import SwiftUI

// Shared param row used by LearningParamsView and RewardSettingsView.
struct ParamRowView: View {
    let symbol: String
    let value: Double
    let format: String
    let step: Double
    let minValue: Double
    let maxValue: Double
    let labelWidth: CGFloat
    let onSet: (Double) -> Void
    let hint: String

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    init(
        symbol: String,
        value: Double,
        format: String,
        step: Double,
        minValue: Double = -.infinity,
        maxValue: Double = .infinity,
        labelWidth: CGFloat = 20,
        onSet: @escaping (Double) -> Void,
        hint: String
    ) {
        self.symbol = symbol
        self.value = value
        self.format = format
        self.step = step
        self.minValue = minValue
        self.maxValue = maxValue
        self.labelWidth = labelWidth
        self.onSet = onSet
        self.hint = hint
        self._text = State(initialValue: String(format: format, value))
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(symbol)
                .frame(width: labelWidth, alignment: .leading)
                .foregroundStyle(.primary)
            Button("-") { decrement() }.buttonStyle(HUDButtonStyle())
            TextField("", text: $text)
                .focused($isFocused)
                .multilineTextAlignment(.center)
                .frame(width: 52)
                .textFieldStyle(.plain)
                .onSubmit { commit() }
                .onChange(of: isFocused) { _, focused in if !focused { commit() } }
                .onChange(of: value) { _, newValue in
                    if !isFocused {
                        text = String(format: format, newValue)
                    }
                }
            Button("+") { increment() }.buttonStyle(HUDButtonStyle())
        }
        .help(hint)
    }

    private func increment() {
        let eps = step * 1e-9
        let next = ceil((value + eps) / step) * step
        let capped = min(next, maxValue)
        if capped > value + eps { onSet(capped) }
    }

    private func decrement() {
        let eps = step * 1e-9
        let prev = floor((value - eps) / step) * step
        let floored = max(prev, minValue)
        if floored < value - eps { onSet(floored) }
    }

    private func commit() {
        if let newValue = Double(text) {
            onSet(newValue)
        }
        text = String(format: format, value)
    }
}

struct LearningParamsView: View {
    let hud: GameHUDModel
    @State private var showRewardSettings = false
    @State private var showSimulationSettings = false
    @State private var showAdamSettings = false
    @State private var showArchitectureEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ParamRowView(symbol: "ε",  value: hud.epsilon,      format: HyperparamSpecs.epsilon.format,       step: HyperparamSpecs.epsilon.step,       minValue: HyperparamSpecs.epsilon.minValue,       maxValue: HyperparamSpecs.epsilon.maxValue,       onSet: hud.onSetEpsilon,
                         hint: "Epsilon — probability of a random action (exploration).\n\(String(format: HyperparamSpecs.epsilon.format, HyperparamSpecs.epsilon.minValue)) = almost pure exploitation, 1.0 = fully random.")
            ParamRowView(symbol: "γ",  value: hud.gamma,         format: HyperparamSpecs.gamma.format,        step: HyperparamSpecs.gamma.step,        minValue: HyperparamSpecs.gamma.minValue,        maxValue: HyperparamSpecs.gamma.maxValue,        onSet: hud.onSetGamma,
                         hint: "Discount factor — how much future rewards matter now.\n0.99 = far-sighted, 0.5 = lives in the moment.")
            ParamRowView(symbol: "τ",  value: hud.tau,           format: HyperparamSpecs.tau.format,          step: HyperparamSpecs.tau.step,          minValue: HyperparamSpecs.tau.minValue,          maxValue: HyperparamSpecs.tau.maxValue,          onSet: hud.onSetTau,
                         hint: "Polyak averaging — target network update speed.\n0.005 = smooth drift, 0.1 = fast sync.")
            ParamRowView(symbol: "α",  value: hud.learningRate,  format: HyperparamSpecs.learningRate.format,  step: HyperparamSpecs.learningRate.step,  minValue: HyperparamSpecs.learningRate.minValue,  maxValue: HyperparamSpecs.learningRate.maxValue,  onSet: hud.onSetLearningRate,
                         hint: "Learning rate — weight update step size.\nToo small = slow, too large = unstable.")
            ParamRowView(symbol: "εd", value: hud.epsilonDecay,  format: HyperparamSpecs.epsilonDecay.format,  step: HyperparamSpecs.epsilonDecay.step,  minValue: HyperparamSpecs.epsilonDecay.minValue,  maxValue: HyperparamSpecs.epsilonDecay.maxValue,  onSet: hud.onSetEpsilonDecay,
                         hint: "Epsilon decay — rate of transition exploration → exploitation.\n0.999 = slow, 0.99 = fast.")
            ParamRowView(symbol: "N",  value: Double(hud.nStep), format: HyperparamSpecs.nStep.format,         step: HyperparamSpecs.nStep.step,         minValue: HyperparamSpecs.nStep.minValue,         maxValue: HyperparamSpecs.nStep.maxValue,         onSet: { hud.onSetNStep(max(1, Int($0))) },
                         hint: "N-step DQN horizon. N=1 = standard DQN, N=10 = agent sees 10 steps ahead per update.")
            HStack(spacing: 8) {
                Button("Simulation…") { showSimulationSettings = true }
                    .buttonStyle(HUDButtonStyle())
                    .popover(isPresented: $showSimulationSettings) {
                        SimulationSettingsView(hud: hud)
                    }
                Button("Reward…") { showRewardSettings = true }
                    .buttonStyle(HUDButtonStyle())
                    .popover(isPresented: $showRewardSettings) {
                        RewardSettingsView(hud: hud)
                    }
                Button("Adam…") { showAdamSettings = true }
                    .buttonStyle(HUDButtonStyle())
                    .popover(isPresented: $showAdamSettings) {
                        AdamParamsView(hud: hud)
                    }
                Button("Network…") { showArchitectureEditor = true }
                    .buttonStyle(HUDButtonStyle())
                    .popover(isPresented: $showArchitectureEditor) {
                        NetworkArchitectureView(hud: hud)
                    }
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(white: 0.15))
    }
}
