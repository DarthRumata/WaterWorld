import SwiftUI

struct LearningParamsView: View {
    let hud: GameHUDModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            paramRow(symbol: "γ",  value: hud.gamma,        format: "%.3f",  step: 0.01,  onSet: hud.onSetGamma,
                     hint: "Discount factor — насколько будущие награды важны сейчас.\n0.99 = дальновидный, 0.5 = живёт моментом.")
            paramRow(symbol: "τ",  value: hud.tau,          format: "%.4f",  step: 0.001, onSet: hud.onSetTau,
                     hint: "Polyak averaging — скорость обновления target-сети.\n0.005 = плавное скольжение, 0.1 = быстрая синхронизация.")
            paramRow(symbol: "α",  value: hud.learningRate, format: "%.4f",  step: 0.001, onSet: hud.onSetLearningRate,
                     hint: "Learning rate — размер шага обновления весов.\nМало = медленно, много = нестабильно.")
            paramRow(symbol: "εd", value: hud.epsilonDecay, format: "%.4f",  step: 0.001, onSet: hud.onSetEpsilonDecay,
                     hint: "Epsilon decay — скорость перехода exploration → exploitation.\n0.999 = медленно, 0.99 = быстро.")
            paramRow(symbol: "Δw", value: hud.deltaWeight,  format: "%.2f",  step: 0.05,  onSet: hud.onSetDeltaWeight,
                     hint: "Reward blend — баланс между сытостью и ощущением.\n0 = только уровень энергии, 1 = только изменение энергии.")
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Color(white: 0.15))
    }

    private func paramRow(
        symbol: String,
        value: Double,
        format: String,
        step: Double,
        onSet: @escaping (Double) -> Void,
        hint: String
    ) -> some View {
        HStack(spacing: 4) {
            Text(symbol)
                .frame(width: 20, alignment: .leading)
                .foregroundStyle(Color(white: 0.4))
            Button("-") { onSet(value - step) }.buttonStyle(HUDButtonStyle())
            Text(String(format: format, value))
                .lineLimit(1)
                .fixedSize()
            Button("+") { onSet(value + step) }.buttonStyle(HUDButtonStyle())
        }
        .help(hint)
    }
}
