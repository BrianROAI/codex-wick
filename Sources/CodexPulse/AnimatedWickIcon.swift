#if os(macOS)
import SwiftUI

/// Shared in-app Codex Wick mark.
///
/// Visual contract:
/// - exactly two rush wicks are always present;
/// - one wick is lit and gently flickers;
/// - the second wick is extinguished, charred, and releases rising smoke.
///
/// App icon and favicon remain static. This animation is used only inside
/// the running macOS app.
struct AnimatedWickIcon: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let ink: Color
    let smoke: Color
    let flame: Color

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 15.0,
                paused: reduceMotion
            )
        ) { timeline in
            Canvas { context, size in
                let time = reduceMotion
                    ? 0
                    : timeline.date.timeIntervalSinceReferenceDate

                drawLamp(in: &context, size: size)
                drawWicks(in: &context, size: size)
                drawFlame(in: &context, size: size, time: time)
                drawSmoke(in: &context, size: size, time: time)
            }
        }
        .accessibilityHidden(true)
    }

    private func drawLamp(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let w = size.width
        let h = size.height

        var bowl = Path()
        bowl.move(to: CGPoint(x: w * 0.08, y: h * 0.66))
        bowl.addQuadCurve(
            to: CGPoint(x: w * 0.82, y: h * 0.64),
            control: CGPoint(x: w * 0.46, y: h * 0.54)
        )
        bowl.addQuadCurve(
            to: CGPoint(x: w * 0.45, y: h * 0.91),
            control: CGPoint(x: w * 0.70, y: h * 0.91)
        )
        bowl.addQuadCurve(
            to: CGPoint(x: w * 0.08, y: h * 0.66),
            control: CGPoint(x: w * 0.19, y: h * 0.90)
        )
        context.stroke(
            bowl,
            with: .color(ink),
            style: StrokeStyle(
                lineWidth: max(1.2, w * 0.045),
                lineCap: .round,
                lineJoin: .round
            )
        )

        var rim = Path()
        rim.move(to: CGPoint(x: w * 0.10, y: h * 0.65))
        rim.addQuadCurve(
            to: CGPoint(x: w * 0.86, y: h * 0.64),
            control: CGPoint(x: w * 0.47, y: h * 0.57)
        )
        context.stroke(
            rim,
            with: .color(ink.opacity(0.82)),
            style: StrokeStyle(
                lineWidth: max(0.9, w * 0.028),
                lineCap: .round
            )
        )

        var lip = Path()
        lip.move(to: CGPoint(x: w * 0.80, y: h * 0.64))
        lip.addQuadCurve(
            to: CGPoint(x: w * 0.96, y: h * 0.63),
            control: CGPoint(x: w * 0.90, y: h * 0.56)
        )
        context.stroke(
            lip,
            with: .color(ink),
            style: StrokeStyle(
                lineWidth: max(1.0, w * 0.034),
                lineCap: .round
            )
        )
    }

    private func drawWicks(
        in context: inout GraphicsContext,
        size: CGSize
    ) {
        let w = size.width
        let h = size.height

        var litWick = Path()
        litWick.move(to: CGPoint(x: w * 0.33, y: h * 0.72))
        litWick.addCurve(
            to: litTip(size),
            control1: CGPoint(x: w * 0.53, y: h * 0.69),
            control2: CGPoint(x: w * 0.70, y: h * 0.57)
        )
        context.stroke(
            litWick,
            with: .color(ink),
            style: StrokeStyle(
                lineWidth: max(1.1, w * 0.038),
                lineCap: .round
            )
        )

        var spentWick = Path()
        spentWick.move(to: CGPoint(x: w * 0.43, y: h * 0.75))
        spentWick.addCurve(
            to: spentTip(size),
            control1: CGPoint(x: w * 0.52, y: h * 0.71),
            control2: CGPoint(x: w * 0.61, y: h * 0.61)
        )
        context.stroke(
            spentWick,
            with: .color(ink.opacity(0.86)),
            style: StrokeStyle(
                lineWidth: max(1.0, w * 0.032),
                lineCap: .round
            )
        )

        let spent = spentTip(size)
        let charSize = max(2.0, w * 0.065)
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: spent.x - charSize / 2,
                    y: spent.y - charSize / 2,
                    width: charSize,
                    height: charSize
                )
            ),
            with: .color(ink)
        )
    }

    private func drawFlame(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let w = size.width
        let h = size.height
        let base = litTip(size)

        let fast = sin(time * 9.4)
        let slow = sin(time * 4.8 + 0.9)
        let flicker = fast * 0.055 + slow * 0.035
        let lean = sin(time * 6.1 + 0.4) * w * 0.035

        let flameHeight = h * (0.27 + flicker)
        let halfWidth = w * (0.085 + 0.012 * sin(time * 7.3))

        var outer = Path()
        outer.move(to: base)
        outer.addQuadCurve(
            to: CGPoint(
                x: base.x + lean,
                y: base.y - flameHeight
            ),
            control: CGPoint(
                x: base.x - halfWidth * 1.4,
                y: base.y - flameHeight * 0.54
            )
        )
        outer.addQuadCurve(
            to: base,
            control: CGPoint(
                x: base.x + halfWidth * 1.5,
                y: base.y - flameHeight * 0.50
            )
        )
        context.fill(outer, with: .color(flame))

        var inner = Path()
        inner.move(to: CGPoint(x: base.x, y: base.y - h * 0.015))
        inner.addQuadCurve(
            to: CGPoint(
                x: base.x + lean * 0.55,
                y: base.y - flameHeight * 0.67
            ),
            control: CGPoint(
                x: base.x - halfWidth * 0.55,
                y: base.y - flameHeight * 0.38
            )
        )
        inner.addQuadCurve(
            to: CGPoint(x: base.x, y: base.y - h * 0.015),
            control: CGPoint(
                x: base.x + halfWidth * 0.60,
                y: base.y - flameHeight * 0.35
            )
        )
        context.fill(
            inner,
            with: .color(Color.white.opacity(0.56))
        )
    }

    private func drawSmoke(
        in context: inout GraphicsContext,
        size: CGSize,
        time: TimeInterval
    ) {
        let w = size.width
        let h = size.height
        let spent = spentTip(size)

        for index in 0..<3 {
            let phase = (
                time * 0.22 + Double(index) / 3.0
            ).truncatingRemainder(dividingBy: 1.0)

            let rise = CGFloat(phase) * h * 0.30
            let fade = max(0, 1.0 - phase)
            let drift = CGFloat(
                sin(time * 1.25 + Double(index) * 1.7)
            ) * w * 0.055

            let start = CGPoint(
                x: spent.x + drift * 0.22,
                y: spent.y - rise
            )
            let end = CGPoint(
                x: spent.x + drift,
                y: spent.y - rise - h * 0.14
            )

            var wisp = Path()
            wisp.move(to: start)
            wisp.addCurve(
                to: end,
                control1: CGPoint(
                    x: start.x + w * 0.07,
                    y: start.y - h * 0.045
                ),
                control2: CGPoint(
                    x: end.x - w * 0.06,
                    y: end.y + h * 0.045
                )
            )

            context.stroke(
                wisp,
                with: .color(
                    smoke.opacity(0.10 + fade * 0.34)
                ),
                style: StrokeStyle(
                    lineWidth: max(0.8, w * 0.024),
                    lineCap: .round
                )
            )
        }
    }

    private func litTip(_ size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * 0.82,
            y: size.height * 0.52
        )
    }

    private func spentTip(_ size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width * 0.66,
            y: size.height * 0.57
        )
    }
}
#endif
