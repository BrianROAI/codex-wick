#if os(macOS)
import AppKit
import Charts
import SwiftUI
import CodexPulseCore

private enum WickInk {
    static let paper = Color(nsColor: .windowBackgroundColor)
    static let paperDeep = Color(nsColor: .underPageBackgroundColor)
    static let ink = Color.primary
    static let muted = Color.secondary
    static let hairline = Color.primary.opacity(0.14)
    static let seal = Color(red: 0.64, green: 0.23, blue: 0.18)
    static let balance = Color(red: 0.12, green: 0.42, blue: 0.84)
    static let derivative = Color(red: 0.92, green: 0.33, blue: 0.14)
    static let weekly = Color(red: 0.12, green: 0.62, blue: 0.34)
    static let shortWindow = Color(red: 0.49, green: 0.31, blue: 0.79)
    static let normal = Color(red: 0.12, green: 0.62, blue: 0.34)
    static let warning = Color(red: 0.93, green: 0.63, blue: 0.12)
    static let high = Color(red: 0.95, green: 0.39, blue: 0.12)
    static let critical = Color(red: 0.82, green: 0.16, blue: 0.20)
}

struct DashboardView: View {
    @EnvironmentObject private var monitor: MonitorModel
    @State private var showSettings = false
    @State private var hoveredPoint: CodexObservation?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.bottom, 18)

                statusStrip
                    .padding(.bottom, 16)

                primaryMetrics
                    .padding(.bottom, 18)

                historySection
                    .padding(.bottom, 18)

                usageSection
                    .padding(.bottom, 16)

                footer
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 620, minHeight: 440)
        .background(WickInk.paper)
        .foregroundStyle(WickInk.ink)
        .preferredColorScheme(monitor.darkMode ? .dark : .light)
        .onAppear {
            HUDController.shared.applyAppearance(monitor: monitor)
        }
        .onChange(of: monitor.darkMode) { _, _ in
            HUDController.shared.applyAppearance(monitor: monitor)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(isPresented: $showSettings)
                .environmentObject(monitor)
        }
    }

    private var masthead: some View {
        HStack(alignment: .center, spacing: 16) {
            AnimatedWickIcon(
                ink: WickInk.ink,
                smoke: WickInk.muted,
                flame: WickInk.warning
            )
            .frame(width: 66, height: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Wick")
                    .font(.system(size: 26, weight: .semibold, design: .serif))

                Text("One Wick Is Enough.")
                    .font(.system(size: 13, weight: .regular, design: .serif))
                    .foregroundStyle(WickInk.muted)
            }

            Spacer()

            SealLabel(text: "節用")

            if monitor.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .tint(WickInk.ink)
            }

            Button {
                Task { await monitor.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(InkButtonStyle())
            .help("Refresh")

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(InkButtonStyle())
            .help("Settings")
        }
    }

    private var statusStrip: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusInk)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(monitor.anomaly.headline)
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                Text(monitor.anomaly.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(WickInk.muted)
                    .lineLimit(1)
            }

            Spacer()

            Text(severityLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.2)
                .foregroundStyle(statusInk)
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(WickInk.hairline)
                .frame(height: 1)
        }
    }

    private var primaryMetrics: some View {
        HStack(alignment: .top, spacing: 0) {
            InkMetric(
                eyebrow: "CREDITS",
                value: currentCredits,
                detail: monitor.current?.planType?.uppercased() ?? "BALANCE",
                accent: WickInk.balance
            )

            metricDivider

            InkMetric(
                eyebrow: "BURN",
                value: burnRateText,
                detail: "credits / hour",
                accent: WickInk.derivative
            )

            metricDivider

            InkMetric(
                eyebrow: "RUNWAY",
                value: runwayText,
                detail: "at current burn",
                accent: WickInk.warning
            )

            metricDivider

            InkMetric(
                eyebrow: "WEEKLY RESET",
                value: resetCountdown,
                detail: weeklyState,
                accent: WickInk.weekly
            )
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(WickInk.hairline)
            .frame(width: 1, height: 72)
            .padding(.horizontal, 22)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Credit balance")
                    .font(.system(size: 17, weight: .semibold, design: .serif))

                Text("last 24 hours")
                    .font(.system(size: 11))
                    .foregroundStyle(WickInk.muted)

                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(WickInk.balance)
                            .frame(width: 14, height: 1.8)
                        Text("credits")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(WickInk.balance)
                    }

                    HStack(spacing: 4) {
                        Rectangle()
                            .fill(WickInk.derivative)
                            .frame(width: 14, height: 1.8)
                        Text("dC/dt")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(WickInk.derivative)
                    }
                }

                Spacer()

                Text(lastMinuteAndHour)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(WickInk.muted)
            }

            Chart {
                ForEach(chartPoints) { point in
                    if let balance = point.creditBalance {
                        LineMark(
                            x: .value("Time", point.observedAt),
                            y: .value("Credits", balance),
                            series: .value("Series", "Credits")
                        )
                        .foregroundStyle(by: .value("Series", "Credits"))
                        .lineStyle(StrokeStyle(lineWidth: 1.9, lineCap: .round))
                        .interpolationMethod(.linear)
                    }
                }

                ForEach(DerivativeOverlay.make(from: chartPoints, targetY: chartYDomain)) { point in
                    LineMark(
                        x: .value("Time", point.observedAt),
                        y: .value("dC/dt", point.mappedY),
                        series: .value("Series", "dC/dt")
                    )
                    .foregroundStyle(by: .value("Series", "dC/dt"))
                    .lineStyle(StrokeStyle(lineWidth: 1.25, lineCap: .round))
                    .interpolationMethod(.linear)
                }

                if let hoveredPoint,
                   let hoveredBalance = hoveredPoint.creditBalance {
                    PointMark(
                        x: .value("Time", hoveredPoint.observedAt),
                        y: .value("Credits", hoveredBalance)
                    )
                    .foregroundStyle(WickInk.balance)
                    .symbolSize(42)
                    .annotation(position: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NumberFormat.credits(hoveredBalance))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            Text(hoveredPoint.observedAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 10))
                                .foregroundStyle(WickInk.muted)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 7)
                        .background(WickInk.paper)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(WickInk.hairline)
                        }
                    }
                }
            }
            .chartForegroundStyleScale([
                "Credits": WickInk.balance,
                "dC/dt": WickInk.derivative
            ])
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) {
                    AxisValueLabel()
                        .foregroundStyle(WickInk.muted)
                        .font(.system(size: 10))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisValueLabel()
                        .foregroundStyle(WickInk.muted)
                        .font(.system(size: 10))
                }
            }
            .chartXScale(domain: chartXDomain)
            .chartYScale(domain: chartYDomain)
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location):
                                let plotFrame = geometry[proxy.plotFrame!]
                                let x = location.x - plotFrame.origin.x
                                guard x >= 0,
                                      x <= plotFrame.width,
                                      let date: Date = proxy.value(atX: x)
                                else {
                                    hoveredPoint = nil
                                    return
                                }

                                hoveredPoint = chartPoints.min {
                                    abs($0.observedAt.timeIntervalSince(date))
                                    < abs($1.observedAt.timeIntervalSince(date))
                                }

                            case .ended:
                                hoveredPoint = nil
                            }
                        }
                }
            }
            .frame(height: 168)

            if chartPoints.count < 2 {
                Text("History will fill in as Codex Wick samples your account.")
                    .font(.system(size: 11))
                    .foregroundStyle(WickInk.muted)
            }
        }
        .padding(.top, 18)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WickInk.hairline)
                .frame(height: 1)
        }
    }

    private var usageSection: some View {
        HStack(alignment: .top, spacing: 14) {
            usageBlock(
                title: "Weekly allowance",
                usedPercent: monitor.current?.weeklyUsedPercent,
                resetDate: monitor.current?.weeklyResetsAt,
                accent: WickInk.weekly
            )
            .padding(14)
            .frame(minHeight: 104)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(WickInk.paperDeep.opacity(0.52))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WickInk.hairline)
            }

            usageBlock(
                title: "Short window",
                usedPercent: monitor.current?.shortWindowUsedPercent,
                resetDate: monitor.current?.shortWindowResetsAt,
                accent: WickInk.shortWindow
            )
            .padding(14)
            .frame(minHeight: 104)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(WickInk.paperDeep.opacity(0.52))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WickInk.hairline)
            }
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WickInk.hairline)
                .frame(height: 1)
        }
    }

    private func usageBlock(
        title: String,
        usedPercent: Double?,
        resetDate: Date?,
        accent: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(accent)

            if let usedPercent {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(WickInk.ink.opacity(0.10))
                        Rectangle()
                            .fill(usedPercent >= 100 ? WickInk.critical : accent)
                            .frame(width: geometry.size.width * min(max(usedPercent, 0), 100) / 100)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(String(format: "%.0f%% used", usedPercent))
                    Spacer()
                    Text(resetDate.map { "reset " + countdown(to: $0) } ?? "reset unknown")
                }
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(WickInk.muted)
            } else {
                Text("Not reported")
                    .font(.system(size: 11))
                    .foregroundStyle(WickInk.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        Group {
            if let error = monitor.lastError {
                Text(error)
                    .foregroundStyle(WickInk.seal)
                    .textSelection(.enabled)
            } else {
                Text("Local Codex telemetry · no OpenAI credentials stored by Codex Wick")
                    .foregroundStyle(WickInk.muted)
            }
        }
        .font(.system(size: 10))
        .padding(.top, 14)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(WickInk.hairline)
                .frame(height: 1)
        }
    }

    private var chartPoints: [CodexObservation] {
        let cutoff = Date().addingTimeInterval(-24 * 3600)
        return monitor.history
            .filter {
                $0.observedAt >= cutoff && $0.creditBalance != nil
            }
            .sorted { $0.observedAt < $1.observedAt }
    }

    private var chartXDomain: ClosedRange<Date> {
        let latest = chartPoints.last?.observedAt ?? Date()
        let earliestAllowed = latest.addingTimeInterval(-24 * 3600)
        let first = chartPoints.first?.observedAt ?? earliestAllowed
        let lower = max(first, earliestAllowed)
        let upper = max(latest, lower.addingTimeInterval(60))
        return lower...upper
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = chartPoints.compactMap(\.creditBalance)
        guard let low = values.min(),
              let high = values.max()
        else {
            return 0...1
        }

        let spread = high - low
        let padding = max(spread * 0.06, max(high * 0.005, 75))
        let lower = max(0, low - padding)
        let upper = max(high + padding, lower + 1)
        return lower...upper
    }

    private var currentCredits: String {
        if monitor.current?.unlimitedCredits == true { return "∞" }
        return NumberFormat.credits(monitor.current?.creditBalance)
    }

    private var burnRateText: String {
        guard let rate = monitor.hourlyBurnRate else { return "—" }
        return NumberFormat.compact(rate)
    }

    private var runwayText: String {
        guard let balance = monitor.current?.creditBalance,
              let burn = monitor.hourlyBurnRate,
              burn > 0
        else { return "—" }

        return durationText(hours: balance / burn)
    }

    private var resetCountdown: String {
        guard let date = monitor.current?.weeklyResetsAt else { return "—" }
        return countdown(to: date)
    }

    private var weeklyState: String {
        guard let used = monitor.current?.weeklyUsedPercent else {
            return "allowance"
        }

        if used >= 100 {
            return "weekly exhausted"
        }

        return String(format: "%.0f%% remaining", max(0, 100 - used))
    }

    private var lastMinuteAndHour: String {
        let minute = NumberFormat.delta(monitor.change(seconds: 60)?.creditDrawdown)
        let hour = NumberFormat.delta(monitor.change(seconds: 3600)?.creditDrawdown)
        return "1m \(minute)   1h \(hour)"
    }

    private func countdown(to date: Date) -> String {
        let seconds = max(0, date.timeIntervalSinceNow)
        let days = Int(seconds / 86_400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3_600) / 60)

        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func durationText(hours: Double) -> String {
        guard hours.isFinite, hours >= 0 else { return "—" }

        let totalHours = Int(hours.rounded(.down))
        if totalHours >= 48 {
            return "\(totalHours / 24)d \(totalHours % 24)h"
        }
        return "\(totalHours)h"
    }

    private var statusInk: Color {
        switch monitor.anomaly.severity {
        case .normal: return WickInk.normal
        case .warning: return WickInk.warning
        case .high: return WickInk.high
        case .critical: return WickInk.critical
        }
    }

    private var severityLabel: String {
        switch monitor.anomaly.severity {
        case .normal: return "NORMAL"
        case .warning: return "WATCH"
        case .high: return "HIGH"
        case .critical: return "CRITICAL"
        }
    }
}

