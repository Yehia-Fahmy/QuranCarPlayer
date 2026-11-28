import SwiftUI
import QuranCarPlayerCore

/// Use the presenting window's size classes. An iPad Settings sheet can itself be compact.
enum ThemePreviewLayout {
    case portrait, landscape, split

    var canvas: CGSize {
        switch self {
        case .portrait: CGSize(width: 260, height: 310)
        case .landscape: CGSize(width: 440, height: 225)
        case .split: CGSize(width: 470, height: 320)
        }
    }
}

struct ThemeGallery: View {
    @Binding var preference: String
    let layout: ThemePreviewLayout
    let language: ResolvedLanguage
    let catalog: SurahCatalog
    let reciter: Reciter?
    @ObservedObject var artworkProvider: ChapterArtworkProvider
    @Environment(\.listeningTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var keys: [String] { [ListeningTheme.systemPreference] + ListeningTheme.allCases.map(\.rawValue) }
    private var selectedKey: String { ListeningTheme(rawValue: preference)?.rawValue ?? ListeningTheme.systemPreference }

    private var swipeLimit: ViewAlignedScrollTargetBehavior.LimitBehavior {
        if #available(iOS 18.0, *) { return .alwaysByOne }
        return .always
    }

    var body: some View {
        GeometryReader { bounds in
            let ratio = layout.canvas.width / layout.canvas.height
            let cardWidth = min(bounds.size.width * 0.76, max(150, bounds.size.height - 112) * ratio, 520)
            let inset = (bounds.size.width - cardWidth) / 2
            ScrollView {
                VStack(spacing: 18) {
                    ScrollView(.horizontal) {
                        LazyHStack(spacing: 14) {
                            ForEach(keys, id: \.self) { key in
                                choice(ListeningTheme(rawValue: key))
                                    .frame(width: cardWidth)
                                    .id(key)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, inset, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .scrollTargetBehavior(.viewAligned(limitBehavior: swipeLimit))
                    .scrollPosition(id: Binding<String?>(
                        get: { selectedKey },
                        set: { if let key = $0 { preference = key } }
                    ), anchor: .center)
                    .accessibilityIdentifier("theme-carousel")

                    HStack(spacing: 6) {
                        ForEach(keys, id: \.self) { key in
                            Capsule()
                                .fill(key == selectedKey ? theme.accent : Color.primary.opacity(0.23))
                                .frame(width: key == selectedKey ? 18 : 6, height: 6)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.vertical, 18)
                .frame(minHeight: bounds.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(theme.background)
        .navigationTitle(L10n.string("theme.appearance", language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func choice(_ palette: ListeningTheme?) -> some View {
        let key = palette?.rawValue ?? ListeningTheme.systemPreference
        let name = L10n.string("theme.\(key)", language)
        let selected = selectedKey == key
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) { preference = key }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { bounds in
                    let size = layout.canvas
                    ZStack {
                        preview(palette ?? .folio)
                        if palette == nil {
                            preview(.nocturne)
                                .mask {
                                    HStack(spacing: 0) {
                                        Color.clear
                                        Color.black
                                    }
                                }
                        }
                    }
                    .frame(width: size.width, height: size.height)
                    .scaleEffect(bounds.size.width / size.width)
                    .position(x: bounds.size.width / 2, y: bounds.size.height / 2)
                }
                .aspectRatio(layout.canvas, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(selected ? theme.accent : Color.primary.opacity(0.16),
                                      lineWidth: selected ? 3 : 1)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(verbatim: name).font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? theme.accent : .secondary)
                }
                .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func preview(_ palette: ListeningTheme) -> some View {
        HStack(spacing: 0) {
            if layout == .split {
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: L10n.string("surahs.title", language)).font(.title2.bold())
                    ForEach(catalog.surahs.prefix(5)) { surah in
                        SurahRow(surah: surah, language: language, isCurrent: surah.number == 1, isPlaying: false)
                            .padding(.horizontal, 5)
                            .background(surah.number == 1 ? palette.accent.opacity(0.13) : palette.surface,
                                        in: .rect(cornerRadius: 6))
                    }
                }
                .frame(width: 200)
                .padding(10)
                .frame(maxHeight: .infinity)
                .background(palette.background)
                Divider()
            }
            if let surah = catalog.surahs.first {
                let arrangement = layout == .landscape ? AnyLayout(HStackLayout(spacing: 20)) : AnyLayout(VStackLayout(spacing: 12))
                arrangement {
                    Image(uiImage: artworkProvider.image(for: surah, reciter: reciter, language: language,
                                                         size: CGSize(width: 320, height: 320)))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 148, height: 148)
                        .clipShape(.rect(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.2), radius: 5, y: 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "\(surah.number). \(surah.displayName(for: language))").font(.title3.bold())
                        if let reciter {
                            Text(verbatim: reciter.displayName(for: language)).font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: 0.3).padding(.vertical, 6)
                        HStack(spacing: 18) {
                            Image(systemName: "backward.end.fill")
                            Image(systemName: "play.circle.fill").font(.title)
                            Image(systemName: "forward.end.fill")
                        }
                        .foregroundStyle(palette.accent)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LinearGradient(colors: [palette.surface, palette.background],
                                           startPoint: .top, endPoint: .bottom))
            }
        }
        .foregroundStyle(.primary)
        .environment(\.listeningTheme, palette)
        .environment(\.colorScheme, palette.colorScheme)
        .tint(palette.accent)
        .dynamicTypeSize(.medium)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
