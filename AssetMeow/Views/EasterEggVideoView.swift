import SwiftUI
import AVKit
import AppKit

struct EasterEggVideoView: View {
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?
    @State private var observer: NSObjectProtocol?

    var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("🐱 Meow!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black)

            // Video player
            if let player = player {
                VideoPlayer(player: player)
                    .frame(width: 480, height: 360)
            } else {
                Color.black
                    .frame(width: 480, height: 360)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "video.slash")
                                .font(.system(size: 32))
                                .foregroundColor(.white.opacity(0.3))
                            Text("Video not found in bundle")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.system(size: 12))
                        }
                    )
            }
        }
        .frame(width: 480, height: 400)
        .background(Color.black)
        .cornerRadius(12)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }

    private func dismiss() {
        cleanup()
        isPresented = false
    }

    private func cleanup() {
        player?.pause()
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
            observer = nil
        }
        player = nil
    }

    private func setupPlayer() {
        // Try to find the video in the bundle
        guard let url = Bundle.main.url(forResource: "ken_dance_video", withExtension: "mp4") else {
            print("[EasterEgg] Video file 'ken_dance_video.mp4' not found in bundle")
            return
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.volume = 1.0

        // Loop the video using notification
        let obs = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }
        self.observer = obs
        self.player = avPlayer

        // Small delay to let the view settle before playing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            avPlayer.play()
        }
    }
}

// MARK: - Easter Egg Window Helper
// Opens the easter egg in a separate NSWindow to avoid .sheet issues on macOS
class EasterEggWindowController {
    static let shared = EasterEggWindowController()
    private var window: NSWindow?

    func show() {
        // If window already exists, just show it
        if let existingWindow = window {
            existingWindow.makeKeyAndOrderFront(nil)
            return
        }

        let binding = Binding<Bool>(
            get: { true },
            set: { [weak self] newValue in
                if !newValue {
                    self?.close()
                }
            }
        )

        let contentView = EasterEggVideoView(isPresented: binding)
            .frame(width: 480, height: 400)

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 480, height: 400)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        newWindow.contentView = hostingView
        newWindow.title = "AssetMeow Easter Egg"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.backgroundColor = .black
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.level = .floating

        self.window = newWindow
    }

    func close() {
        window?.close()
        window = nil
    }
}
