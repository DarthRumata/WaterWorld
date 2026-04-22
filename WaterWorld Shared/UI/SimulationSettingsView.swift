import SwiftUI

struct SimulationSettingsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Simulation Settings")
                .font(.headline)
                .padding(.bottom, 4)

            ParamRowView(
                symbol: "Min energy to dodge",
                value: hud.dodgeEnergyRequired,
                format: "%.0f",
                step: 10,
                minValue: 0,
                labelWidth: 150,
                onSet: hud.onSetDodgeEnergyRequired,
                hint: "Minimum energy an organism needs to attempt a dodge. Below this — instant death."
            )
            ParamRowView(
                symbol: "Dodge cost",
                value: hud.dodgeCost,
                format: "%.0f",
                step: 10,
                minValue: 0,
                labelWidth: 150,
                onSet: hud.onSetDodgeCost,
                hint: "Energy lost on a successful dodge."
            )
        }
        .padding()
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 360)
    }
}
