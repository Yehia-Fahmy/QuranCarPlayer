import Foundation

/// Cancellable handle for a scheduled action.
public protocol ScheduledWork: AnyObject {
    func cancel()
}

/// Injected timer so retry and checkpoint timing are deterministic in tests.
@MainActor
public protocol WorkScheduler: AnyObject {
    func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ScheduledWork
}

/// Injected clock.
public protocol Clock: Sendable {
    func now() -> Date
}

public struct SystemClock: Clock {
    public init() {}
    public func now() -> Date { Date() }
}

/// Production scheduler backed by main-queue dispatch.
@MainActor
public final class DispatchWorkScheduler: WorkScheduler {
    public init() {}

    private final class Handle: ScheduledWork {
        let item: DispatchWorkItem
        init(_ item: DispatchWorkItem) { self.item = item }
        func cancel() { item.cancel() }
    }

    public func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) -> ScheduledWork {
        let item = DispatchWorkItem { action() }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        return Handle(item)
    }
}

/// Streaming retry policy: delays of 1, 2, 4 seconds bounded by a 20-second window.
/// This is a policy to test against real providers, not a guarantee.
public struct RetryPolicy: Equatable, Sendable {
    public var delays: [TimeInterval]
    public var recoveryWindow: TimeInterval

    public init(delays: [TimeInterval] = [1, 2, 4], recoveryWindow: TimeInterval = 20) {
        self.delays = delays
        self.recoveryWindow = recoveryWindow
    }

    /// Delay before attempt `attempt` (0-based), or nil when retries are exhausted
    /// or would fall outside the recovery window.
    public func delay(forAttempt attempt: Int, elapsedSinceFirstFailure elapsed: TimeInterval) -> TimeInterval? {
        guard attempt < delays.count else { return nil }
        let delay = delays[attempt]
        guard elapsed + delay <= recoveryWindow else { return nil }
        return delay
    }
}
