import SwiftUI

struct RewardSettingsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reward Settings")
                .font(.headline)
                .padding(.bottom, 4)

            HStack {
                Text("Death penalty")
                    .frame(width: 120, alignment: .leading)
                Spacer()
                Text(String(format: "%.2f", hud.deathPenalty))
                    .foregroundStyle(.secondary)
                Text("(auto)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .help("Auto-computed: −(N−1)·Rmax / γ^(N−1). Scales with N-step and gamma.")

            Divider()

            Toggle("State energy reward", isOn: Binding(
                get: { hud.isStateRewardEnabled },
                set: { hud.onToggleStateReward($0) }
            ))
            .help("Reward based on current energy level: positive above night-survival threshold, negative below.")

            Toggle("Delta energy reward", isOn: Binding(
                get: { hud.isDeltaRewardEnabled },
                set: { hud.onToggleDeltaReward($0) }
            ))
            .help("Reward for gaining energy, penalty for losing it.")
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .colorScheme(.light)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 320)
    }
}