private struct InkMetric: View {
    let eyebrow: String
    let value: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .tracking(1.3)
                .foregroundStyle(WickInk.muted)

            Text(value)
                .font(.system(size: 29, weight: .medium, design: .serif))
                .foregroundStyle(accent)
                .monospacedDigit()
                .lineLimit(1)

            Text(detail)
                .font(.system(size: 10))
                .foregroundStyle(WickInk.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SealLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .serif))
            .foregroundStyle(WickInk.seal)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(WickInk.seal, lineWidth: 1.3)
            }
    }
}

private struct InkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(WickInk.ink)
            .frame(width: 30, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(configuration.isPressed ? WickInk.ink.opacity(0.08) : .clear)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(WickInk.hairline, lineWidth: 1)
            }
    }
}

private struct LampMark: View {
    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            var bowl = Path()
            bowl.move(to: CGPoint(x: w * 0.10, y: h * 0.60))
            bowl.addQuadCurve(
                to: CGPoint(x: w * 0.82, y: h * 0.60),
                control: CGPoint(x: w * 0.47, y: h * 0.50)
            )
            bowl.addQuadCurve(
                to: CGPoint(x: w * 0.46, y: h * 0.88),
                control: CGPoint(x: w * 0.72, y: h * 0.88)
            )
            bowl.addQuadCurve(
                to: CGPoint(x: w * 0.10, y: h * 0.60),
                control: CGPoint(x: w * 0.20, y: h * 0.87)
            )
            context.stroke(bowl, with: .color(WickInk.ink), lineWidth: 2.1)

