import UIKit
import MediaPlayer
import QuranCarPlayerCore

/// Generates chapter artwork from three bundled, release-cleared portraits.
///
/// Artwork is rendered on demand instead of bundling 342 chapter/portrait combinations.
/// The source portraits add less than 1 MB to the app and work fully offline. Mishary,
/// fixture reciters, and unknown reciters deliberately use the typography fallback.
@MainActor
final class ChapterArtworkProvider {
    enum SourceKind: Equatable {
        case licensedPortrait
        case typographyFallback
    }

    struct Attribution: Identifiable, Equatable {
        let id: String
        let title: String
        let detail: String
        let sourceURL: URL
        let licenseURL: URL
    }

    static let attributions: [Attribution] = [
        Attribution(
            id: "mp3quran.maher",
            title: "Maher Al-Muaiqly portrait",
            detail: "Photo by الشيخ هيثم الدخين · CC BY-SA 3.0 · cropped and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Maher_Al_Mueaqly.jpg")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/3.0/")!
        ),
        Attribution(
            id: "mp3quran.sudais",
            title: "Abdul Rahman Al-Sudais portrait",
            detail: "Prime Minister’s Office, Government of India · GODL-India · cropped and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Abdul-Rahman_Al-Sudais_(Cropped,_2011).jpg")!,
            licenseURL: URL(string: "https://data.gov.in/sites/default/files/Gazette_Notification_OGDL.pdf")!
        ),
        Attribution(
            id: "mp3quran.shuraim",
            title: "Saud Al-Shuraim portrait",
            detail: "Vice President’s Secretariat, Government of India · GODL-India · cropped and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:The_IMAM_of_Holy_Mosque_in_Makka_Al_Mukarramah,_Saudi_Arabia,_Sheikh_Dr._Saud_Bin_Ibrahem_Al_Shuraim_meeting_the_Vice_President,_Shri_Mohd._Hamid_Ansari,_in_New_Delhi_on_March_03,_2012_(cropped).jpg")!,
            licenseURL: URL(string: "https://data.gov.in/sites/default/files/Gazette_Notification_OGDL.pdf")!
        ),
    ]

    private struct PortraitDescriptor {
        let assetName: String
        let color: UIColor
        let verticalFocus: CGFloat
    }

    private let cache = NSCache<NSString, UIImage>()

    init() {
        cache.countLimit = 180
        cache.totalCostLimit = 40 * 1_024 * 1_024
    }

    func sourceKind(for reciterID: ReciterID?) -> SourceKind {
        portraitDescriptor(for: reciterID) == nil ? .typographyFallback : .licensedPortrait
    }

    func image(for surah: Surah,
               reciter: Reciter?,
               language: ResolvedLanguage,
               size: CGSize) -> UIImage {
        let dimension = max(64, min(1_024, Int(ceil(max(size.width, size.height)))))
        let reciterKey = reciter?.id.rawValue ?? "none"
        let key = "\(surah.number)|\(reciterKey)|\(language.localeIdentifier)|\(dimension)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let image = render(surah: surah, reciter: reciter, language: language, dimension: dimension)
        cache.setObject(image, forKey: key, cost: dimension * dimension * 4)
        return image
    }

    func nowPlayingArtwork(for surah: Surah,
                           reciter: Reciter?,
                           language: ResolvedLanguage) -> MPMediaItemArtwork {
        let variants = [128, 256, 512, 1_024].map { dimension in
            image(for: surah,
                  reciter: reciter,
                  language: language,
                  size: CGSize(width: dimension, height: dimension))
        }
        return MPMediaItemArtwork(boundsSize: CGSize(width: 1_024, height: 1_024)) { requestedSize in
            let nearest = variants.min {
                abs($0.size.width - requestedSize.width) < abs($1.size.width - requestedSize.width)
            } ?? variants[variants.count - 1]
            guard nearest.size != requestedSize,
                  requestedSize.width > 0,
                  requestedSize.height > 0 else {
                return nearest
            }
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 1
            return UIGraphicsImageRenderer(size: requestedSize, format: format).image { _ in
                nearest.draw(in: CGRect(origin: .zero, size: requestedSize))
            }
        }
    }

    private func render(surah: Surah,
                        reciter: Reciter?,
                        language: ResolvedLanguage,
                        dimension: Int) -> UIImage {
        let size = CGSize(width: dimension, height: dimension)
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { rendererContext in
            let context = rendererContext.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let descriptor = portraitDescriptor(for: reciter?.id)

            if let descriptor,
               let portrait = UIImage(named: descriptor.assetName) {
                drawAspectFill(portrait, in: rect, verticalFocus: descriptor.verticalFocus)
                drawGradient(in: context, rect: rect, color: descriptor.color)
                drawChapterLabel(surah: surah,
                                 reciter: reciter,
                                 language: language,
                                 in: rect,
                                 accent: descriptor.color,
                                 includeText: dimension >= 180)
            } else {
                let color = fallbackColor(for: surah.number)
                context.setFillColor(color.cgColor)
                context.fill(rect)
                drawGeometry(in: context, rect: rect, accent: UIColor(red: 0.90, green: 0.72, blue: 0.29, alpha: 1))
                drawChapterLabel(surah: surah,
                                 reciter: reciter,
                                 language: language,
                                 in: rect,
                                 accent: color,
                                 includeText: dimension >= 180)
            }
        }
    }

    private func portraitDescriptor(for reciterID: ReciterID?) -> PortraitDescriptor? {
        switch reciterID?.rawValue {
        case "mp3quran.maher":
            return PortraitDescriptor(assetName: "ReciterMaher",
                                      color: UIColor(red: 0.09, green: 0.30, blue: 0.26, alpha: 1),
                                      verticalFocus: 0.34)
        case "mp3quran.sudais":
            return PortraitDescriptor(assetName: "ReciterSudais",
                                      color: UIColor(red: 0.09, green: 0.21, blue: 0.32, alpha: 1),
                                      verticalFocus: 0.36)
        case "mp3quran.shuraim":
            return PortraitDescriptor(assetName: "ReciterShuraim",
                                      color: UIColor(red: 0.36, green: 0.22, blue: 0.17, alpha: 1),
                                      verticalFocus: 0.37)
        default:
            // Mishary has no bundled portrait until its reuse rights are independently cleared.
            return nil
        }
    }

    private func drawAspectFill(_ image: UIImage, in rect: CGRect, verticalFocus: CGFloat) {
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let drawnSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let horizontalOverflow = max(0, drawnSize.width - rect.width)
        let verticalOverflow = max(0, drawnSize.height - rect.height)
        let focusedTop = max(0, min(verticalOverflow, drawnSize.height * verticalFocus - rect.height * 0.42))
        image.draw(in: CGRect(x: rect.minX - horizontalOverflow / 2,
                              y: rect.minY - focusedTop,
                              width: drawnSize.width,
                              height: drawnSize.height))
    }

    private func drawGradient(in context: CGContext, rect: CGRect, color: UIColor) {
        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                color.withAlphaComponent(0.06).cgColor,
                color.withAlphaComponent(0.18).cgColor,
                color.withAlphaComponent(0.94).cgColor,
            ] as CFArray,
            locations: [0, 0.52, 1]
        ) else { return }
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: rect.midX, y: rect.minY),
                                   end: CGPoint(x: rect.midX, y: rect.maxY),
                                   options: [])
    }

    private func drawGeometry(in context: CGContext, rect: CGRect, accent: UIColor) {
        context.saveGState()
        context.setStrokeColor(accent.withAlphaComponent(0.72).cgColor)
        context.setLineWidth(max(1, rect.width * 0.006))
        let center = CGPoint(x: rect.midX, y: rect.height * 0.38)
        let maximumRadius = rect.width * 0.32
        for ring in 1...5 {
            let radius = maximumRadius * CGFloat(ring) / 5
            var points: [CGPoint] = []
            for point in 0..<8 {
                let angle = CGFloat(point) * .pi / 4 + (ring.isMultiple(of: 2) ? 0 : .pi / 8)
                points.append(CGPoint(x: center.x + cos(angle) * radius,
                                      y: center.y + sin(angle) * radius))
            }
            if let first = points.first {
                context.move(to: first)
                for point in points.dropFirst() { context.addLine(to: point) }
                context.closePath()
                context.strokePath()
            }
        }
        context.restoreGState()
    }

    private func drawChapterLabel(surah: Surah,
                                  reciter: Reciter?,
                                  language: ResolvedLanguage,
                                  in rect: CGRect,
                                  accent: UIColor,
                                  includeText: Bool) {
        let scale = rect.width / 1_024
        let badgeRect = CGRect(x: 64 * scale, y: 64 * scale, width: 154 * scale, height: 154 * scale)
        let badge = UIBezierPath(roundedRect: badgeRect, cornerRadius: 42 * scale)
        UIColor(red: 1, green: 0.95, blue: 0.78, alpha: 1).setFill()
        badge.fill()

        let numberSize: CGFloat = surah.number >= 100 ? 62 : 76
        drawFitted(String(surah.number),
                   in: badgeRect,
                   maximumPointSize: numberSize * scale,
                   minimumPointSize: 42 * scale,
                   weight: .bold,
                   color: accent,
                   alignment: .center)
        guard includeText else { return }

        let lineY = 730 * scale
        let context = UIGraphicsGetCurrentContext()
        context?.setStrokeColor(UIColor(red: 0.90, green: 0.72, blue: 0.29, alpha: 1).cgColor)
        context?.setLineWidth(max(1, 3 * scale))
        context?.move(to: CGPoint(x: 64 * scale, y: lineY))
        context?.addLine(to: CGPoint(x: 960 * scale, y: lineY))
        context?.strokePath()

        drawFitted(surah.arabicName,
                   in: CGRect(x: 64 * scale, y: 740 * scale, width: 896 * scale, height: 130 * scale),
                   maximumPointSize: 112 * scale,
                   minimumPointSize: 70 * scale,
                   weight: .regular,
                   color: UIColor(red: 1, green: 0.97, blue: 0.91, alpha: 1),
                   alignment: language.isRightToLeft ? .right : .left)
        drawFitted(surah.transliteratedName,
                   in: CGRect(x: 64 * scale, y: 855 * scale, width: 896 * scale, height: 70 * scale),
                   maximumPointSize: 48 * scale,
                   minimumPointSize: 30 * scale,
                   weight: .bold,
                   color: .white,
                   alignment: .left)
        if let reciter {
            drawFitted(reciter.displayName(for: language),
                       in: CGRect(x: 64 * scale, y: 925 * scale, width: 896 * scale, height: 52 * scale),
                       maximumPointSize: 30 * scale,
                       minimumPointSize: 21 * scale,
                       weight: .bold,
                       color: UIColor(red: 0.97, green: 0.83, blue: 0.51, alpha: 1),
                       alignment: language.isRightToLeft ? .right : .left)
        }
    }

    private func drawFitted(_ text: String,
                            in rect: CGRect,
                            maximumPointSize: CGFloat,
                            minimumPointSize: CGFloat,
                            weight: UIFont.Weight,
                            color: UIColor,
                            alignment: NSTextAlignment) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        var pointSize = maximumPointSize
        var selectedFont = UIFont.systemFont(ofSize: pointSize, weight: weight)
        while pointSize > minimumPointSize {
            let width = (text as NSString).size(withAttributes: [.font: selectedFont]).width
            if width <= rect.width { break }
            pointSize -= 2
            selectedFont = UIFont.systemFont(ofSize: pointSize, weight: weight)
        }
        (text as NSString).draw(in: rect,
                                withAttributes: [
                                    .font: selectedFont,
                                    .foregroundColor: color,
                                    .paragraphStyle: paragraph,
                                ])
    }

    private func fallbackColor(for surahNumber: Int) -> UIColor {
        let colors: [UIColor] = [
            UIColor(red: 0.03, green: 0.31, blue: 0.26, alpha: 1),
            UIColor(red: 0.09, green: 0.18, blue: 0.30, alpha: 1),
            UIColor(red: 0.36, green: 0.16, blue: 0.29, alpha: 1),
            UIColor(red: 0.23, green: 0.29, blue: 0.20, alpha: 1),
            UIColor(red: 0.31, green: 0.18, blue: 0.16, alpha: 1),
            UIColor(red: 0.15, green: 0.22, blue: 0.36, alpha: 1),
        ]
        return colors[(surahNumber - 1) % colors.count]
    }
}
