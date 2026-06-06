import SwiftUI

struct SimulationSettingsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Simulation Settings")
                .font(.headline)
                .padding(.bottom, 4)

            ParamRowView(
                symbol: "Dodge cost (min)",
                value: hud.dodgeCost,
                format: "%.0f",
                step: 10,
                minValue: 0,
                labelWidth: 150,
                onSet: hud.onSetDodgeCost,
                hint: "Min energy lost on a successful dodge (at depth 0.3). Max is \(Int(GlobalConstants.predationDodgeCostMax)) at surface."
            )
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .colorScheme(.light)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 360)
    }
}
