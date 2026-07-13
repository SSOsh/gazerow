import SwiftUI

/// windows scope의 후보 창 preview strip.
///
/// @author suho.do
/// @since 2026-07-13
struct OverlayWindowMatchStripView: View {
    let previews: [OverlayWindowMatchPreview]

    var body: some View {
        content
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            }
    }

    @ViewBuilder
    private var content: some View {
        if previews.allSatisfy(\.hasAppIcon) {
            HStack(spacing: 8) {
                ForEach(previews.prefix(6)) { preview in
                    WindowMatchIconView(preview: preview)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(previews.prefix(6)) { preview in
                    WindowMatchListRowView(preview: preview)
                }
            }
        }
    }
}

private struct WindowMatchIconView: View {
    let preview: OverlayWindowMatchPreview

    var body: some View {
        VStack(spacing: 3) {
            icon
                .frame(width: 24, height: 24)
                .padding(3)
                .background(
                    preview.isFocused ? Color.blue.opacity(0.42) : Color.white.opacity(0.10),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            preview.isFocused ? Color.blue.opacity(0.98) : Color.white.opacity(0.36),
                            lineWidth: preview.isFocused ? 2 : 1
                        )
                }

            Text(preview.appName)
                .font(.system(size: 9, weight: preview.isFocused ? .bold : .medium, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 70)
                .foregroundStyle(Color.white.opacity(preview.isFocused ? 1 : 0.76))
        }
        .help(preview.displayName)
    }

    @ViewBuilder
    private var icon: some View {
        if let appIcon = preview.appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .scaledToFit()
        } else {
            Text(initials)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.blue, in: RoundedRectangle(cornerRadius: 4))
        }
    }

    private var initials: String {
        let characters = preview.appName.split(separator: " ").prefix(2).compactMap(\.first)
        let value = String(characters).uppercased()
        return value.isEmpty ? "?" : value
    }
}

private struct WindowMatchListRowView: View {
    let preview: OverlayWindowMatchPreview

    var body: some View {
        HStack(spacing: 7) {
            Text("\(preview.ordinal)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.82))
                .frame(width: 15, height: 15)
                .background(Color.white.opacity(preview.isFocused ? 0.96 : 0.78), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(preview.appName)
                    .font(.system(size: 10, weight: preview.isFocused ? .bold : .semibold, design: .rounded))
                    .lineLimit(1)

                if !preview.detailText.isEmpty {
                    Text(preview.detailText)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .foregroundStyle(Color.white.opacity(0.72))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(Color.white.opacity(preview.isFocused ? 1 : 0.82))
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            preview.isFocused ? Color.blue.opacity(0.26) : Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 5)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(
                    preview.isFocused ? Color.blue.opacity(0.92) : Color.white.opacity(0.22),
                    lineWidth: preview.isFocused ? 1.5 : 1
                )
        }
        .help(preview.displayName)
    }
}
