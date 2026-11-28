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

    @State private var pendingKey: String?
    @ScaledMetric(relativeTo: .body) private var controlsHeight: CGFloat = 164
    @ScaledMetric(relativeTo: .headline) private var minConfirmWidth: CGFloat = 180
    @GestureState private var dragOffset: CGFloat = 0

    private var readingDirection: LayoutDirection { language.isRightToLeft ? .rightToLeft : .leftToRight }
    private var keys: [String] { [ListeningTheme.systemPreference] + ListeningTheme.allCases.map(\.rawValue) }
    private var appliedKey: String { ListeningTheme(rawValue: preference)?.rawValue ?? ListeningTheme.systemPreference }

    private var selectedKey: String { pendingKey ?? appliedKey }
    private var selectedIndex: Int { keys.firstIndex(of: selectedKey) ?? 0 }

    private func select(_ key: String) {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) { pendingKey = key }
    }

    var body: some View {
        GeometryReader { bounds in
            let ratio = layout.canvas.width / layout.canvas.height
            let cardWidth = min(bounds.size.width * 0.76, max(90, bounds.size.height - controlsHeight) * ratio, 520)
            VStack(spacing: 16) {
                ViewThatFits(in: .vertical) {
                    previews(cardWidth: cardWidth)
                    ScrollView { previews(cardWidth: cardWidth) }
                }
                confirmButton
                    .frame(width: min(max(cardWidth, minConfirmWidth), max(0, bounds.size.width - 32)))
                    .layoutPriority(1)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environment(\.layoutDirection, readingDirection)
        .background(theme.background)
        .navigationTitle(L10n.string("theme.appearance", language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func previews(cardWidth: CGFloat) -> some View {
        VStack(spacing: 16) {
            carousel(cardWidth: cardWidth)

            HStack(spacing: 6) {
                ForEach(keys, id: \.self) { key in
                    Capsule()
                        .fill(key == selectedKey ? theme.accent : Color.primary.opacity(0.23))
                        .frame(width: key == selectedKey ? 18 : 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
    }

    private var confirmButton: some View {
        Button {
            preference = selectedKey
            pendingKey = nil
        } label: {
            Text(verbatim: L10n.string("theme.confirm", language))
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 32)
        }
        .buttonStyle(.borderedProminent)
        .disabled(selectedKey == appliedKey)
        .accessibilityIdentifier("confirm-theme")
    }

    private func carousel(cardWidth: CGFloat) -> some View {
        let sign: CGFloat = language.isRightToLeft ? -1 : 1
        let stride = cardWidth + 14
        let swipe = DragGesture(minimumDistance: 12)
            .updating($dragOffset) { value, offset, _ in
                let travel = value.translation
                guard abs(travel.width) > abs(travel.height) else { return }
                let logical = travel.width * sign
                let atEnd = (selectedIndex == 0 && logical > 0) ||
                    (selectedIndex == keys.count - 1 && logical < 0)
                offset = min(stride, max(-stride, travel.width)) * (atEnd ? 0.18 : 1)
            }
            .onEnded { value in
                let travel = value.translation
                guard abs(travel.width) > abs(travel.height),
                      max(abs(travel.width), abs(value.predictedEndTranslation.width)) > cardWidth * 0.18
                else { return }
                advance(by: travel.width * sign < 0 ? 1 : -1)
            }

        return ZStack(alignment: .top) {
            ForEach(keys, id: \.self) { key in
                let distance = (keys.firstIndex(of: key) ?? 0) - selectedIndex
                choice(ListeningTheme(rawValue: key))
                    .environment(\.layoutDirection, readingDirection)
                    .frame(width: cardWidth)
                    .offset(x: CGFloat(distance) * stride * sign + dragOffset)
                    .accessibilityHidden(abs(distance) > 1)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
        .contentShape(Rectangle())
        .highPriorityGesture(swipe)
        // Card offsets and finger movement share a physical x axis; card contents follow the language.
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("theme-carousel")
        .accessibilityScrollAction { edge in
            if edge == .leading { advance(by: 1) }
            if edge == .trailing { advance(by: -1) }
        }
    }

    private func advance(by step: Int) {
        let target = selectedIndex + step
        if keys.indices.contains(target) { select(keys[target]) }
    }

    private func choice(_ palette: ListeningTheme?) -> some View {
        let key = palette?.rawValue ?? ListeningTheme.systemPreference
        let name = L10n.string("theme.\(key)", language)
        let selected = selectedKey == key
        return Button {
            select(key)
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
                    if key == appliedKey {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(theme.accent)
                    }
                }
                .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Button(name) { select(key) }
                .accessibilityValue(key == appliedKey ? L10n.string("theme.applied", language) : "")
                .accessibilityAddTraits(selected ? .isSelected : [])
        }
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
