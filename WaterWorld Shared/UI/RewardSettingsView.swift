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
                format: HyperparamSpecs.deathPenalty.format,
                step: HyperparamSpecs.deathPenalty.step,
                minValue: HyperparamSpecs.deathPenalty.minValue,
                maxValue: HyperparamSpecs.deathPenalty.maxValue,
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