            var spout = Path()
            spout.move(to: CGPoint(x: w * 0.80, y: h * 0.59))
            spout.addQuadCurve(
                to: CGPoint(x: w * 0.96, y: h * 0.60),
                control: CGPoint(x: w * 0.90, y: h * 0.52)
            )
            context.stroke(spout, with: .color(WickInk.ink), lineWidth: 2)

            var wick = Path()
            wick.move(to: CGPoint(x: w * 0.40, y: h * 0.66))
            wick.addCurve(
                to: CGPoint(x: w * 0.84, y: h * 0.46),
                control1: CGPoint(x: w * 0.58, y: h * 0.63),
                control2: CGPoint(x: w * 0.72, y: h * 0.51)
            )
            context.stroke(wick, with: .color(WickInk.ink), lineWidth: 2)

            var flame = Path()
            flame.move(to: CGPoint(x: w * 0.84, y: h * 0.46))
            flame.addQuadCurve(
                to: CGPoint(x: w * 0.86, y: h * 0.18),
                control: CGPoint(x: w * 0.72, y: h * 0.32)
            )
            flame.addQuadCurve(
                to: CGPoint(x: w * 0.84, y: h * 0.46),
                control: CGPoint(x: w * 0.96, y: h * 0.33)
            )
            context.fill(flame, with: .color(WickInk.ink))

