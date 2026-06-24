import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var devices: [Device] = []
    @State private var isLoading = false
    @State private var lastRefresh: Date?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Content
            ScrollView {
                VStack(spacing: 24) {
                    // Summary cards
                    summaryCardsView
                    
                    // Location breakdown table
                    locationBreakdownView
                }
                .padding(24)
            }
        }
        .background(AppTheme.backgroundMedium)
        .onAppear { loadDashboard() }
        .onChange(of: appState.currentEvent?.id) { _ in loadDashboard() }
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dashboard")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                
                Text(appState.currentEvent?.name ?? "All Events")
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            Spacer()
            
            // Refresh button
            Button(action: { loadDashboard() }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12, weight: .medium))
                    Text("Refresh")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(AppTheme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppTheme.surfaceLight.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            if let lastRefresh = lastRefresh {
                Text("Updated \(lastRefresh, style: .relative) ago")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(AppTheme.backgroundDark.opacity(0.5))
    }
    
    // MARK: - Summary Cards
    private var summaryCardsView: some View {
        HStack(spacing: 16) {
            summaryCard(
                title: "Total Devices",
                value: "\(devices.count)",
                icon: "cpu",
                color: AppTheme.primaryPurple
            )
            summaryCard(
                title: "Checked In",
                value: "\(checkedInCount)",
                icon: "arrow.down.to.line",
                color: AppTheme.statusAvailable
            )
            summaryCard(
                title: "Checked Out",
                value: "\(checkedOutCount)",
                icon: "arrow.up.forward",
                color: AppTheme.statusCheckedOut
            )
            summaryCard(
                title: "Missing",
                value: "\(missingCount)",
                icon: "exclamationmark.triangle",
                color: AppTheme.statusMissing
            )
        }
    }
    
    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.textPrimary)
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surfaceDark)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                )
        )
    }
    
    // MARK: - Location Breakdown Table
    private var locationBreakdownView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Breakdown by Assigned Location")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
            
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                    Text("Loading...")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                }
                .padding(40)
            } else if locationGroups.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.textMuted)
                    Text("No devices found")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textSecondary)
                    if appState.currentEvent != nil {
                        Text("Try selecting a different event or 'All Events'")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 0) {
                    // Table header
                    tableHeaderRow
                    
                    // Location groups
                    ForEach(locationGroups, id: \.locationName) { group in
                        locationGroupView(group)
                    }
                    
                    // Grand total
                    grandTotalRow
                }
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppTheme.surfaceDark)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                        )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    
    private var tableHeaderRow: some View {
        HStack(spacing: 0) {
            Text("Location / Category")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Checked In")
                .frame(width: 120, alignment: .center)
            Text("Checked Out")
                .frame(width: 120, alignment: .center)
            Text("Total")
                .frame(width: 100, alignment: .center)
        }
        .font(.system(size: 12, weight: .bold))
        .foregroundColor(AppTheme.textSecondary)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.backgroundDark.opacity(0.5))
    }
    
    private func locationGroupView(_ group: LocationGroup) -> some View {
        VStack(spacing: 0) {
            // Location header row
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.primaryPurple)
                    Text(group.locationName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\(group.totalCheckedIn)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.statusAvailable)
                    .frame(width: 120, alignment: .center)
                
                Text("\(group.totalCheckedOut)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.statusCheckedOut)
                    .frame(width: 120, alignment: .center)
                
                Text("\(group.totalDevices)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.textPrimary)
                    .frame(width: 100, alignment: .center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppTheme.surfaceLight.opacity(0.3))
            
            // Category rows
            ForEach(group.categories, id: \.categoryName) { cat in
                HStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Text("")
                            .frame(width: 14) // indent
                        Image(systemName: "tag")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textMuted)
                        Text(cat.categoryName)
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("\(cat.checkedIn)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 120, alignment: .center)
                    
                    Text("\(cat.checkedOut)")
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 120, alignment: .center)
                    
                    Text("\(cat.total)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.textSecondary)
                        .frame(width: 100, alignment: .center)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
            }
            
            Divider()
                .background(AppTheme.surfaceBorder.opacity(0.3))
        }
    }
    
    private var grandTotalRow: some View {
        HStack(spacing: 0) {
            Text("GRAND TOTAL")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text("\(checkedInCount)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.statusAvailable)
                .frame(width: 120, alignment: .center)
            
            Text("\(checkedOutCount)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.statusCheckedOut)
                .frame(width: 120, alignment: .center)
            
            Text("\(devices.count)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 100, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppTheme.primaryPurple.opacity(0.1))
    }
    
    // MARK: - Data Models
    
    struct LocationGroup {
        let locationName: String
        let categories: [CategoryCount]
        var totalCheckedIn: Int { categories.reduce(0) { $0 + $1.checkedIn } }
        var totalCheckedOut: Int { categories.reduce(0) { $0 + $1.checkedOut } }
        var totalDevices: Int { categories.reduce(0) { $0 + $1.total } }
    }
    
    struct CategoryCount {
        let categoryName: String
        let checkedIn: Int
        let checkedOut: Int
        var total: Int { checkedIn + checkedOut }
    }
    
    // MARK: - Computed Properties
    
    private var checkedInCount: Int {
        devices.filter { $0.status == .available }.count
    }
    
    private var checkedOutCount: Int {
        devices.filter { $0.status == .checkedOut }.count
    }
    
    private var missingCount: Int {
        devices.filter { $0.status == .missing }.count
    }
    
    private var locationGroups: [LocationGroup] {
        // Group devices by assigned location
        let grouped = Dictionary(grouping: devices) { device -> String in
            device.assignedLocationName ?? "Unassigned"
        }
        
        return grouped.keys.sorted().map { locationName in
            let locationDevices = grouped[locationName] ?? []
            
            // Group by category within this location
            let catGrouped = Dictionary(grouping: locationDevices) { device -> String in
                device.category ?? "Uncategorized"
            }
            
            let categories = catGrouped.keys.sorted().map { catName in
                let catDevices = catGrouped[catName] ?? []
                let checkedIn = catDevices.filter { $0.status == .available }.count
                let checkedOut = catDevices.filter { $0.status == .checkedOut || $0.status == .inTransit }.count
                return CategoryCount(categoryName: catName, checkedIn: checkedIn, checkedOut: checkedOut)
            }
            
            return LocationGroup(locationName: locationName, categories: categories)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadDashboard() {
        isLoading = true
        Task {
            do {
                let response = try await APIService.shared.getDevices(
                    eventId: appState.currentEvent?.id,
                    limit: 10000
                )
                devices = response.devices
                lastRefresh = Date()
            } catch {
                print("Dashboard load error: \(error)")
            }
            isLoading = false
        }
    }
}
