import SwiftUI
import AVKit

struct EasterEggVideoView: View {
    @Binding var isPresented: Bool
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        player?.pause()
                        isPresented = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.8))
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                Spacer()
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
            looper = nil
        }
    }
    
    private func setupPlayer() {
        guard let url = Bundle.main.url(forResource: "ken_dance_video", withExtension: "mp4") else {
            return
        }
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer(playerItem: item)
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        
        self.player = queuePlayer
        self.looper = playerLooper
        queuePlayer.play()
    }
}
