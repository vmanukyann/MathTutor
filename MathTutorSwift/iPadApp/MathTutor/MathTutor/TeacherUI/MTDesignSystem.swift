import SwiftUI

enum MTTheme {
    static let canvas = Color(.systemGroupedBackground)
    static let ink = Color.primary
    static let secondaryInk = Color.secondary
    static let accent = Color.indigo
    static let accentSoft = Color.indigo.opacity(0.12)
    static let success = Color.green
    static let warning = Color.orange
    static let danger = Color.red

    static let pagePadding: CGFloat = 28
    static let cardRadius: CGFloat = 24
    static let controlRadius: CGFloat = 18
    static let compactRadius: CGFloat = 14
}

struct MTBackground: View {
    var body: some View {
        Color(.systemGroupedBackground)
            .overlay(alignment: .topLeading) {
                LinearGradient(
                    colors: [
                        Color(.systemBackground).opacity(0.92),
                        Color(.secondarySystemGroupedBackground).opacity(0.64),
                        Color(.tertiarySystemGroupedBackground).opacity(0.48)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        .ignoresSafeArea()
    }
}

struct MTGlassPanel<Content: View>: View {
    let alignment: Alignment
    let content: Content

    init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.055), radius: 18, x: 0, y: 10)
    }
}

struct MTFloatingGlass<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .mtLiquidGlass(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 12)
    }
}

struct MTMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = MTTheme.accent

    var body: some View {
        MTGlassPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                    Text(title)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }
}

struct MTStatusPill: View {
    let title: String
    let symbol: String
    var tint: Color = MTTheme.accent

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .mtLiquidGlass(in: Capsule(), tint: tint.opacity(0.08))
            .overlay {
                Capsule().stroke(tint.opacity(0.18), lineWidth: 1)
            }
    }
}

struct MTPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(MTTheme.accent.gradient, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .shadow(color: MTTheme.accent.opacity(configuration.isPressed ? 0.08 : 0.24), radius: 18, x: 0, y: 10)
    }
}

struct MTSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .mtLiquidGlass(in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(.white.opacity(0.24), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}

struct MTIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(width: 48, height: 48)
            .mtLiquidGlass(in: Circle())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
    }
}

struct MTSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.bold())
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MTInfoRow: View {
    let title: String
    let detail: String
    let symbol: String
    var tint: Color = MTTheme.accent

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.82), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
    }
}

extension View {
    func mtPage() -> some View {
        self
            .padding(MTTheme.pagePadding)
            .background(MTBackground())
    }

    @ViewBuilder
    func mtLiquidGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        if #available(iOS 26.0, *) {
            if let tint {
                self.glassEffect(.regular.tint(tint), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}
