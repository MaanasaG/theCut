import Foundation

/// Lightweight on-device cleanup using Pomvox-style filler/false-start rules.
/// Falls back gracefully when a full MLX cleanup model is unavailable on iPhone.
public enum LocalCleanup {
    private static let fillers: Set<String> = [
        "um", "uh", "erm", "hmm", "like", "you know", "sort of", "kind of",
        "basically", "actually", "right", "okay so", "so yeah"
    ]

    public static func clean(_ raw: String) -> (cleaned: String, fillerCount: Int) {
        var fillerCount = 0
        var tokens = raw
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }

        // Drop leading false starts: repeated openings before a comma/period.
        if tokens.count > 3 {
            let lower = tokens.map { $0.lowercased().trimmingCharacters(in: .punctuationCharacters) }
            if lower[0] == lower[1] {
                tokens.removeFirst()
                fillerCount += 1
            }
        }

        var kept: [String] = []
        var i = 0
        while i < tokens.count {
            let t = tokens[i]
            let bare = t.lowercased().trimmingCharacters(in: .punctuationCharacters)
            // Two-word fillers
            if i + 1 < tokens.count {
                let two = "\(bare) \(tokens[i + 1].lowercased().trimmingCharacters(in: .punctuationCharacters))"
                if fillers.contains(two) {
                    fillerCount += 1
                    i += 2
                    continue
                }
            }
            if fillers.contains(bare) {
                fillerCount += 1
                i += 1
                continue
            }
            kept.append(t)
            i += 1
        }

        var text = kept.joined(separator: " ")
        // Capitalize sentence starts
        if let first = text.first {
            text = String(first).uppercased() + text.dropFirst()
        }
        return (text, fillerCount)
    }

    public static func paceStats(timestamps: [WordTimestamp], duration: Double) -> (wpm: Double, pauses: Int) {
        guard duration > 0, !timestamps.isEmpty else { return (0, 0) }
        let wpm = Double(timestamps.count) / (duration / 60.0)
        var pauses = 0
        for idx in 1..<timestamps.count {
            if timestamps[idx].start - timestamps[idx - 1].end > 0.6 {
                pauses += 1
            }
        }
        return (wpm, pauses)
    }
}
