import SwiftUI

// Shared param row used by LearningParamsView and RewardSettingsView.
struct ParamRowView: View {
    let symbol: String
    let value: Double
    let format: String
    let step: Double
    let minValue: Double
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
        labelWidth: CGFloat = 20,
        onSet: @escaping (Double) -> Void,
        hint: String
    ) {
        self.symbol = symbol
        self.value = value
        self.format = format
        self.step = step
        self.minValue = minValue
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
            Button("+") { onSet(value + step) }.buttonStyle(HUDButtonStyle())
        }
        .help(hint)
    }

    private func decrement() {
        var delta = step
        while value - delta < minValue && delta > step / 1024 {
            delta /= 2
        }
        if value - delta >= minValue {
            onSet(value - delta)
        }
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
            ParamRowView(symbol: "γ",  value: hud.gamma,        format: "%.3f",  step: 0.01,  minValue: 0.01,   onSet: hud.onSetGamma,
                         hint: "Discount factor — насколько будущие награды важны сейчас.\n0.99 = дальновидный, 0.5 = живёт моментом.")
            ParamRowView(symbol: "τ",  value: hud.tau,          format: "%.4f",  step: 0.001, minValue: 0.001,  onSet: hud.onSetTau,
                         hint: "Polyak averaging — скорость обновления target-сети.\n0.005 = плавное скольжение, 0.1 = быстрая синхронизация.")
            ParamRowView(symbol: "α",  value: hud.learningRate, format: "%.4f",  step: 0.001, minValue: 0.0001, onSet: hud.onSetLearningRate,
                         hint: "Learning rate — размер шага обновления весов.\nМало = медленно, много = нестабильно.")
            ParamRowView(symbol: "εd", value: hud.epsilonDecay, format: "%.4f",  step: 0.001, minValue: 0.99,   onSet: hud.onSetEpsilonDecay,
                         hint: "Epsilon decay — скорость перехода exploration → exploitation.\n0.999 = медленно, 0.99 = быстро.")
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
