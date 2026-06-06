import SwiftUI

struct AdamParamsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Adam Optimizer")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { hud.isAdamEnabled },
                    set: { hud.onToggleAdam($0) }
                ))
                .labelsHidden()
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 10) {
                ParamRowView(
                    symbol: "β1",
                    value: hud.adamBeta1,
                    format: HyperparamSpecs.adamBeta1.format,
                    step: HyperparamSpecs.adamBeta1.step,
                    minValue: HyperparamSpecs.adamBeta1.minValue,
                    maxValue: HyperparamSpecs.adamBeta1.maxValue,
                    labelWidth: 24,
                    onSet: hud.onSetAdamBeta1,
                    hint: "First moment decay (momentum). 0.9 = standard."
                )
                ParamRowView(
                    symbol: "β2",
                    value: hud.adamBeta2,
                    format: HyperparamSpecs.adamBeta2.format,
                    step: HyperparamSpecs.adamBeta2.step,
                    minValue: HyperparamSpecs.adamBeta2.minValue,
                    maxValue: HyperparamSpecs.adamBeta2.maxValue,
                    labelWidth: 24,
                    onSet: hud.onSetAdamBeta2,
                    hint: "Second moment decay. 0.999 = stable, 0.99 = faster adaptation (better for RL)."
                )
                ParamRowView(
                    symbol: "ε",
                    value: hud.adamEps,
                    format: HyperparamSpecs.adamEps.format,
                    step: HyperparamSpecs.adamEps.step,
                    minValue: HyperparamSpecs.adamEps.minValue,
                    maxValue: HyperparamSpecs.adamEps.maxValue,
                    labelWidth: 24,
                    onSet: hud.onSetAdamEps,
                    hint: "Numerical stability constant. Usually 1e-8."
                )
            }
            .opacity(hud.isAdamEnabled ? 1 : 0.35)
            .disabled(!hud.isAdamEnabled)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .colorScheme(.light)
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(.primary)
        .frame(width: 300)
    }
}
