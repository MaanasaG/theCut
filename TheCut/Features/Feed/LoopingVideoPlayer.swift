import AVFoundation
import AVKit
import SwiftUI

/// Full-bleed muted looping video. Sized explicitly so the layer is never zero.
struct LoopingVideoPlayer: UIViewRepresentable {
    var resourceName: String
    var isActive: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        context.coordinator.view = view
        view.configure(resourceName: resourceName)
        view.setActive(isActive)
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        if uiView.resourceName != resourceName {
            uiView.configure(resourceName: resourceName)
        }
        uiView.setActive(isActive)
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        uiView.teardown()
    }

    final class Coordinator {
        weak var view: PlayerContainerView?
    }
}

final class PlayerContainerView: UIView {
    private(set) var resourceName: String = ""
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var statusObserver: NSKeyValueObservation?
    private let playerLayer = AVPlayerLayer()
    private var wantsPlaying = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .black
        clipsToBounds = true
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }

    func configure(resourceName: String) {
        teardown()
        self.resourceName = resourceName

        let url =
            Bundle.main.url(forResource: resourceName, withExtension: "mp4")
            ?? Bundle.main.url(forResource: resourceName, withExtension: "mp4", subdirectory: "Videos")
            ?? Bundle.main.urls(forResourcesWithExtension: "mp4", subdirectory: nil)?
                .first(where: { $0.lastPathComponent.hasPrefix(resourceName) })

        guard let url else {
            print("TheCut: missing video \(resourceName).mp4")
            return
        }

        let item = AVPlayerItem(url: url)
        let queue = AVQueuePlayer(playerItem: item)
        queue.isMuted = true
        queue.automaticallyWaitsToMinimizeStalling = false
        looper = AVPlayerLooper(player: queue, templateItem: item)
        player = queue
        playerLayer.player = queue

        statusObserver = item.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if item.status == .readyToPlay, self.wantsPlaying {
                    queue.play()
                } else if item.status == .failed {
                    print("TheCut: video failed \(resourceName): \(String(describing: item.error))")
                }
            }
        }
    }

    func setActive(_ active: Bool) {
        wantsPlaying = active
        guard let player else { return }
        if active {
            player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
            player.play()
        } else {
            player.pause()
        }
    }

    func teardown() {
        statusObserver = nil
        player?.pause()
        looper = nil
        player = nil
        playerLayer.player = nil
    }
}

/// Auto-narrate the lesson when a reel becomes active (quiet, can be interrupted).
@MainActor
final class ReelNarrator: ObservableObject {
    static let shared = ReelNarrator()
    private let synth = AVSpeechSynthesizer()
    private var lastCardID: String?

    func speakIfNeeded(cardID: String, title: String, body: String) {
        guard lastCardID != cardID else { return }
        lastCardID = cardID
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        let u = AVSpeechUtterance(string: "\(title). \(body)")
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
        u.volume = 0.9
        synth.speak(u)
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
    }

    func resetCardTracking() {
        lastCardID = nil
    }
}
