import Foundation

struct RubricScore: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var score: Int
    var note: String
}

struct GradeResult: Codable, Hashable {
    var rubricScores: [RubricScore]
    var average: Double
    var modelOutline: String
    var coaching: String
    var oneThingToFix: String
    var hireSignal: String?
}

struct LiveTurn: Codable, Hashable {
    var role: String
    var text: String
}

enum ClaudeClientError: Error, LocalizedError {
    case missingAPIKey
    case spendCapExceeded
    case badResponse(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Add your Anthropic API key in Settings."
        case .spendCapExceeded: return "Monthly Claude spend cap reached. Raise it in Settings or wait for next month."
        case .badResponse(let s): return s
        case .decoding: return "Could not parse Claude response."
        }
    }
}

actor ClaudeClient {
    static let shared = ClaudeClient()

    /// Rough cost estimate per 1M tokens (input/output blended) for Opus-class — used only for soft cap metering.
    private let usdPerMillionTokens = 25.0
    private let model = "claude-opus-4-5"

    func gradeSpokenAnswer(
        prompt: String,
        raw: String,
        cleaned: String,
        fillerCount: Int,
        wpm: Double,
        rubric: [RubricItem],
        kind: String,
        progress: UserProgress
    ) async throws -> GradeResult {
        try guardSpend(progress)

        let rubricList = rubric.map { "- \($0.id): \($0.label) — \($0.description)" }.joined(separator: "\n")
        let system = """
        You are an expert Director of Engineering interview coach for The Cut.
        Grade the candidate's spoken answer. Use the RAW transcript for delivery coaching (fillers, ramble, pace).
        Use the CLEANED transcript for content substance.
        Return ONLY valid JSON with keys:
        rubricScores (array of {id, label, score 1-5, note}),
        average (number),
        modelOutline (string),
        coaching (string, quote their raw words when pointing issues),
        oneThingToFix (string),
        hireSignal (optional string: hire|lean_hire|no_hire for live rounds only).
        """
        let user = """
        Kind: \(kind)
        Question: \(prompt)
        Rubric:
        \(rubricList)
        Delivery stats: fillers=\(fillerCount), wpm=\(Int(wpm))
        RAW transcript:
        \(raw)
        CLEANED transcript:
        \(cleaned)
        """

        let text = try await messages(system: system, user: user, maxTokens: 1800)
        let result: GradeResult = try decodeJSON(text)
        charge(estimatedTokens: estimateTokens(system + user + text), progress: progress)
        return result
    }

    func liveInterviewerReply(
        roundName: String,
        companyStyle: String,
        minutesRemaining: Int,
        history: [LiveTurn],
        progress: UserProgress
    ) async throws -> String {
        try guardSpend(progress)
        let system = """
        You are a senior interviewer running a \(roundName) for a Director of Engineering candidate.
        Company style: \(companyStyle).
        Minutes remaining: \(minutesRemaining).
        Ask one question or follow-up at a time. Probe weak spots, ask for numbers, push back.
        Near the end (under 3 minutes), change a requirement once.
        When time is up, say ROUND_COMPLETE and stop interviewing.
        Keep responses under 80 words unless giving the final wrap.
        """
        let transcript = history.map { "\($0.role): \($0.text)" }.joined(separator: "\n")
        let user = "Conversation so far:\n\(transcript)\n\nRespond as interviewer."
        let text = try await messages(system: system, user: user, maxTokens: 400)
        charge(estimatedTokens: estimateTokens(system + user + text), progress: progress)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func guardSpend(_ progress: UserProgress) throws {
        progress.rollDayIfNeeded()
        if progress.monthlySpendUSD >= progress.monthlySpendCapUSD {
            throw ClaudeClientError.spendCapExceeded
        }
    }

    private func charge(estimatedTokens: Int, progress: UserProgress) {
        let usd = Double(estimatedTokens) / 1_000_000.0 * usdPerMillionTokens
        progress.monthlySpendUSD += max(usd, 0.01)
    }

    private func estimateTokens(_ s: String) -> Int {
        max(s.count / 4, 1)
    }

    private func messages(system: String, user: String, maxTokens: Int) async throws -> String {
        guard let key = KeychainStore.anthropicAPIKey, !key.isEmpty else {
            throw ClaudeClientError.missingAPIKey
        }
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeClientError.badResponse("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ClaudeClientError.badResponse(msg)
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = json["content"] as? [[String: Any]]
        else {
            throw ClaudeClientError.decoding
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        return text
    }

    private func decodeJSON<T: Decodable>(_ text: String) throws -> T {
        let trimmed = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { throw ClaudeClientError.decoding }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