            var smoke = Path()
            smoke.move(to: CGPoint(x: w * 0.72, y: h * 0.47))
            smoke.addCurve(
                to: CGPoint(x: w * 0.78, y: h * 0.12),
                control1: CGPoint(x: w * 0.89, y: h * 0.36),
                control2: CGPoint(x: w * 0.64, y: h * 0.24)
            )
            context.stroke(smoke, with: .color(WickInk.muted.opacity(0.38)), lineWidth: 1.2)
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var monitor: MonitorModel
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("Codex Wick")
                    .font(.system(size: 23, weight: .semibold, design: .serif))
                Spacer()
                SealLabel(text: "節用")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Polling")
                    .font(.system(size: 12, weight: .semibold, design: .serif))

                Picker("Polling interval", selection: $monitor.pollIntervalSeconds) {
                    Text("15 sec").tag(15.0)
                    Text("30 sec").tag(30.0)
                    Text("1 min").tag(60.0)
                    Text("5 min").tag(300.0)
                }
                .pickerStyle(.segmented)
            }

            Divider()

            Toggle("Show floating Wick", isOn: $monitor.hudVisible)
            Toggle("Floating Wick ignores mouse clicks", isOn: $monitor.hudClickThrough)
                .disabled(!monitor.hudVisible)
            Toggle("Notify on unexpected drawdown", isOn: $monitor.alertsEnabled)
            Toggle("Dark mode", isOn: $monitor.darkMode)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Codex executable")
                    .font(.system(size: 12, weight: .semibold, design: .serif))

                TextField(
                    "Auto-detect, or enter /path/to/codex",
                    text: $monitor.codexPathOverride
                )
                .textFieldStyle(.roundedBorder)

                Text("Leave blank to auto-detect Codex.")
                    .font(.system(size: 10))
                    .foregroundStyle(WickInk.muted)
            }

            HStack {
                Spacer()
                Button("Cancel") { isPresented = false }
                Button("Save") {
                    monitor.saveSettings()
                    isPresented = false
                    Task { await monitor.refresh() }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(26)
        .frame(width: 520)
        .background(WickInk.paper)
        .foregroundStyle(WickInk.ink)
        .preferredColorScheme(monitor.darkMode ? .dark : .light)
        .onAppear {
            HUDController.shared.applyAppearance(monitor: monitor)
        }
        .onChange(of: monitor.darkMode) { _, _ in
            HUDController.shared.applyAppearance(monitor: monitor)
        }
    }
}
#endif
