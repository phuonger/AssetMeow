import SwiftUI
import AVKit

struct EasterEggVideoView: View {
    @Binding var isPresented: Bool
    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: 0) {
            // Title bar with close button
            HStack {
                Text("🐱 Meow!")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: {
                    player?.pause()
                    isPresented = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
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
                        Text("Video not found")
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
        .background(Color.black)
        .cornerRadius(12)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "ken_dance_video", withExtension: "mp4") else {
            return
        }
        let avPlayer = AVPlayer(url: url)
        self.player = avPlayer

        // Loop the video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: avPlayer.currentItem,
            queue: .main
        ) { _ in
            avPlayer.seek(to: .zero)
            avPlayer.play()
        }

        avPlayer.play()
    }
}
