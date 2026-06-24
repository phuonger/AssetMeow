import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var activities: [ActivityEntry] = []
    @State private var isLoading = false
    @State private var limit = 100
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Activity Log")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Track all actions performed in the system")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    Button(action: loadActivity) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                    
                    Picker("Show", selection: $limit) {
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("250").tag(250)
                        Text("500").tag(500)
                    }
                    .frame(width: 80)
                    .onChange(of: limit) { _ in loadActivity() }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
                
                if isLoading {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                        Text("Loading activity...")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                } else if activities.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No activity yet")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textMuted)
                        Text("Actions like check out, check in, and imports will appear here.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(activities, id: \.id) { entry in
                                activityRow(entry)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .onAppear { loadActivity() }
    }
    
    func activityRow(_ entry: ActivityEntry) -> some View {
        HStack(spacing: 12) {
            // Action icon
            ZStack {
                Circle()
                    .fill(actionColor(entry.action ?? "").opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: actionIcon(entry.action ?? ""))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(actionColor(entry.action ?? ""))
            }
            
            // Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.action ?? "Unknown")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)
                    if let tag = entry.assetTag, !tag.isEmpty {
                        CopyableAssetTag(assetTag: tag)
                    }
                    if let model = entry.model {
                        CopyableText(text: "(\(model))", color: AppTheme.textMuted)
                    }
                }
                
                HStack(spacing: 16) {
                    if let from = entry.fromLocation, let to = entry.toLocation {
                        HStack(spacing: 4) {
                            Text(from)
                                .foregroundColor(AppTheme.textMuted)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.textMuted)
                            Text(to)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .font(AppTheme.captionFont)
                    } else if let to = entry.toLocation {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 8))
                                .foregroundColor(AppTheme.textMuted)
                            Text(to)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .font(AppTheme.captionFont)
                    }
                    
                    if let from = entry.fromPerson {
                        Text("from: \(from)")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    if let to = entry.toPerson {
                        Text("to: \(to)")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.accentCyan)
                    }
                }
                
                if let performedBy = entry.performedBy, !performedBy.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 9))
                        Text("by \(performedBy)")
                    }
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.primaryPurpleLight.opacity(0.7))
                }
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentOrange)
                }
            }
            
            Spacer()
            
            // Timestamp
            Text(entry.createdAt ?? "")
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppTheme.backgroundDark)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.surfaceBorder, lineWidth: 0.5)
        )
    }
    
    func actionIcon(_ action: String) -> String {
        switch action {
        case "Check Out": return "arrow.up.right.square"
        case "Check In": return "arrow.down.left.square"
        case "Move": return "arrow.right.square"
        case "Scan": return "barcode.viewfinder"
        case "Update": return "pencil.circle"
        case "Import": return "square.and.arrow.down"
        case "Delete": return "trash"
        case "Create": return "plus.circle"
        default: return "circle"
        }
    }
    
    func actionColor(_ action: String) -> Color {
        switch action {
        case "Check Out": return AppTheme.accentOrange
        case "Check In": return AppTheme.statusAvailable
        case "Move": return AppTheme.accentCyan
        case "Scan": return AppTheme.primaryPurple
        case "Update": return Color.yellow
        case "Import": return AppTheme.accentCyan
        case "Delete": return AppTheme.statusMissing
        case "Create": return AppTheme.statusAvailable
        default: return AppTheme.textMuted
        }
    }
    
    func loadActivity() {
        isLoading = true
        Task {
            do {
                let resp = try await APIService.shared.getActivity(limit: limit)
                await MainActor.run {
                    activities = resp.activity
                }
            } catch {
                print("Error loading activity: \(error)")
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
}
