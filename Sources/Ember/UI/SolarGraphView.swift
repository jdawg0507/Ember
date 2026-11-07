import SwiftUI

/// Beautiful 24-hour continuous solar timeline graph.
public struct SolarGraphView: View {
    let solarTimes: SolarTimes
    let currentKelvin: Double
    let currentPhase: SolarPhase

    public init(solarTimes: SolarTimes, currentKelvin: Double, currentPhase: SolarPhase) {
        self.solarTimes = solarTimes
        self.currentKelvin = currentKelvin
        self.currentPhase = currentPhase
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Canvas { context, size in
                drawSolarGraph(context: context, size: size)
            }
            .frame(height: 90)
            .background(Color.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            // Timeline labels below graph
            HStack {
                Label(timeFormatter.string(from: solarTimes.sunrise), systemImage: "sunrise.fill")
                    .foregroundColor(.orange.opacity(0.85))
                Spacer()
                Label(timeFormatter.string(from: solarTimes.sunset), systemImage: "sunset.fill")
                    .foregroundColor(.orange)
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Drawing Logic

    private func drawSolarGraph(context: GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height
        let calendar = Calendar.current
        let now = Date()

        // Fraction of day elapsed (0.0 to 1.0)
        let dayStart = calendar.startOfDay(for: now)
        let secondsInDay: Double = 86400.0
        let currentSeconds = max(now.timeIntervalSince(dayStart), 0)
        let currentProgress = min(currentSeconds / secondsInDay, 1.0)

        // Sunrise and sunset fractions
        let sunriseSeconds = max(solarTimes.sunrise.timeIntervalSince(dayStart), 0)
        let sunsetSeconds = max(solarTimes.sunset.timeIntervalSince(dayStart), 0)
        let sunriseX = width * CGFloat(sunriseSeconds / secondsInDay)
        let sunsetX = width * CGFloat(sunsetSeconds / secondsInDay)

        // Baseline horizon Y position
        let horizonY = height * 0.65

        // 1. Draw horizon reference line
        var horizonPath = Path()
        horizonPath.move(to: CGPoint(x: 0, y: horizonY))
        horizonPath.addLine(to: CGPoint(x: width, y: horizonY))
        context.stroke(
            horizonPath,
            with: .color(Color.white.opacity(0.12)),
            style: StrokeStyle(lineWidth: 1, dash: [4, 4])
        )

        // 2. Draw 24-hour sinusoidal solar path
        var curvePath = Path()
        var fillPath = Path()

        let steps = 100
        var points: [CGPoint] = []

        for i in 0...steps {
            let t = Double(i) / Double(steps)
            let x = width * CGFloat(t)
            let dateAtT = dayStart.addingTimeInterval(t * secondsInDay)

            // Calculate elevation for point
            let elev = SolarEngine.solarElevation(
                latitude: UserLocation.fallback.latitude,
                longitude: UserLocation.fallback.longitude,
                date: dateAtT
            )

            // Map elevation (-60° to +65°) to graph Y
            let normalizedY = (elev + 40.0) / 100.0
            let y = height * (1.0 - CGFloat(normalizedY) * 0.75 - 0.1)

            points.append(CGPoint(x: x, y: y))
        }

        if let first = points.first {
            curvePath.move(to: first)
            fillPath.move(to: CGPoint(x: 0, y: height))
            fillPath.addLine(to: first)

            for pt in points.dropFirst() {
                curvePath.addLine(to: pt)
                fillPath.addLine(to: pt)
            }

            fillPath.addLine(to: CGPoint(x: width, y: height))
            fillPath.closeSubpath()
        }

        // Fill with warm sunlight gradient
        let gradient = Gradient(colors: [
            Color.orange.opacity(0.35),
            Color.yellow.opacity(0.15),
            Color.clear
        ])
        context.fill(
            fillPath,
            with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: width * 0.5, y: height * 0.1),
                endPoint: CGPoint(x: width * 0.5, y: height)
            )
        )

        // Stroke solar curve line
        let curveGradient = Gradient(colors: [
            Color.indigo.opacity(0.6),
            Color.orange,
            Color.yellow,
            Color.orange,
            Color.indigo.opacity(0.6)
        ])
        context.stroke(
            curvePath,
            with: .linearGradient(
                curveGradient,
                startPoint: CGPoint(x: 0, y: horizonY),
                endPoint: CGPoint(x: width, y: horizonY)
            ),
            lineWidth: 2.2
        )

        // 3. Draw vertical sunrise / sunset markers
        context.draw(
            Text("☼").font(.system(size: 10)).foregroundColor(.orange.opacity(0.7)),
            at: CGPoint(x: sunriseX, y: horizonY - 10)
        )
        context.draw(
            Text("☽").font(.system(size: 10)).foregroundColor(.orange.opacity(0.7)),
            at: CGPoint(x: sunsetX, y: horizonY - 10)
        )

        // 4. Current time indicator dot
        let currentX = width * CGFloat(currentProgress)
        // Interpolate current Y
        let currentElev = SolarEngine.solarElevation(
            latitude: UserLocation.fallback.latitude,
            longitude: UserLocation.fallback.longitude,
            date: now
        )
        let normCurrentY = (currentElev + 40.0) / 100.0
        let currentY = height * (1.0 - CGFloat(normCurrentY) * 0.75 - 0.1)

        // Outer glow circle
        let glowRect = CGRect(x: currentX - 9, y: currentY - 9, width: 18, height: 18)
        context.fill(
            Path(ellipseIn: glowRect),
            with: .color(warmColor(for: currentKelvin).opacity(0.28))
        )

        // Inner solid dot
        let dotRect = CGRect(x: currentX - 4.5, y: currentY - 4.5, width: 9, height: 9)
        context.fill(
            Path(ellipseIn: dotRect),
            with: .color(warmColor(for: currentKelvin))
        )
        context.stroke(
            Path(ellipseIn: dotRect),
            with: .color(.white),
            lineWidth: 1.5
        )
    }

    private func warmColor(for kelvin: Double) -> Color {
        if kelvin <= 2200 {
            return Color.red
        } else if kelvin <= 3600 {
            return Color.orange
        } else if kelvin <= 5000 {
            return Color.yellow
        } else {
            return Color.white
        }
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
}

