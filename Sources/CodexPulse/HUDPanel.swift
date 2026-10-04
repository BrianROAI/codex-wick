#if os(macOS)
import AppKit
import SwiftUI
import CodexPulseCore

private enum HUDInk {
    static let paper = Color(nsColor: .windowBackgroundColor)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let seal = Color(red: 0.64, green: 0.23, blue: 0.18)
    static let hairline = Color.primary.opacity(0.13)
    static let balance = Color(red: 0.12, green: 0.42, blue: 0.84)
    static let derivative = Color(red: 0.92, green: 0.33, blue: 0.14)
    static let weekly = Color(red: 0.12, green: 0.62, blue: 0.34)
    static let shortWindow = Color(red: 0.49, green: 0.31, blue: 0.79)
    static let normal = Color(red: 0.12, green: 0.62, blue: 0.34)
    static let warning = Color(red: 0.93, green: 0.63, blue: 0.12)
    static let high = Color(red: 0.95, green: 0.39, blue: 0.12)
    static let critical = Color(red: 0.82, green: 0.16, blue: 0.20)
}

@MainActor
final class HUDController: NSObject, NSWindowDelegate {
    static let shared = HUDController()

    private var panel: NSPanel?
    private var detailWindow: NSWindow?
    private weak var monitor: MonitorModel?

    private override init() {
        super.init()
    }

    func show(monitor: MonitorModel) {
        self.monitor = monitor

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 292, height: 258),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )

            panel.level = .floating
            panel.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle
            ]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(
                rootView: CompactWickView()
                    .environmentObject(monitor)
            )

            self.panel = panel
        }

        applySettings(monitor: monitor)
    }

    func applySettings(monitor: MonitorModel) {
        self.monitor = monitor
        applyAppearance(monitor: monitor)

        guard let panel else { return }

        panel.ignoresMouseEvents = monitor.hudClickThrough

        if monitor.hudVisible {
            if detailWindow?.isVisible == true {
                panel.orderOut(nil)
            } else {
                reposition()
                panel.orderFrontRegardless()
            }
        } else {
            panel.orderOut(nil)
        }
    }

    func applyAppearance(monitor: MonitorModel) {
        let appearanceName: NSAppearance.Name = monitor.darkMode ? .darkAqua : .aqua
        let appearance = NSAppearance(named: appearanceName)

        NSApp.appearance = appearance

        for window in NSApp.windows {
            window.appearance = appearance
            window.contentView?.appearance = appearance
            window.contentView?.needsDisplay = true
        }

        panel?.appearance = appearance
        panel?.contentView?.appearance = appearance
        panel?.contentView?.needsDisplay = true

        detailWindow?.appearance = appearance
        detailWindow?.contentView?.appearance = appearance
        detailWindow?.contentView?.needsDisplay = true
    }

    func reposition() {
        guard let panel else { return }

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first {
            NSMouseInRect(mouse, $0.frame, false)
        } ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen else { return }

        let visible = screen.visibleFrame
        let margin: CGFloat = 16
        let initialVerticalOffset: CGFloat = 108

        panel.setFrameOrigin(
            NSPoint(
                x: visible.maxX - panel.frame.width - margin,
                y: visible.maxY - panel.frame.height - margin - initialVerticalOffset
            )
        )
    }

    func openDashboard(monitor: MonitorModel) {
        if detailWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 640),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )

            window.title = "Codex Wick"
            window.minSize = NSSize(width: 620, height: 440)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.contentView = NSHostingView(
                rootView: DashboardView()
                    .environmentObject(monitor)
            )
            detailWindow = window
        }

        guard let window = detailWindow else { return }

        applyAppearance(monitor: monitor)

        let screen = panel?.screen ?? NSScreen.main ?? NSScreen.screens.first
        if let screen {
            let visible = screen.visibleFrame
            let size = window.frame.size
            window.setFrameOrigin(
                NSPoint(
                    x: visible.midX - size.width / 2,
                    y: visible.midY - size.height / 2
                )
            )
        }

        panel?.orderOut(nil)

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let closingWindow = notification.object as? NSWindow,
              closingWindow === detailWindow,
              let monitor,
              monitor.hudVisible
        else { return }

        applyAppearance(monitor: monitor)
        panel?.orderFrontRegardless()
    }
}

private struct CompactWickView: View {
    @EnvironmentObject private var monitor: MonitorModel

