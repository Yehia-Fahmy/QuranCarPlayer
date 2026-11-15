import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol AudioDownloadClient: Sendable {
    /// Downloads to a temporary file owned by the caller. Progress is nil when the server does
    /// not provide a usable content length.
    func download(from url: URL,
                  progress: @escaping @Sendable (Double?) -> Void) async throws -> URL
}

public enum AudioDownloadClientError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case emptyFile
    case writeFailed
}

/// Foreground URLSession downloader that streams bytes directly to disk.
///
/// A foreground transfer is intentional: downloads are user initiated, cancellable, and do not
/// imply background-download behavior that the app does not yet support.
public final class URLSessionAudioDownloadClient: AudioDownloadClient, @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let fileManager: FileManager

    public init(configuration: URLSessionConfiguration = .default,
                fileManager: FileManager = .default) {
        self.configuration = configuration
        self.fileManager = fileManager
    }

    public func download(from url: URL,
                         progress: @escaping @Sendable (Double?) -> Void) async throws -> URL {
        let operation = StreamingDownloadOperation(url: url,
                                                   configuration: configuration,
                                                   fileManager: fileManager,
                                                   progress: progress)
        return try await operation.start()
    }
}

private final class StreamingDownloadOperation: NSObject,
                                                URLSessionDataDelegate,
                                                @unchecked Sendable {
    private let sourceURL: URL
    private let configuration: URLSessionConfiguration
    private let fileManager: FileManager
    private let progress: @Sendable (Double?) -> Void
    private let lock = NSLock()

    private var continuation: CheckedContinuation<URL, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var outputURL: URL?
    private var output: FileHandle?
    private var receivedBytes: Int64 = 0
    private var expectedBytes: Int64?
    private var terminalError: Error?
    private var cancellationRequested = false
    private var finished = false

    init(url: URL,
         configuration: URLSessionConfiguration,
         fileManager: FileManager,
         progress: @escaping @Sendable (Double?) -> Void) {
        sourceURL = url
        self.configuration = configuration
        self.fileManager = fileManager
        self.progress = progress
    }

    func start() async throws -> URL {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                begin(continuation)
            }
        } onCancel: {
            self.cancel()
        }
    }

    private func begin(_ continuation: CheckedContinuation<URL, Error>) {
        lock.lock()
        if cancellationRequested {
            lock.unlock()
            continuation.resume(throwing: CancellationError())
            return
        }
        self.continuation = continuation
        lock.unlock()

        var createdTemporaryURL: URL?
        do {
            let temporaryURL = fileManager.temporaryDirectory
                .appendingPathComponent("qcp-\(UUID().uuidString).download")
            guard fileManager.createFile(atPath: temporaryURL.path, contents: nil) else {
                throw AudioDownloadClientError.writeFailed
            }
            createdTemporaryURL = temporaryURL
            let handle = try FileHandle(forWritingTo: temporaryURL)
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            let request = URLRequest(url: sourceURL,
                                     cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
                                     timeoutInterval: 60)
            let task = session.dataTask(with: request)

            lock.lock()
            if cancellationRequested || finished {
                lock.unlock()
                try? handle.close()
                try? fileManager.removeItem(at: temporaryURL)
                session.invalidateAndCancel()
                return
            }
            outputURL = temporaryURL
            output = handle
            self.session = session
            self.task = task
            lock.unlock()

            progress(nil)
            task.resume()
        } catch {
            if let createdTemporaryURL { try? fileManager.removeItem(at: createdTemporaryURL) }
            finish(.failure(error))
        }
    }

    private func cancel() {
        lock.lock()
        cancellationRequested = true
        let task = task
        let hasContinuation = continuation != nil
        lock.unlock()
        task?.cancel()
        if task == nil && hasContinuation {
            finish(.failure(CancellationError()))
        }
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive response: URLResponse,
                    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let http = response as? HTTPURLResponse else {
            setTerminalError(AudioDownloadClientError.invalidResponse)
            completionHandler(.cancel)
            return
        }
        guard (200...299).contains(http.statusCode) else {
            setTerminalError(AudioDownloadClientError.httpStatus(http.statusCode))
            completionHandler(.cancel)
            return
        }
        if response.expectedContentLength > 0 {
            lock.qcpWithLock { expectedBytes = response.expectedContentLength }
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession,
                    dataTask: URLSessionDataTask,
                    didReceive data: Data) {
        do {
            try lock.qcpWithLock {
                try output?.write(contentsOf: data)
                receivedBytes += Int64(data.count)
            }
        } catch {
            setTerminalError(AudioDownloadClientError.writeFailed)
            dataTask.cancel()
            return
        }

        let update: Double? = lock.qcpWithLock {
            guard let expectedBytes, expectedBytes > 0 else { return nil }
            return min(1, max(0, Double(receivedBytes) / Double(expectedBytes)))
        }
        progress(update)
    }

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        let result: Result<URL, Error> = lock.qcpWithLock {
            if cancellationRequested {
                return .failure(CancellationError())
            }
            if let terminalError {
                return .failure(terminalError)
            }
            if let error {
                return .failure(error)
            }
            guard receivedBytes > 0, let outputURL else {
                return .failure(AudioDownloadClientError.emptyFile)
            }
            return .success(outputURL)
        }
        finish(result)
    }

    private func setTerminalError(_ error: Error) {
        lock.qcpWithLock {
            if terminalError == nil { terminalError = error }
        }
    }

    private func finish(_ result: Result<URL, Error>) {
        let context: (continuation: CheckedContinuation<URL, Error>?,
                      session: URLSession?,
                      outputURL: URL?,
                      result: Result<URL, Error>)? = lock.qcpWithLock {
            guard !finished else { return nil }
            finished = true
            try? output?.close()
            output = nil
            let completion = continuation
            continuation = nil
            let activeSession = session
            session = nil
            task = nil
            let finalResult: Result<URL, Error> = cancellationRequested
                ? .failure(CancellationError())
                : result
            return (completion, activeSession, outputURL, finalResult)
        }
        guard let context else { return }

        context.session?.finishTasksAndInvalidate()

        switch context.result {
        case .success(let url):
            progress(1)
            context.continuation?.resume(returning: url)
        case .failure(let error):
            if let outputURL = context.outputURL { try? fileManager.removeItem(at: outputURL) }
            context.continuation?.resume(throwing: error)
        }
    }
}
