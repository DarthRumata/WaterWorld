import SwiftUI

struct LearningWarningBanner: View {
    private var warnings: [LearningWarning] { QLearningStore.shared.learningWarnings }

    var body: some View {
        if !warnings.isEmpty {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                ForEach(warnings, id: \.description) { warning in
                    Text(warning.description)
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.orange)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(.black.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .fixedSize()
            .transition(.move(edge: .top).combined(with: .opacity))
            .animation(.easeInOut(duration: 0.3), value: warnings.map(\.description))
        }
    }
}
