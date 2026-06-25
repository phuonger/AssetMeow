import SwiftUI

struct ActivityLogView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var activities: [ActivityEntry] = []
    @State private var isLoading = false
    @State private var limit = 100
    @State private var showColumnSettings = false
    @State private var isExporting = false
    
    // Column visibility settings (persisted via AppStorage)
    @AppStorage("activityLog_showCategory") private var showCategory = true
    @AppStorage("activityLog_showMake") private var showMake = false
    @AppStorage("activityLog_showModel") private var showModel = true
    @AppStorage("activityLog_showSKU") private var showSKU = false
    @AppStorage("activityLog_showLocation") private var showLocation = true
    @AppStorage("activityLog_showPerson") private var showPerson = true
    @AppStorage("activityLog_showNotes") private var showNotes = true
    @AppStorage("activityLog_showPerformedBy") private var showPerformedBy = true
    
    // Filter
    @State private var filterAction = "All"
    @State private var searchText = ""
    
    var filteredActivities: [ActivityEntry] {
        var result = activities
        if filterAction != "All" {
            result = result.filter { $0.action == filterAction }
        }
        if !searchText.isEmpty {
            result = result.filter { entry in
                let searchLower = searchText.lowercased()
                return (entry.assetTag?.lowercased().contains(searchLower) ?? false) ||
                       (entry.model?.lowercased().contains(searchLower) ?? false) ||
                       (entry.category?.lowercased().contains(searchLower) ?? false) ||
                       (entry.make?.lowercased().contains(searchLower) ?? false) ||
                       (entry.sku?.lowercased().contains(searchLower) ?? false) ||
                       (entry.notes?.lowercased().contains(searchLower) ?? false) ||
                       (entry.toLocation?.lowercased().contains(searchLower) ?? false) ||
                       (entry.fromLocation?.lowercased().contains(searchLower) ?? false) ||
                       (entry.toPerson?.lowercased().contains(searchLower) ?? false)
            }
        }
        return result
    }
    
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
                        Text("\(filteredActivities.count) entries")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    // Search
                    HStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        TextField("Search...", text: $searchText)
                            .font(.system(size: 12))
                            .frame(width: 140)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(AppTheme.backgroundDark)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.surfaceBorder, lineWidth: 0.5)
                    )
                    
                    // Filter by action
                    Picker("Action", selection: $filterAction) {
                        Text("All").tag("All")
                        Text("Check Out").tag("Check Out")
                        Text("Check In").tag("Check In")
                        Text("Move").tag("Move")
                        Text("Update").tag("Update")
                        Text("Import").tag("Import")
                        Text("Create").tag("Create")
                        Text("Delete").tag("Delete")
                    }
                    .frame(width: 110)
                    
                    // Limit
                    Picker("Show", selection: $limit) {
                        Text("50").tag(50)
                        Text("100").tag(100)
                        Text("250").tag(250)
                        Text("500").tag(500)
                    }
                    .frame(width: 70)
                    .onChange(of: limit) { _ in loadActivity() }
                    
                    // Column settings
                    Button(action: { showColumnSettings.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Columns")
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryPurpleLight)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.primaryPurple.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Export CSV
                    Button(action: exportCSV) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export")
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentCyan)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(AppTheme.accentCyan.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    
                    // Refresh
                    Button(action: loadActivity) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // Column settings panel
                if showColumnSettings {
                    columnSettingsPanel
                }
                
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
                } else if filteredActivities.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No activity found")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textMuted)
                        if !searchText.isEmpty || filterAction != "All" {
                            Text("Try adjusting your search or filter.")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    Spacer()
                } else {
                    // Table header
                    tableHeaderView
                    
                    // Table rows
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredActivities, id: \.id) { entry in
                                activityRow(entry)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .onAppear { loadActivity() }
    }
    
    // MARK: - Column Settings Panel
    var columnSettingsPanel: some View {
        HStack(spacing: 16) {
            Text("Visible Columns:")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppTheme.textSecondary)
            
            Toggle("Category", isOn: $showCategory)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("Make", isOn: $showMake)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("Model", isOn: $showModel)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("SKU", isOn: $showSKU)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("Location", isOn: $showLocation)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("Person", isOn: $showPerson)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("Notes", isOn: $showNotes)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            Toggle("Performed By", isOn: $showPerformedBy)
                .toggleStyle(.checkbox)
                .font(.system(size: 11))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(AppTheme.backgroundDark.opacity(0.5))
    }
    
    // MARK: - Table Header
    var tableHeaderView: some View {
        HStack(spacing: 0) {
            Text("Action")
                .frame(width: 90, alignment: .leading)
            Text("Asset Tag")
                .frame(width: 120, alignment: .leading)
            if showCategory {
                Text("Category")
                    .frame(width: 100, alignment: .leading)
            }
            if showMake {
                Text("Make")
                    .frame(width: 90, alignment: .leading)
            }
            if showModel {
                Text("Model")
                    .frame(width: 120, alignment: .leading)
            }
            if showSKU {
                Text("SKU")
                    .frame(width: 100, alignment: .leading)
            }
            if showLocation {
                Text("Location")
                    .frame(width: 160, alignment: .leading)
            }
            if showPerson {
                Text("Person")
                    .frame(width: 120, alignment: .leading)
            }
            if showNotes {
                Text("Notes")
                    .frame(minWidth: 120, alignment: .leading)
            }
            if showPerformedBy {
                Text("By")
                    .frame(width: 80, alignment: .leading)
            }
            Text("Date")
                .frame(width: 130, alignment: .trailing)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundColor(AppTheme.textMuted)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .background(AppTheme.backgroundDark.opacity(0.7))
    }
    
    // MARK: - Activity Row
    func activityRow(_ entry: ActivityEntry) -> some View {
        HStack(spacing: 0) {
            // Action badge
            HStack(spacing: 4) {
                Circle()
                    .fill(actionColor(entry.action ?? ""))
                    .frame(width: 6, height: 6)
                Text(entry.action ?? "Unknown")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(actionColor(entry.action ?? ""))
                    .lineLimit(1)
            }
            .frame(width: 90, alignment: .leading)
            
            // Asset Tag
            if let tag = entry.assetTag, !tag.isEmpty {
                CopyableAssetTag(assetTag: tag)
                    .frame(width: 120, alignment: .leading)
            } else {
                Text("—")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 120, alignment: .leading)
            }
            
            // Category
            if showCategory {
                Text(entry.category ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }
            
            // Make
            if showMake {
                Text(entry.make ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 90, alignment: .leading)
            }
            
            // Model
            if showModel {
                Text(entry.model ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 120, alignment: .leading)
            }
            
            // SKU
            if showSKU {
                Text(entry.sku ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
            }
            
            // Location
            if showLocation {
                HStack(spacing: 3) {
                    if let from = entry.fromLocation {
                        Text(from)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 7))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    if let to = entry.toLocation {
                        Text(to)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                            .lineLimit(1)
                    }
                    if entry.fromLocation == nil && entry.toLocation == nil {
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .frame(width: 160, alignment: .leading)
            }
            
            // Person
            if showPerson {
                HStack(spacing: 3) {
                    if let from = entry.fromPerson {
                        Text(from)
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                            .lineLimit(1)
                        if entry.toPerson != nil {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 7))
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    if let to = entry.toPerson {
                        Text(to)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.accentCyan)
                            .lineLimit(1)
                    }
                    if entry.fromPerson == nil && entry.toPerson == nil {
                        Text("—")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
            
            // Notes
            if showNotes {
                Text(entry.notes ?? "—")
                    .font(.system(size: 10))
                    .foregroundColor(entry.notes != nil ? AppTheme.accentOrange : AppTheme.textMuted)
                    .lineLimit(2)
                    .frame(minWidth: 120, alignment: .leading)
                    .help(entry.notes ?? "")
            }
            
            // Performed By
            if showPerformedBy {
                Text(entry.performedBy ?? "—")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.primaryPurpleLight.opacity(0.7))
                    .lineLimit(1)
                    .frame(width: 80, alignment: .leading)
            }
            
            // Date
            Text(formatDate(entry.createdAt))
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 130, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(AppTheme.backgroundDark)
        .cornerRadius(4)
    }
    
    // MARK: - Helpers
    
    func formatDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "—" }
        // Try to parse and format nicely
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "MMM d, yyyy h:mm a"
            return displayFormatter.string(from: date)
        }
        return dateStr
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
    
    // MARK: - CSV Export
    func exportCSV() {
        let entries = filteredActivities
        guard !entries.isEmpty else {
            ToastManager.shared.warning("No Data", detail: "No activity entries to export.")
            return
        }
        
        var csv = "Action,Asset Tag,Category,Make,Model,SKU,From Location,To Location,From Person,To Person,Notes,Performed By,Date\n"
        
        for entry in entries {
            let row = [
                escapeCSV(entry.action ?? ""),
                escapeCSV(entry.assetTag ?? ""),
                escapeCSV(entry.category ?? ""),
                escapeCSV(entry.make ?? ""),
                escapeCSV(entry.model ?? ""),
                escapeCSV(entry.sku ?? ""),
                escapeCSV(entry.fromLocation ?? ""),
                escapeCSV(entry.toLocation ?? ""),
                escapeCSV(entry.fromPerson ?? ""),
                escapeCSV(entry.toPerson ?? ""),
                escapeCSV(entry.notes ?? ""),
                escapeCSV(entry.performedBy ?? ""),
                escapeCSV(entry.createdAt ?? "")
            ].joined(separator: ",")
            csv += row + "\n"
        }
        
        // Save to file and open
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "activity_log_\(DateFormatter.fileTimestamp.string(from: Date())).csv"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try csv.write(to: url, atomically: true, encoding: .utf8)
                ToastManager.shared.success("Export Complete", detail: "Saved \(entries.count) entries to CSV.")
            } catch {
                ToastManager.shared.error("Export Failed", detail: error.localizedDescription)
            }
        }
    }
    
    func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}

// DateFormatter extension for file timestamps
extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
}
