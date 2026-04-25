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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ParamRowView(symbol: "γ",  value: hud.gamma,         format: HyperparamSpecs.gamma.format,        step: HyperparamSpecs.gamma.step,        minValue: HyperparamSpecs.gamma.minValue,        maxValue: HyperparamSpecs.gamma.maxValue,        onSet: hud.onSetGamma,
                         hint: "Discount factor — насколько будущие награды важны сейчас.\n0.99 = дальновидный, 0.5 = живёт моментом.")
            ParamRowView(symbol: "τ",  value: hud.tau,           format: HyperparamSpecs.tau.format,          step: HyperparamSpecs.tau.step,          minValue: HyperparamSpecs.tau.minValue,          maxValue: HyperparamSpecs.tau.maxValue,          onSet: hud.onSetTau,
                         hint: "Polyak averaging — скорость обновления target-сети.\n0.005 = плавное скольжение, 0.1 = быстрая синхронизация.")
            ParamRowView(symbol: "α",  value: hud.learningRate,  format: HyperparamSpecs.learningRate.format,  step: HyperparamSpecs.learningRate.step,  minValue: HyperparamSpecs.learningRate.minValue,  maxValue: HyperparamSpecs.learningRate.maxValue,  onSet: hud.onSetLearningRate,
                         hint: "Learning rate — размер шага обновления весов.\nМало = медленно, много = нестабильно.")
            ParamRowView(symbol: "εd", value: hud.epsilonDecay,  format: HyperparamSpecs.epsilonDecay.format,  step: HyperparamSpecs.epsilonDecay.step,  minValue: HyperparamSpecs.epsilonDecay.minValue,  maxValue: HyperparamSpecs.epsilonDecay.maxValue,  onSet: hud.onSetEpsilonDecay,
                         hint: "Epsilon decay — скорость перехода exploration → exploitation.\n0.999 = медленно, 0.99 = быстро.")
            ParamRowView(symbol: "N",  value: Double(hud.nStep), format: HyperparamSpecs.nStep.format,         step: HyperparamSpecs.nStep.step,         minValue: HyperparamSpecs.nStep.minValue,         maxValue: HyperparamSpecs.nStep.maxValue,         onSet: { hud.onSetNStep(max(1, Int($0))) },
                         hint: "N-step DQN горизонт. N=1 = стандартный DQN, N=10 = агент видит 10 шагов вперёд за одно обновление.")
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
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(white: 0.15))
    }
}
