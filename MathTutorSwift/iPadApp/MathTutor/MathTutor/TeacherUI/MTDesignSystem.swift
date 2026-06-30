import SwiftUI

enum MTTheme {
    static let notebookPaper = Color(hex: 0xF4F1E6)
    static let gridLine = Color(hex: 0xD8D2BD)
    static let graphiteInk = Color(hex: 0x202421)
    static let chalkboardGreen = Color(hex: 0x1F4D3A)
    static let labGreen = Color(hex: 0x3F7D5A)
    static let chemicalGold = Color(hex: 0xC6A04A)
    static let paleYellowNote = Color(hex: 0xE9D88D)
    static let errorRust = Color(hex: 0xA64B3C)
    static let deepBlackGreen = Color(hex: 0x0D1F18)
    static let disabledGray = Color(hex: 0x9A9A8C)

    static let canvas = notebookPaper
    static let ink = graphiteInk
    static let secondaryInk = graphiteInk.opacity(0.68)
    static let accent = chalkboardGreen
    static let accentSoft = labGreen.opacity(0.14)
    static let success = labGreen
    static let warning = chemicalGold
    static let danger = errorRust

    static let pagePadding: CGFloat = 28
    static let cardRadius: CGFloat = 8
    static let controlRadius: CGFloat = 8
    static let compactRadius: CGFloat = 6
}

struct MTBackground: View {
    var body: some View {
        NotebookGridBackground()
            .ignoresSafeArea()
    }
}

struct NotebookGridBackground: View {
    var spacing: CGFloat = 28

    var body: some View {
        MTTheme.notebookPaper
            .overlay {
                Canvas { context, size in
                    var path = Path()
                    var x: CGFloat = 0
                    while x <= size.width {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        x += spacing
                    }

                    var y: CGFloat = 0
                    while y <= size.height {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        y += spacing
                    }

                    context.stroke(path, with: .color(MTTheme.gridLine.opacity(0.55)), lineWidth: 0.7)
                }
                .allowsHitTesting(false)
            }
    }
}

struct MTNotebookPanel<Content: View>: View {
    let alignment: Alignment
    let content: Content

    init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: alignment)
            .padding(18)
            .background(MTTheme.notebookPaper, in: RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.cardRadius, style: .continuous)
                    .stroke(MTTheme.gridLine, lineWidth: 1)
            }
    }
}

typealias MTGlassPanel<Content: View> = MTNotebookPanel<Content>

struct MTControlStrip<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(8)
            .background(MTTheme.notebookPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(MTTheme.gridLine, lineWidth: 1)
            }
    }
}

typealias MTFloatingGlass<Content: View> = MTControlStrip<Content>

struct MTMetricCard: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = MTTheme.accent

    var body: some View {
        MTNotebookPanel(alignment: .leading) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)

                Text(value)
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .foregroundStyle(MTTheme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(MTTheme.secondaryInk)
                    .lineLimit(2)
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
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MTTheme.notebookPaper.opacity(0.94), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                    .stroke(tint.opacity(0.36), lineWidth: 1)
            }
    }
}

struct MTPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(MTTheme.notebookPaper)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(MTTheme.chalkboardGreen, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

struct MTSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(MTTheme.graphiteInk)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(MTTheme.notebookPaper, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(MTTheme.gridLine, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct MTLabeledControlButton: ButtonStyle {
    var tint: Color = MTTheme.graphiteInk
    var fill: Color = MTTheme.notebookPaper
    var isFilled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout.weight(.semibold))
            .foregroundStyle(isFilled ? MTTheme.notebookPaper : tint)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(isFilled ? fill : MTTheme.notebookPaper, in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(isFilled ? fill.opacity(0.35) : MTTheme.gridLine, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.74 : 1)
    }
}

struct MTIconButton: ButtonStyle {
    var tint: Color = MTTheme.graphiteInk

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 48, height: 48)
            .background(MTTheme.notebookPaper.opacity(0.96), in: RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: MTTheme.controlRadius, style: .continuous)
                    .stroke(MTTheme.gridLine, lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.68 : 1)
    }
}

struct MTSectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(MTTheme.ink)
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(MTTheme.secondaryInk)
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
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(MTTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(MTTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(MTTheme.notebookPaper.opacity(0.78), in: RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: MTTheme.compactRadius, style: .continuous)
                .stroke(MTTheme.gridLine.opacity(0.82), lineWidth: 1)
        }
    }
}

extension View {
    func mtPage() -> some View {
        self
            .padding(MTTheme.pagePadding)
            .background(MTBackground())
    }

    func mtNotebookSurface<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        self
            .background((tint ?? MTTheme.notebookPaper).opacity(0.96), in: shape)
            .overlay {
                shape.stroke(MTTheme.gridLine, lineWidth: 1)
            }
    }

    func mtLiquidGlass<S: Shape>(in shape: S, tint: Color? = nil) -> some View {
        mtNotebookSurface(in: shape, tint: tint)
    }
}

private extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
