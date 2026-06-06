//
//  NetworkArchitectureView.swift
//  WaterWorld Shared
//

import SwiftUI

struct NetworkArchitectureView: View {
    let hud: GameHUDModel

    @State private var layers: [Int]
    @State private var showConfirm = false

    private let inputSize = 5
    private let outputSize = 3
    private let minUnits = 2
    private let maxUnits = 256
    private let unitsStep = 2

    init(hud: GameHUDModel) {
        self.hud = hud
        _layers = State(initialValue: hud.networkArchitecture)
    }

    private var isDirty: Bool { layers != hud.networkArchitecture }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Architecture")
                .font(.headline)

            Text("Input: \(inputSize) · Hidden: \(layers.count) layers · Output: \(outputSize)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()

            // Architecture diagram
            HStack(spacing: 6) {
                layerBox(label: "In", units: inputSize, editable: false)
                ForEach(layers.indices, id: \.self) { i in
                    Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.caption)
                    editableLayer(index: i)
                }
                Image(systemName: "arrow.right").foregroundStyle(.secondary).font(.caption)
                layerBox(label: "Out", units: outputSize, editable: false)
            }
            .padding(.vertical, 4)

            // Add / Remove layer buttons
            HStack(spacing: 8) {
                Button {
                    layers.append(16)
                } label: {
                    Label("Add layer", systemImage: "plus.circle")
                }
                .disabled(layers.count >= 6)

                Button {
                    if layers.count > 1 { layers.removeLast() }
                } label: {
                    Label("Remove last", systemImage: "minus.circle")
                }
                .disabled(layers.count <= 1)
            }
            .font(.caption)

            Divider()

            if isDirty {
                Text("⚠ Applying resets all training data and replay buffer.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Reset") { layers = hud.networkArchitecture }
                    .disabled(!isDirty)
                Spacer()
                Button("Apply") { showConfirm = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(!isDirty)
            }
        }
        .padding()
        .frame(width: 480)
        .background(Color(NSColor.controlBackgroundColor))
        .colorScheme(.light)
        .font(.system(size: 12, design: .monospaced))
        .confirmationDialog(
            "Apply new architecture?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Apply & Reset training", role: .destructive) {
                hud.onApplyArchitecture(layers)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All replay buffers, training progress, and epsilon will be reset. The network will be reinitialized with random weights.")
        }
    }

    private func layerBox(label: String, units: Int, editable: Bool) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text("\(units)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.secondary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func editableLayer(index i: Int) -> some View {
        VStack(spacing: 2) {
            Text("H\(i + 1)").font(.caption2).foregroundStyle(.secondary)
            VStack(spacing: 1) {
                Button { layers[i] = min(maxUnits, layers[i] + unitsStep) } label: {
                    Image(systemName: "chevron.up").font(.system(size: 8))
                }
                Text("\(layers[i])")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .frame(minWidth: 32)
                Button { layers[i] = max(minUnits, layers[i] - unitsStep) } label: {
                    Image(systemName: "chevron.down").font(.system(size: 8))
                }
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.accentColor.opacity(0.4), lineWidth: 1))
        }
    }
}
