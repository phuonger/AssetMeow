import SwiftUI

struct KioskLoginView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var badgeInput = ""
    @State private var isProcessing = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var pulseAnimation = false
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        ZStack {
            // Full-screen dark background
            AppTheme.backgroundDark.ignoresSafeArea()
            
            // Subtle gradient overlay
            LinearGradient(
                gradient: Gradient(colors: [
                    AppTheme.primaryPurple.opacity(0.05),
                    Color.clear,
                    AppTheme.accentCyan.opacity(0.03)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Exit Station Mode button (top-right)
                HStack {
                    Spacer()
                    Button(action: { appState.exitStationMode() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12))
                            Text("Exit Station Mode")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppTheme.surfaceDark)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.surfaceBorder, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(20)
                }
                
                Spacer()
                
                // Main content - centered
                VStack(spacing: 32) {
                    // App branding
                    VStack(spacing: 12) {
                        Image(systemName: "cat.fill")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundStyle(AppTheme.primaryGradient)
                        
                        Text("AssetMeow")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Station Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.accentCyan)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(AppTheme.accentCyan.opacity(0.1))
                            .cornerRadius(12)
                    }
                    
                    // Badge scan prompt
                    VStack(spacing: 20) {
                        // Animated badge icon
                        ZStack {
                            Circle()
                                .fill(AppTheme.primaryPurple.opacity(0.1))
                                .frame(width: 120, height: 120)
                                .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                                .animation(
                                    .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                                    value: pulseAnimation
                                )
                            
                            Circle()
                                .fill(AppTheme.primaryPurple.opacity(0.2))
                                .frame(width: 90, height: 90)
                            
                            Image(systemName: "wave.3.right")
                                .font(.system(size: 36, weight: .medium))
                                .foregroundColor(AppTheme.primaryPurpleLight)
                        }
                        
                        Text("Scan Your Badge")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Hold your employee badge near the reader to sign in")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Hidden input field that captures badge scan
                    TextField("", text: $badgeInput)
                        .focused($inputFocused)
                        .frame(width: 1, height: 1)
                        .opacity(0.01)
                        .onSubmit {
                            processBadgeScan()
                        }
                    
                    // Error message
                    if showError {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(AppTheme.statusMissing)
                            Text(errorMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(AppTheme.statusMissing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.statusMissing.opacity(0.1))
                        .cornerRadius(8)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Loading indicator
                    if isProcessing {
                        HStack(spacing: 10) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                                .scaleEffect(0.8)
                            Text("Authenticating...")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                // Bottom hint
                VStack(spacing: 8) {
                    Text("Place your RFID badge on the reader")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textMuted)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppTheme.statusAvailable)
                            .frame(width: 6, height: 6)
                        Text("Reader active")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .onAppear {
            inputFocused = true
            pulseAnimation = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Re-focus input when app becomes active
            inputFocused = true
        }
    }
    
    private func processBadgeScan() {
        let scannedBadge = badgeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        badgeInput = ""
        
        guard !scannedBadge.isEmpty else {
            inputFocused = true
            return
        }
        
        isProcessing = true
        showError = false
        
        Task {
            let success = await appState.badgeLogin(badgeId: scannedBadge)
            await MainActor.run {
                isProcessing = false
                if !success {
                    errorMessage = appState.loginError ?? "Badge not recognized"
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showError = true
                    }
                    // Auto-hide error after 4 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation {
                            showError = false
                        }
                    }
                }
                // Re-focus for next scan attempt
                inputFocused = true
            }
        }
    }
}
