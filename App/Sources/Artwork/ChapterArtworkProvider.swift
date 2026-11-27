import UIKit
import CoreText
import MediaPlayer
import QuranCarPlayerCore

/// Generates chapter artwork from eight bundled, release-cleared portraits.
///
/// Artwork is rendered on demand instead of bundling 912 chapter/portrait combinations.
/// The source portraits work fully offline. Mishary, fixture reciters, and unknown
/// reciters deliberately use the typography fallback.
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
            detail: "Photo by Real avdulmouhd · CC BY-SA 4.0 · cropped and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Professor_Maher_Al-Mu%27aiqly.jpg")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!
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
        Attribution(
            id: "mp3quran.saad",
            title: "Saad Al-Ghamdi portrait",
            detail: "Photo by الشيخ هيثم الدخين · CC BY-SA 4.0 · reframed, resized, and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Saad_al_Ghamdi.jpg")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!
        ),
        Attribution(
            id: "mp3quran.hussary",
            title: "Mahmoud Khalil Al-Hussary portrait",
            detail: "Photo by Zubairkhan1 · worldwide public-domain release · reframed, resized, and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Hussary.jpg")!,
            licenseURL: URL(string: "https://commons.wikimedia.org/wiki/File:Hussary.jpg#Licensing")!
        ),
        Attribution(
            id: "mp3quran.minshawi",
            title: "Mohammed Siddiq Al-Minshawi portrait",
            detail: "Unknown photographer · public domain · reframed, resized, and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Elminshwey.jpg")!,
            licenseURL: URL(string: "https://commons.wikimedia.org/wiki/Template:PD-Egypt")!
        ),
        Attribution(
            id: "mp3quran.abdulbasit",
            title: "Abdulbasit Abdulsamad portrait",
            detail: "Prasar Bharati, Ministry of Information and Broadcasting, Government of India · GODL-India · reframed, resized, and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Abdul_Basit_Abdul_Samad_at_Centenary_Celebration_Of_Darul_Uloom_Deoband_1980.jpg")!,
            licenseURL: URL(string: "https://data.gov.in/sites/default/files/Gazette_Notification_OGDL.pdf")!
        ),
        Attribution(
            id: "mp3quran.yasser",
            title: "Yasser Al-Dosari portrait",
            detail: "Photo by MAL MALDIVE · CC BY-SA 4.0 · reframed, resized, and color-treated",
            sourceURL: URL(string: "https://commons.wikimedia.org/wiki/File:Yasser_Al-Dosari.jpg")!,
            licenseURL: URL(string: "https://creativecommons.org/licenses/by-sa/4.0/")!
        ),
    ]

    private struct PortraitDescriptor {
        let assetName: String
        let color: UIColor
        let verticalFocus: CGFloat
    }

    private static let titleThreshold: CGFloat = 180
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
            guard requestedSize.width.isFinite, requestedSize.height.isFinite,
                  requestedSize.width > 0, requestedSize.height > 0 else {
                return variants[variants.count - 1]
            }
            let side = min(requestedSize.width, requestedSize.height)
            let source: UIImage
            if side < Self.titleThreshold {
                source = variants[0]
            } else {
                source = variants.first { $0.size.width >= side } ?? variants[variants.count - 1]
            }
            guard source.size != requestedSize else { return source }
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 1
            return UIGraphicsImageRenderer(size: requestedSize, format: format).image { renderer in
                UIColor.black.setFill()
                renderer.fill(CGRect(origin: .zero, size: requestedSize))
                source.draw(in: CGRect(x: (requestedSize.width - side) / 2,
                                       y: (requestedSize.height - side) / 2,
                                       width: side, height: side))
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
                                 includeText: rect.width >= Self.titleThreshold)
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
                                 includeText: rect.width >= Self.titleThreshold)
            }
        }
    }

    private func portraitDescriptor(for reciterID: ReciterID?) -> PortraitDescriptor? {
        switch reciterID?.rawValue {
        case "mp3quran.maher":
            return PortraitDescriptor(assetName: "ReciterMaher",
                                      color: UIColor(red: 0.09, green: 0.30, blue: 0.26, alpha: 1),
                                      verticalFocus: 0.43)
        case "mp3quran.sudais":
            return PortraitDescriptor(assetName: "ReciterSudais",
                                      color: UIColor(red: 0.09, green: 0.21, blue: 0.32, alpha: 1),
                                      verticalFocus: 0.36)
        case "mp3quran.shuraim":
            return PortraitDescriptor(assetName: "ReciterShuraim",
                                      color: UIColor(red: 0.36, green: 0.22, blue: 0.17, alpha: 1),
                                      verticalFocus: 0.37)
        case "mp3quran.saad":
            return PortraitDescriptor(assetName: "ReciterSaad",
                                      color: UIColor(red: 0.27, green: 0.12, blue: 0.13, alpha: 1),
                                      verticalFocus: 0.50)
        case "mp3quran.hussary":
            return PortraitDescriptor(assetName: "ReciterHussary",
                                      color: UIColor(red: 0.24, green: 0.20, blue: 0.10, alpha: 1),
                                      verticalFocus: 0.50)
        case "mp3quran.minshawi":
            return PortraitDescriptor(assetName: "ReciterMinshawi",
                                      color: UIColor(red: 0.14, green: 0.18, blue: 0.24, alpha: 1),
                                      verticalFocus: 0.50)
        case "mp3quran.abdulbasit":
            return PortraitDescriptor(assetName: "ReciterAbdulbasit",
                                      color: UIColor(red: 0.12, green: 0.16, blue: 0.13, alpha: 1),
                                      verticalFocus: 0.50)
        case "mp3quran.yasser":
            return PortraitDescriptor(assetName: "ReciterYasser",
                                      color: UIColor(red: 0.34, green: 0.25, blue: 0.12, alpha: 1),
                                      verticalFocus: 0.50)
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
                color.withAlphaComponent(0.68).cgColor,
                color.withAlphaComponent(0.97).cgColor,
            ] as CFArray,
            locations: [0, 0.50, 0.76, 1]
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
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        defer { context.restoreGState() }
        let scale = rect.width / 1_024
        context.scaleBy(x: scale, y: scale)

        // Use one design grid at every output resolution. Thumbnails keep just the
        // number and portrait, with a wider badge for the longer chapter numbers.
        let inset: CGFloat = 64
        let badgeHeight: CGFloat = includeText ? 154 : 236
        let digits = String(surah.number)
        let badgeWidth: CGFloat
        if includeText {
            badgeWidth = digits.count == 3 ? 188 : badgeHeight
        } else {
            badgeWidth = max(badgeHeight, 76 + CGFloat(digits.count) * 94)
        }
        let badge = CGRect(x: inset, y: inset, width: badgeWidth, height: badgeHeight)
        UIColor(red: 1, green: 0.95, blue: 0.78, alpha: 1).setFill()
        UIBezierPath(roundedRect: badge, cornerRadius: badgeHeight * 0.27).fill()
        drawLine(digits, in: badge.insetBy(dx: includeText ? 21 : 27, dy: 12),
                 font: .monospacedDigitSystemFont(ofSize: includeText ? 80 : 162, weight: .bold),
                 color: accent, alignment: .center, context: context)
        guard includeText else { return }

        let gold = UIColor(red: 0.90, green: 0.72, blue: 0.29, alpha: 1)
        context.setStrokeColor(gold.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: inset, y: 716))
        context.addLine(to: CGPoint(x: 1_024 - inset, y: 716))
        context.strokePath()

        let alignment: NSTextAlignment = language.isRightToLeft ? .right : .left
        let width = 1_024 - 2 * inset
        drawLine(surah.arabicName, in: CGRect(x: inset, y: 737, width: width, height: 105),
                 font: .systemFont(ofSize: 112, weight: .regular),
                 color: UIColor(red: 1, green: 0.97, blue: 0.91, alpha: 1),
                 alignment: alignment, context: context)
        drawLine(surah.transliteratedName, in: CGRect(x: inset, y: 857, width: width, height: 62),
                 font: .systemFont(ofSize: 52, weight: .bold), color: .white,
                 alignment: alignment, context: context)
        if let reciter {
            drawLine(reciter.displayName(for: language),
                     in: CGRect(x: inset, y: 932, width: width, height: 48),
                     font: .systemFont(ofSize: 41, weight: .semibold),
                     color: UIColor(red: 0.99, green: 0.87, blue: 0.62, alpha: 1),
                     alignment: alignment, context: context)
        }
    }

    /// Align the visible glyphs, including Arabic dots and descenders. Line-fragment
    /// padding varies between scripts and would leave the number high in its badge.
    private func drawLine(_ text: String, in box: CGRect, font: UIFont, color: UIColor,
                          alignment: NSTextAlignment, context: CGContext) {
        let string = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color])
        let line = CTLineCreateWithAttributedString(string)
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard ink.width > 0, ink.height > 0 else { return }
        let fit = min(1, box.width / ink.width, box.height / ink.height)
        let width = ink.width * fit
        let left: CGFloat
        switch alignment {
        case .center: left = box.midX - width / 2
        case .right: left = box.maxX - width
        default: left = box.minX
        }

        context.saveGState()
        defer { context.restoreGState() }
        context.translateBy(x: left - ink.minX * fit, y: box.midY + ink.midY * fit)
        context.scaleBy(x: fit, y: -fit)
        context.textMatrix = .identity
        context.textPosition = .zero
        CTLineDraw(line, context)
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
