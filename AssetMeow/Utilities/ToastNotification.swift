import SwiftUI

// ============================================================
// Toast Notification System
// Provides app-wide feedback for database writes and operations
// ============================================================

// MARK: - Toast Model
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let detail: String?
    let timestamp: Date
    
    init(type: ToastType, title: String, detail: String? = nil) {
        self.type = type
        self.title = title
        self.detail = detail
        self.timestamp = Date()
    }
    
    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return AppTheme.statusAvailable
        case .error: return AppTheme.statusMissing
        case .warning: return AppTheme.statusCheckedOut
        case .info: return AppTheme.accentCyan
        }
    }
}

// MARK: - Toast Manager (shared across the app)
@MainActor
class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastMessage?
    @Published var toastHistory: [ToastMessage] = []
    
    private var dismissTask: Task<Void, Never>?
    
    func show(_ type: ToastType, title: String, detail: String? = nil, duration: Double = 3.0) {
        let toast = ToastMessage(type: type, title: title, detail: detail)
        
        // Cancel any pending dismiss
        dismissTask?.cancel()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentToast = toast
        }
        
        // Keep history (last 50)
        toastHistory.insert(toast, at: 0)
        if toastHistory.count > 50 {
            toastHistory = Array(toastHistory.prefix(50))
        }
        
        // Auto-dismiss after duration
        dismissTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if !Task.isCancelled {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.currentToast = nil
                }
            }
        }
    }
    
    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = nil
        }
    }
    
    // Convenience methods
    func success(_ title: String, detail: String? = nil) {
        show(.success, title: title, detail: detail)
    }
    
    func error(_ title: String, detail: String? = nil) {
        show(.error, title: title, detail: detail, duration: 5.0)
    }
    
    func warning(_ title: String, detail: String? = nil) {
        show(.warning, title: title, detail: detail, duration: 4.0)
    }
    
    func info(_ title: String, detail: String? = nil) {
        show(.info, title: title, detail: detail)
    }
}

// MARK: - Toast View
struct ToastView: View {
    let toast: ToastMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: toast.type.icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(toast.type.color)
            
            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(toast.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                    .lineLimit(1)
                
                if let detail = toast.detail, !detail.isEmpty {
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 20, height: 20)
                    .background(AppTheme.surfaceDefault.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AppTheme.backgroundCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(toast.type.color.opacity(0.4), lineWidth: 1)
                )
                .shadow(color: toast.type.color.opacity(0.15), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
        )
        .frame(maxWidth: 400)
    }
}

// MARK: - Toast Overlay Modifier
struct ToastOverlay: ViewModifier {
    @ObservedObject var toastManager = ToastManager.shared
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = toastManager.currentToast {
                    ToastView(toast: toast, onDismiss: { toastManager.dismiss() })
                        .padding(.top, 12)
                        .padding(.horizontal, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1000)
                }
            }
    }
}

extension View {
    func withToastOverlay() -> some View {
        modifier(ToastOverlay())
    }
}
