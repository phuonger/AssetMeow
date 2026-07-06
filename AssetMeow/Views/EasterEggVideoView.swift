import SwiftUI
import AVKit
import AppKit

// MARK: - Easter Egg Window Controller
// Opens the easter egg video in a native NSWindow with AVPlayerView (most stable on macOS)
class EasterEggWindowController {
    static let shared = EasterEggWindowController()
    private var window: NSWindow?
    private var player: AVPlayer?
    private var loopObserver: NSObjectProtocol?
    private var closeObserver: NSObjectProtocol?

    func show() {
        // If window already exists, just bring it front
        if let existingWindow = window, existingWindow.isVisible {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }
        
        // Clean up any previous instance
        cleanup()
        
        // Find the video file
        guard let videoURL = Bundle.main.url(forResource: "ken_dance_video", withExtension: "mp4") else {
            print("[EasterEgg] Video file not found in bundle")
            // Fallback: show a fun alert instead of crashing
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "🐱 Meow!"
                alert.informativeText = "The cat video couldn't be found. But you found the easter egg!"
                alert.alertStyle = .informational
                alert.runModal()
            }
            return
        }
        
        // Create AVPlayer
        let playerItem = AVPlayerItem(url: videoURL)
        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.volume = 1.0
        self.player = avPlayer
        
        // Set up looping
        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak avPlayer] _ in
            avPlayer?.seek(to: .zero)
            avPlayer?.play()
        }
        self.loopObserver = obs
        
        // Create the AVPlayerView (AppKit native - more stable than SwiftUI VideoPlayer)
        let playerView = AVPlayerView()
        playerView.player = avPlayer
        playerView.controlsStyle = .floating
        playerView.frame = NSRect(x: 0, y: 0, width: 480, height: 360)
        
        // Create window
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        newWindow.contentView = playerView
        newWindow.title = "🐱 Meow!"
        newWindow.backgroundColor = .black
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.level = .floating
        
        // Watch for window close to clean up (block-based, no @objc needed)
        let closeObs = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: newWindow,
            queue: .main
        ) { [weak self] _ in
            self?.cleanup()
        }
        self.closeObserver = closeObs
        
        newWindow.makeKeyAndOrderFront(nil)
        self.window = newWindow
        
        // Start playing
        avPlayer.play()
    }

    private func cleanup() {
        player?.pause()
        player = nil
        
        if let obs = loopObserver {
            NotificationCenter.default.removeObserver(obs)
            loopObserver = nil
        }
        
        if let obs = closeObserver {
            NotificationCenter.default.removeObserver(obs)
            closeObserver = nil
        }
        
        window = nil
    }
}
