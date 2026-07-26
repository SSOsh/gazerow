import SwiftUI

/// GazeRow가 직접 표시하는 Mission Control 스타일 전체 화면 창 오버뷰.
///
/// 화면 bitmap을 캡처하지 않고 앱 아이콘과 창 메타데이터만 사용한다.
///
/// @author suho.do
/// @since 2026-07-26
struct OverlayWindowOverviewView: View {
    let items: [OverlayWindowOverviewItem]
    let language: AppLanguage
    private let layoutEngine = OverlayWindowOverviewLayoutEngine()

    init(
        items: [OverlayWindowOverviewItem],
        language: AppLanguage = AppLanguageSettings().selectedLanguage
    ) {
        self.items = items
        self.language = language
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = layoutEngine.makeLayout(
                itemCount: items.count,
                availableSize: geometry.size
            )

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)

                Color.black.opacity(0.64)

                VStack(spacing: 24) {
                    header

                    ScrollViewReader { proxy in
                        ScrollView(.vertical) {
                            LazyVGrid(
                                columns: columns(for: layout),
                                alignment: .center,
                                spacing: layout.verticalSpacing
                            ) {
                                ForEach(items) { item in
                                    OverlayWindowOverviewCard(item: item)
                                        .frame(
                                            width: layout.cardSize.width,
                                            height: layout.cardSize.height
                                        )
                                        .id(item.id)
                                }
                            }
                            .padding(.horizontal, 64)
                            .padding(.vertical, 8)
                        }
                        .scrollIndicators(.hidden)
                        .onChange(of: focusedItemID) { _, focusedItemID in
                            guard let focusedItemID else {
                                return
                            }

                            withAnimation(.easeOut(duration: 0.14)) {
                                proxy.scrollTo(focusedItemID, anchor: .center)
                            }
                        }
                    }
                }
                .padding(.top, 34)
                .padding(.bottom, 116)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var header: some View {
        let content = AppContent.localized(for: language)
        return VStack(spacing: 5) {
            Text(content.commandBarModeTitle(for: .windows))
                .font(.system(size: 24, weight: .bold, design: .rounded))

            Text(content.commandBarModeHelper(for: .windows))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.68))
        }
        .foregroundStyle(Color.white)
    }

    private var focusedItemID: Int? {
        items.first(where: \.isFocused)?.id
    }

    private func columns(for layout: OverlayWindowOverviewLayout) -> [GridItem] {
        Array(
            repeating: GridItem(.fixed(layout.cardSize.width), spacing: layout.horizontalSpacing),
            count: layout.columnCount
        )
    }
}

private struct OverlayWindowOverviewCard: View {
    let item: OverlayWindowOverviewItem

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            windowBody
            footer
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.12).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    item.isFocused ? Color.cyan.opacity(0.98) : Color.white.opacity(0.18),
                    lineWidth: item.isFocused ? 3 : 1
                )
        }
        .overlay {
            labelBadge
        }
        .shadow(
            color: item.isFocused ? Color.cyan.opacity(0.28) : Color.black.opacity(0.5),
            radius: item.isFocused ? 18 : 10,
            y: 5
        )
        .scaleEffect(item.isFocused ? 1.025 : 1)
        .animation(.easeOut(duration: 0.14), value: item.isFocused)
        .help(item.displayName)
    }

    private var titleBar: some View {
        HStack(spacing: 8) {
            appIcon(size: 20)

            Text(item.appName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .lineLimit(1)

            Spacer(minLength: 8)

            HStack(spacing: 5) {
                Circle().fill(Color.white.opacity(0.18))
                Circle().fill(Color.white.opacity(0.18))
                Circle().fill(Color.white.opacity(0.18))
            }
            .frame(width: 35)
        }
        .foregroundStyle(Color.white.opacity(0.9))
        .padding(.horizontal, 13)
        .frame(height: 38)
        .background(Color.white.opacity(0.07))
    }

    private var windowBody: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(item.isFocused ? 0.13 : 0.09),
                    Color.white.opacity(0.025)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 13) {
                appIcon(size: 54)
                    .opacity(item.isFocused ? 0.96 : 0.8)

                VStack(spacing: 7) {
                    Capsule()
                        .fill(Color.white.opacity(0.13))
                        .frame(width: 112, height: 6)
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 76, height: 5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 9) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.detailText.isEmpty ? item.appName : item.detailText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let tabCount = item.tabCount {
                    Text("\(tabCount) tabs")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.56))
                }
            }

            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.white.opacity(0.88))
        .padding(.horizontal, 13)
        .frame(height: 44)
        .background(Color.black.opacity(0.18))
    }

    private var labelBadge: some View {
        Text(item.label)
            .font(.system(size: 24, weight: .black, design: .monospaced))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .background(
                item.isFocused ? Color.cyan.opacity(0.95) : Color.black.opacity(0.82),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(Color.white.opacity(0.94), lineWidth: item.isFocused ? 2 : 1)
            }
            .shadow(color: Color.black.opacity(0.42), radius: 6, y: 2)
    }

    @ViewBuilder
    private func appIcon(size: CGFloat) -> some View {
        if let appIcon = item.appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
        } else {
            Text(initials)
                .font(.system(size: size * 0.38, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(width: size, height: size)
                .background(Color.blue.opacity(0.8), in: RoundedRectangle(cornerRadius: size * 0.22))
        }
    }

    private var initials: String {
        let characters = item.appName.split(separator: " ").prefix(2).compactMap(\.first)
        let value = String(characters).uppercased()
        return value.isEmpty ? "?" : value
    }
}
