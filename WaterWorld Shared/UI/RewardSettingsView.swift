import SwiftUI

struct RewardSettingsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reward Settings")
                .font(.headline)
                .padding(.bottom, 4)

            ParamRowView(
                symbol: "Death penalty",
                value: hud.deathPenalty,
                format: "%.1f",
                step: 0.1,
                minValue: -1.0,
                labelWidth: 120,
                onSet: hud.onSetDeathPenalty,
                hint: "Reward on organism death. Range: -1.0...0."
            )
        }
        .padding()
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 320)
    }
}
