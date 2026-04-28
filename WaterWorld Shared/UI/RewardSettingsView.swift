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
        }
        .padding()
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 320)
    }
}
