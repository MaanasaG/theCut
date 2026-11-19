import Foundation
import Speech

enum SpeechFallback {
    static func requestAuth() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { _ in
                cont.resume()
            }
        }
    }

    static func transcribe(url: URL) async -> String {
        await withCheckedContinuation { (cont: CheckedContinuation<String, Never>) in
            var resumed = false
            let finish: (String) -> Void = { text in
                guard !resumed else { return }
                resumed = true
                cont.resume(returning: text)
            }

            guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
                  recognizer.isAvailable else {
                finish("")
                return
            }

            SFSpeechRecognizer.requestAuthorization { status in
                guard status == .authorized else {
                    finish("")
                    return
                }
                let request = SFSpeechURLRecognitionRequest(url: url)
                request.shouldReportPartialResults = false
                recognizer.recognitionTask(with: request) { result, error in
                    if let error {
                        finish("")
                        _ = error
                        return
                    }
                    if let result, result.isFinal {
                        finish(result.bestTranscription.formattedString)
                    }
                }
            }
        }
    }
}