    var body: some View {
        VStack(spacing: 10) {
            header
            balanceChart
                .frame(height: 82)

            HStack(spacing: 9) {
                AllowanceTile(
                    title: "WEEKLY",
                    used: monitor.current?.weeklyUsedPercent,
                    reset: monitor.current?.weeklyResetsAt,
                    accent: HUDInk.weekly
                )
                AllowanceTile(
                    title: "SHORT",
                    used: monitor.current?.shortWindowUsedPercent,
                    reset: monitor.current?.shortWindowResetsAt,
                    accent: HUDInk.shortWindow
                )
            }
        }
        .padding(13)
        .frame(width: 292, height: 258)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(HUDInk.paper.opacity(0.98))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(HUDInk.ink.opacity(0.16), lineWidth: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            HUDController.shared.openDashboard(monitor: monitor)
        }
        .preferredColorScheme(monitor.darkMode ? .dark : .light)
        .onAppear {
            HUDController.shared.applyAppearance(monitor: monitor)
        }
        .onChange(of: monitor.darkMode) { _, _ in
            HUDController.shared.applyAppearance(monitor: monitor)
        }
        .help("Click to open Codex Wick details")
    }

    private var header: some View {
        HStack(spacing: 9) {
            AnimatedWickIcon(
                ink: HUDInk.ink,
                smoke: HUDInk.muted,
                flame: HUDInk.warning
            )
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 0) {
                Text(balance)
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .monospacedDigit()

                Text("−\(burn)/hr")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(HUDInk.muted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(resetText)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(statusColor)

                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(statusLabel)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(HUDInk.muted)
                }

                Text(monitor.freshnessCompactText(at: monitor.clock))
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundStyle(HUDInk.muted)
            }
        }
    }

    private var balanceChart: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("BALANCE")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HUDInk.muted)

                HStack(spacing: 3) {
                    Rectangle()
                        .fill(HUDInk.derivative)
                        .frame(width: 11, height: 1.4)
                    Text("dC/dt")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(HUDInk.derivative)
                }

                Spacer()
            }

            DualSparkline(
                observations: recentObservations,
                xDomain: chartXDomain
            )
        }
    }

    private var recentObservations: [CodexObservation] {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        return monitor.history
            .filter {
                $0.observedAt >= cutoff && $0.creditBalance != nil
            }
            .sorted { $0.observedAt < $1.observedAt }
    }

    private var chartXDomain: ClosedRange<Date> {
        let latest = recentObservations.last?.observedAt ?? Date()
        let earliestAllowed = latest.addingTimeInterval(-24 * 3600)
        let first = recentObservations.first?.observedAt ?? earliestAllowed
        let lower = max(first, earliestAllowed)
        let upper = max(latest, lower.addingTimeInterval(60))
        return lower...upper
    }

    private var balance: String {
        guard let value = monitor.current?.creditBalance else { return "—" }
        return NumberFormat.compact(value)
    }

    private var burn: String {
        guard let rate = monitor.hourlyBurnRate else { return "—" }
        return NumberFormat.compact(rate)
    }

    private var resetText: String {
        guard let date = monitor.current?.weeklyResetsAt else { return "RESET —" }
        return "RESET \(countdown(to: date))"
    }

    private var statusColor: Color {
        if monitor.isStale(at: monitor.clock) {
            return HUDInk.high
        }

        switch monitor.anomaly.severity {
        case .normal: return HUDInk.normal
        case .warning: return HUDInk.warning
        case .high: return HUDInk.high
        case .critical: return HUDInk.critical
        }
    }

    private var statusLabel: String {
        if monitor.isStale(at: monitor.clock) {
            return "STALE"
        }
        if monitor.lastError != nil {
            return "RETRY"
        }
        return monitor.anomaly.severity >= .warning ? "WATCH" : "NORMAL"
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, date.timeIntervalSinceNow)
        let days = Int(seconds / 86_400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)

        if days > 0 { return "\(days)d \(hours)h" }
        return "\(hours)h"
    }
}

private struct AllowanceTile: View {
    let title: String
    let used: Double?
    let reset: Date?
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(accent)

                Spacer()

                Text(percentText)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .monospacedDigit()
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(HUDInk.ink.opacity(0.10))

                    Capsule()
                        .fill((used ?? 0) >= 100 ? HUDInk.critical : accent)
                        .frame(
                            width: geometry.size.width
                                * min(max(used ?? 0, 0), 100) / 100
                        )
                }
            }
            .frame(height: 4)

            Text(resetText)
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(HUDInk.muted)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(accent.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(HUDInk.hairline)
        }
    }

    private var percentText: String {
        guard let used else { return "—" }
        return String(format: "%.0f%%", used)
    }

    private var resetText: String {
        guard let reset else { return "reset —" }

        let seconds = max(0, reset.timeIntervalSinceNow)
        let hours = Int(seconds / 3_600)

        if hours >= 24 {
            return "reset \(hours / 24)d \(hours % 24)h"
        }

        return "reset \(hours)h"
    }
}

