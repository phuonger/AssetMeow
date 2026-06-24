import SwiftUI

struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var activityEntries: [ActivityEntry] = []
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    // Filters
    @State private var filterAction: String = "All"
    @State private var filterLimit: Int = 100
    @State private var searchQuery = ""
    
    let actionFilters = ["All", "checkout", "checkin", "move", "create", "update", "delete"]
    let limitOptions = [50, 100, 200, 500, 1000]
    
    var filteredEntries: [ActivityEntry] {
        var entries = activityEntries
        
        if filterAction != "All" {
            entries = entries.filter { ($0.action ?? "").lowercased() == filterAction.lowercased() }
        }
        
        if !searchQuery.isEmpty {
            let q = searchQuery.lowercased()
            entries = entries.filter { entry in
                (entry.assetTag ?? "").lowercased().contains(q) ||
                (entry.model ?? "").lowercased().contains(q) ||
                (entry.toLocation ?? "").lowercased().contains(q) ||
                (entry.fromLocation ?? "").lowercased().contains(q) ||
                (entry.toPerson ?? "").lowercased().contains(q) ||
                (entry.fromPerson ?? "").lowercased().contains(q) ||
                (entry.performedBy ?? "").lowercased().contains(q) ||
                (entry.notes ?? "").lowercased().contains(q)
            }
        }
        
        return entries
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reports")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("View and export device scan logs, check-in/check-out history")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    // Export button
                    Button(action: exportFilteredLog) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.doc.fill")
                            Text("Export to CSV")
                        }
                        .primaryButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredEntries.isEmpty)
                }
                .padding(20)
                
                // Filters bar
                HStack(spacing: 16) {
                    // Action filter
                    HStack(spacing: 6) {
                        Text("Action:")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                        Picker("", selection: $filterAction) {
                            ForEach(actionFilters, id: \.self) { action in
                                Text(action == "All" ? "All Actions" : action.capitalized).tag(action)
                            }
                        }
                        .frame(width: 140)
                    }
                    
                    // Limit
                    HStack(spacing: 6) {
                        Text("Show:")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                        Picker("", selection: $filterLimit) {
                            ForEach(limitOptions, id: \.self) { limit in
                                Text("\(limit) records").tag(limit)
                            }
                        }
                        .frame(width: 120)
                        .onChange(of: filterLimit) { _ in
                            loadActivity()
                        }
                    }
                    
                    // Search
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textMuted)
                        TextField("Search asset tag, location, person...", text: $searchQuery)
                            .textFieldStyle(.plain)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.backgroundDark)
                    .cornerRadius(8)
                    .frame(maxWidth: 280)
                    
                    Spacer()
                    
                    // Refresh
                    Button(action: loadActivity) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                    
                    // Summary
                    Text("\(filteredEntries.count) records")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textMuted)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Quick report buttons
                HStack(spacing: 10) {
                    quickReportButton("Check-Outs Only", icon: "arrow.up.right.square", action: "checkout")
                    quickReportButton("Check-Ins Only", icon: "arrow.down.to.line", action: "checkin")
                    quickReportButton("Moves", icon: "arrow.left.arrow.right", action: "move")
                    quickReportButton("All Activity", icon: "list.bullet.rectangle", action: "All")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                Divider()
                    .background(AppTheme.surfaceBorder)
                
                // Activity table
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                    Text("Loading activity log...")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                } else if !errorMessage.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 30))
                            .foregroundColor(AppTheme.statusMissing)
                        Text(errorMessage)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textSecondary)
                        Button("Retry") { loadActivity() }
                            .buttonStyle(.plain)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    Spacer()
                } else if filteredEntries.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 30))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No activity records found")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textSecondary)
                        if filterAction != "All" || !searchQuery.isEmpty {
                            Text("Try adjusting your filters")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                        }
                    }
                    Spacer()
                } else {
                    activityTable
                }
            }
        }
        .onAppear { loadActivity() }
    }
    
    // MARK: - Quick Report Button
    func quickReportButton(_ title: String, icon: String, action: String) -> some View {
        Button(action: { filterAction = action }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(filterAction == action ? AppTheme.primaryPurple.opacity(0.2) : AppTheme.surfaceDefault)
            .foregroundColor(filterAction == action ? AppTheme.primaryPurpleLight : AppTheme.textSecondary)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(filterAction == action ? AppTheme.primaryPurple.opacity(0.5) : AppTheme.surfaceBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Activity Table
    var activityTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Table header
                HStack(spacing: 0) {
                    tableHeader("Date", width: 140)
                    tableHeader("Action", width: 80)
                    tableHeader("Asset Tag", width: 130)
                    tableHeader("Model", width: 120)
                    tableHeader("From", width: 120)
                    tableHeader("To", width: 120)
                    tableHeader("Person", width: 100)
                    tableHeader("By", width: 80)
                    tableHeader("Notes", width: nil)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppTheme.backgroundDark)
                
                // Table rows
                ForEach(filteredEntries, id: \.id) { entry in
                    HStack(spacing: 0) {
                        Text(formatDate(entry.createdAt))
                            .frame(width: 140, alignment: .leading)
                        
                        actionBadge(entry.action ?? "—")
                            .frame(width: 80, alignment: .leading)
                        
                        CopyableAssetTag(assetTag: entry.assetTag ?? "—")
                            .frame(width: 130, alignment: .leading)
                        
                        CopyableText(text: entry.model ?? "—")
                            .frame(width: 120, alignment: .leading)
                        
                        CopyableText(text: entry.fromLocation ?? entry.fromPerson ?? "—")
                            .frame(width: 120, alignment: .leading)
                        
                        CopyableText(text: entry.toLocation ?? entry.toPerson ?? "—")
                            .frame(width: 120, alignment: .leading)
                        
                        CopyableText(text: entry.toPerson ?? entry.fromPerson ?? "—")
                            .frame(width: 100, alignment: .leading)
                        
                        CopyableText(text: entry.performedBy ?? "—")
                            .frame(width: 80, alignment: .leading)
                        
                        Text(entry.notes ?? "")
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(
                        (filteredEntries.firstIndex(where: { $0.id == entry.id }) ?? 0) % 2 == 0
                            ? Color.clear
                            : AppTheme.backgroundDark.opacity(0.3)
                    )
                    
                    Divider()
                        .background(AppTheme.surfaceBorder.opacity(0.5))
                }
            }
        }
    }
    
    func tableHeader(_ title: String, width: CGFloat?) -> some View {
        Group {
            if let w = width {
                Text(title)
                    .frame(width: w, alignment: .leading)
            } else {
                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(AppTheme.textMuted)
        .textCase(.uppercase)
    }
    
    func actionBadge(_ action: String) -> some View {
        let color: Color = {
            switch action.lowercased() {
            case "checkout": return AppTheme.statusCheckedOut
            case "checkin": return AppTheme.statusAvailable
            case "move": return AppTheme.accentCyan
            case "create": return AppTheme.primaryPurple
            case "delete": return AppTheme.statusMissing
            default: return AppTheme.textMuted
            }
        }()
        
        return Text(action.capitalized)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .cornerRadius(4)
    }
    
    func formatDate(_ dateStr: String?) -> String {
        guard let dateStr = dateStr else { return "—" }
        // Try to parse and reformat
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = inputFormatter.date(from: dateStr) {
            let outputFormatter = DateFormatter()
            outputFormatter.dateFormat = "MMM d, h:mm a"
            return outputFormatter.string(from: date)
        }
        return dateStr
    }
    
    // MARK: - Actions
    func loadActivity() {
        isLoading = true
        errorMessage = ""
        Task {
            do {
                let response = try await APIService.shared.getActivity(limit: filterLimit)
                activityEntries = response.activity
            } catch {
                errorMessage = "Failed to load activity: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }
    
    func exportFilteredLog() {
        let entries = filteredEntries
        guard !entries.isEmpty else { return }
        
        let actionLabel = filterAction == "All" ? "all_activity" : filterAction
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = dateFormatter.string(from: Date())
        let filename = "report_\(actionLabel)_\(dateStr).csv"
        
        CSVExporter.exportActivityLog(entries, filename: filename)
    }
}
