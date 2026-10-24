import SwiftUI

extension Theme {
    var colors: [Color] {
        switch self {
        case .ocean: return [Color(red: 0.05, green: 0.25, blue: 0.45), Color(red: 0.10, green: 0.55, blue: 0.65)]
        case .forest: return [Color(red: 0.07, green: 0.28, blue: 0.20), Color(red: 0.30, green: 0.55, blue: 0.35)]
        case .sunset: return [Color(red: 0.55, green: 0.20, blue: 0.35), Color(red: 0.95, green: 0.55, blue: 0.35)]
        case .dusk: return [Color(red: 0.15, green: 0.10, blue: 0.35), Color(red: 0.45, green: 0.30, blue: 0.65)]
        case .graphite: return [Color(red: 0.10, green: 0.10, blue: 0.12), Color(red: 0.30, green: 0.32, blue: 0.36)]
        }
    }
}

struct BreakView: View {
    @ObservedObject var scheduler: BreakScheduler
    @ObservedObject var settings: Settings
    @ObservedObject var stats: Stats

    var body: some View {
        ZStack {
            LinearGradient(colors: settings.theme.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            TimelineView(.periodic(from: Date(), by: 0.25)) { context in
                content(now: context.date)
            }
        }
        .ignoresSafeArea()
    }

    private func content(now: Date) -> some View {
        let total = scheduler.breakDuration
        let remaining = max(0, (scheduler.breakEndsAt ?? now).timeIntervalSince(now))
        let progress = total > 0 ? 1 - remaining / total : 1

        return VStack(spacing: 32) {
            Image(systemName: "eye")
                .font(.system(size: 56, weight: .light))
            Text(settings.message)
                .font(.system(size: 44, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
            ZStack {
                Circle().stroke(Color.white.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.25), value: progress)
                Text(Self.clock(remaining))
                    .font(.system(size: 36, weight: .medium, design: .rounded).monospacedDigit())
            }
            .frame(width: 170, height: 170)
            skipArea(now: now)
            if stats.streak > 0 {
                Label("\(stats.streak) break\(stats.streak == 1 ? "" : "s") in a row", systemImage: "flame")
                    .font(.system(size: 15, weight: .medium))
                    .opacity(0.8)
            }
        }
        .foregroundColor(.white)
        .padding(60)
    }

    @ViewBuilder
    private func skipArea(now: Date) -> some View {
        if settings.skipMode == .never {
            Text("Skipping is turned off").font(.system(size: 14)).opacity(0.6)
        } else if scheduler.canSkip(at: now) {
            VStack(spacing: 10) {
                Button("Skip  ␣") { scheduler.skip() }
                    .buttonStyle(SkipButtonStyle())
                if stats.nextSkipResetsStreak {
                    Text("Skip again and your streak resets")
                        .font(.system(size: 13))
                        .opacity(0.7)
                }
            }
        } else {
            let wait = SkipMode.delay - now.timeIntervalSince(scheduler.breakStartedAt ?? now)
            Text("You can skip in \(Int(wait.rounded(.up)))s").font(.system(size: 14)).opacity(0.6)
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

private struct SkipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .padding(.horizontal, 26)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white.opacity(configuration.isPressed ? 0.35 : 0.2)))
            .foregroundColor(.white)
    }
}
