import SwiftUI

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var animateGlow = false
    
    var body: some View {
        ZStack {
            // Background
            AppTheme.backgroundDark
                .ignoresSafeArea()
            
            // Subtle gradient overlay
            RadialGradient(
                colors: [AppTheme.primaryPurple.opacity(0.15), Color.clear],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and branding
                VStack(spacing: 16) {
                    // App icon
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryPurple.opacity(0.2))
                            .frame(width: 100, height: 100)
                            .blur(radius: animateGlow ? 20 : 10)
                        
                        Image(systemName: "cat.fill")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(AppTheme.primaryGradient)
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                            animateGlow = true
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text("AssetMeow")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Text("Asset Tracker")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .padding(.bottom, 40)
                
                // Login card
                VStack(spacing: 20) {
                    Text("Sign In")
                        .font(AppTheme.headingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    // Username field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "person.fill")
                                .foregroundColor(AppTheme.textMuted)
                                .frame(width: 20)
                            
                            TextField("", text: $username)
                                .textFieldStyle(.plain)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        .padding(12)
                        .background(AppTheme.backgroundDark)
                        .cornerRadius(AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                        )
                    }
                    
                    // Password field
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        HStack(spacing: 10) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(AppTheme.textMuted)
                                .frame(width: 20)
                            
                            SecureField("", text: $password)
                                .textFieldStyle(.plain)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textPrimary)
                                .onSubmit { login() }
                        }
                        .padding(12)
                        .background(AppTheme.backgroundDark)
                        .cornerRadius(AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                        )
                    }
                    
                    // Error message
                    if showError {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                            Text(errorMessage)
                                .font(AppTheme.captionFont)
                        }
                        .foregroundColor(AppTheme.statusMissing)
                        .padding(.vertical, 4)
                    }
                    
                    // Login button
                    Button(action: login) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Signing In..." : "Sign In")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.buttonGradient)
                        .foregroundColor(.white)
                        .cornerRadius(AppTheme.buttonCornerRadius)
                        .shadow(color: AppTheme.primaryPurple.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading || username.isEmpty || password.isEmpty)
                    .opacity((username.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                }
                .padding(32)
                .background(AppTheme.backgroundCard)
                .cornerRadius(AppTheme.cardCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                        .stroke(AppTheme.surfaceBorder.opacity(0.5), lineWidth: 1)
                )
                .frame(maxWidth: 360)
                
                Spacer()
                
                // Footer
                Text("v2.0")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.bottom, 20)
            }
            .padding()
        }
        .frame(minWidth: 500, minHeight: 500)
    }
    
    private func login() {
        guard !username.isEmpty, !password.isEmpty else { return }
        
        isLoading = true
        showError = false
        
        Task {
            let success = await appState.login(username: username, password: password)
            await MainActor.run {
                isLoading = false
                if !success {
                    errorMessage = appState.loginError ?? "Login failed"
                    showError = true
                }
            }
        }
    }
}