private struct DualSparkline: View {
    let observations: [CodexObservation]
    let xDomain: ClosedRange<Date>

    var body: some View {
        Canvas { context, size in
            let balances = observations.compactMap { observation -> (Date, Double)? in
                guard let balance = observation.creditBalance else { return nil }
                return (observation.observedAt, balance)
            }

            guard balances.count > 1 else { return }

            drawSeries(
                balances,
                in: context,
                size: size,
                xDomain: xDomain,
                color: HUDInk.balance.opacity(0.96),
                width: 2.4
            )

            let derivative = smoothedDerivative(balances)
            if derivative.count > 1 {
                drawSeries(
                    derivative,
                    in: context,
                    size: size,
                    xDomain: xDomain,
                    color: HUDInk.derivative.opacity(0.92),
                    width: 1.8
                )
            }
        }
    }

    private func smoothedDerivative(
        _ points: [(Date, Double)]
    ) -> [(Date, Double)] {
        var raw: [(Date, Double)] = []

        for index in 1..<points.count {
            let elapsed = points[index].0.timeIntervalSince(points[index - 1].0) / 3_600
            guard elapsed > 0 else { continue }
            raw.append((
                points[index].0,
                (points[index].1 - points[index - 1].1) / elapsed
            ))
        }

        guard raw.count > 2 else { return raw }

        return raw.indices.map { index in
            let lower = max(0, index - 2)
            let upper = min(raw.count - 1, index + 2)
            let window = raw[lower...upper]
            let average = window.reduce(0) { partial, point in
                partial + point.1
            } / Double(window.count)
            return (raw[index].0, average)
        }
    }

    private func drawSeries(
        _ points: [(Date, Double)],
        in context: GraphicsContext,
        size: CGSize,
        xDomain: ClosedRange<Date>,
        color: Color,
        width: CGFloat
    ) {
        guard points.count > 1,
              let low = points.map(\.1).min(),
              let high = points.map(\.1).max()
        else { return }

        let yRange = max(high - low, 0.0001)
        let xRange = max(
            xDomain.upperBound.timeIntervalSince(xDomain.lowerBound),
            60
        )
        let verticalInset: CGFloat = 4

        var path = Path()

        for (index, point) in points.enumerated() {
            let elapsed = point.0.timeIntervalSince(xDomain.lowerBound)
            let x = CGFloat(elapsed / xRange) * size.width
            let normalized = (point.1 - low) / yRange
            let y = size.height - verticalInset
                - CGFloat(normalized) * (size.height - verticalInset * 2)

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        context.stroke(
            path,
            with: .color(color),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }
}

private struct HUDLamp: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var bowl = Path()
            bowl.move(to: CGPoint(x: w * 0.08, y: h * 0.62))
            bowl.addQuadCurve(
                to: CGPoint(x: w * 0.78, y: h * 0.62),
                control: CGPoint(x: w * 0.44, y: h * 0.52)
            )
            bowl.addQuadCurve(
                to: CGPoint(x: w * 0.43, y: h * 0.90),
                control: CGPoint(x: w * 0.70, y: h * 0.88)
            )
            bowl.addQuadCurve(
                to: CGPoint(x: w * 0.08, y: h * 0.62),
                control: CGPoint(x: w * 0.18, y: h * 0.89)
            )
            context.stroke(bowl, with: .color(HUDInk.ink), lineWidth: 1.8)

            var wick = Path()
            wick.move(to: CGPoint(x: w * 0.32, y: h * 0.68))
            wick.addCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.46),
                control1: CGPoint(x: w * 0.53, y: h * 0.66),
                control2: CGPoint(x: w * 0.69, y: h * 0.53)
            )
            context.stroke(wick, with: .color(HUDInk.ink), lineWidth: 1.6)

            var flame = Path()
            flame.move(to: CGPoint(x: w * 0.82, y: h * 0.46))
            flame.addQuadCurve(
                to: CGPoint(x: w * 0.84, y: h * 0.15),
                control: CGPoint(x: w * 0.70, y: h * 0.30)
            )
            flame.addQuadCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.46),
                control: CGPoint(x: w * 0.94, y: h * 0.31)
            )
            context.fill(flame, with: .color(HUDInk.ink))
        }
    }
}
#endif
