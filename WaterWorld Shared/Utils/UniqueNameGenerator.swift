//
//  UniqueNameGenerator.swift
//  WaterWorld macOS
//
//  Created by Stas Kirichok on 12/12/24.
//

class UniqueNameGenerator {
    private var namePool: [String] = []

    init(syllables: [String]) {
        // Precompute all possible names (2–4 syllables)
        for syllableCount in 2 ... 4 {
            generateCombinations(from: syllables, length: syllableCount)
        }
        // Shuffle the pool to ensure randomness
        namePool.shuffle()
    }

    private func generateCombinations(from syllables: [String], length: Int) {
        func backtrack(current: [String], remaining: Int) {
            if remaining == 0 {
                namePool.append(current.joined())
                return
            }
            for syllable in syllables {
                // Disallow consecutive duplicate syllables
                if current.last == syllable {
                    continue
                }
                backtrack(current: current + [syllable], remaining: remaining - 1)
            }
        }
        backtrack(current: [], remaining: length)
    }

    func generateName() -> String? {
        if let name = namePool.popLast() {
            return name.capitalizingFirstLetter()
        }
        
        return nil
    }
}

private extension String {
    func capitalizingFirstLetter() -> String {
        return prefix(1).uppercased() + self.lowercased().dropFirst()
    }
}
