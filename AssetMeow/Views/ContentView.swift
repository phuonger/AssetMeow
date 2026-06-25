import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: SidebarItem = .dashboard
    
    enum SidebarItem: String, CaseIterable {
        case dashboard = "Dashboard"
        case scan = "Scan & Checkout"
        case checkin = "Check In"
        case quickLookup = "Quick Lookup"
        case inventory = "Inventory"
        case bulkOps = "Bulk Operations"
        case importExport = "Import / Export"
        case reports = "Reports"
        case activity = "Activity Log"
        case fieldManager = "Field Manager"
        case users = "Users"
        case settings = "Settings"
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .scan: return "barcode.viewfinder"
            case .checkin: return "arrow.down.to.line"
            case .quickLookup: return "magnifyingglass"
            case .inventory: return "list.bullet.rectangle"
            case .bulkOps: return "square.stack.3d.up"
            case .importExport: return "arrow.up.arrow.down"
            case .reports: return "chart.bar.doc.horizontal"
            case .activity: return "clock.arrow.circlepath"
            case .fieldManager: return "rectangle.grid.1x2"
            case .users: return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }
    
    var body: some View {
        mainContent
            .onChange(of: appState.navigateToTab) { newTab in
                if let tabName = newTab,
                   let tab = SidebarItem(rawValue: tabName) {
                    selectedTab = tab
                    appState.navigateToTab = nil
                }
            }
    }
    
    var mainContent: some View {
        HStack(spacing: 0) {
            // Custom sidebar
            sidebarView
            
            // Main content area
            ZStack {
                AppTheme.backgroundMedium.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top toolbar with event picker
                    topToolbar
                    
                    // Content
                    Group {
                        switch selectedTab {
                        case .dashboard:
                            DashboardView()
                        case .scan:
                            ScanCheckoutView()
                        case .checkin:
                            CheckInView()
                        case .quickLookup:
                            QuickLookupView()
                        case .inventory:
                            InventoryListView()
                        case .bulkOps:
                            BulkOperationsView()
                        case .importExport:
                            ImportExportView()
                        case .reports:
                            ReportsView()
                        case .activity:
                            ActivityLogView()
                        case .fieldManager:
                            FieldManagerView()
                        case .users:
                            UserManagementView()
                        case .settings:
                            SettingsView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .withToastOverlay()
        }
        .frame(minWidth: 1100, minHeight: 700)
    }
    
    // MARK: - Top Toolbar with Event Picker
    private var topToolbar: some View {
        HStack(spacing: 12) {
            Spacer()
            
            // Event picker
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppTheme.primaryPurpleLight)
                
                Text("Event:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                
                Menu {
                    Button(action: { appState.selectEvent(nil) }) {
                        HStack {
                            Text("All Events")
                            if appState.currentEvent == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(appState.events, id: \.id) { event in
                        Button(action: { appState.selectEvent(event) }) {
                            HStack {
                                Text(event.name)
                                if appState.currentEvent?.id == event.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(appState.currentEvent?.name ?? "All Events")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.surfaceDark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                            )
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            AppTheme.backgroundDark.opacity(0.3)
        )
        .overlay(
            Divider()
                .background(AppTheme.surfaceBorder.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // MARK: - Custom Sidebar
    var sidebarView: some View {
        VStack(spacing: 0) {
            // Logo / Branding
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "cat.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppTheme.primaryGradient)
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("AssetMeow")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Asset Tracker")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }
            
            Divider()
                .background(AppTheme.surfaceBorder.opacity(0.3))
                .padding(.horizontal, 12)
            
            // Navigation items
            ScrollView {
                VStack(spacing: 4) {
                    // Dashboard
                    sidebarSection("OVERVIEW") {
                        sidebarButton(.dashboard)
                    }
                    
                    // Main section
                    sidebarSection("OPERATIONS") {
                        sidebarButton(.scan)
                        sidebarButton(.checkin)
                        sidebarButton(.quickLookup)
                    }
                    
                    sidebarSection("MANAGEMENT") {
                        sidebarButton(.inventory)
                        sidebarButton(.bulkOps)
                        sidebarButton(.importExport)
                    }
                    
                    sidebarSection("REPORTS & LOGS") {
                        sidebarButton(.reports)
                        sidebarButton(.activity)
                    }
                    
                    sidebarSection("SYSTEM") {
                        sidebarButton(.fieldManager)
                        sidebarButton(.users)
                        sidebarButton(.settings)
                    }
                }
                .padding(.top, 12)
            }
            
            Spacer()
            
            // User info & logout
            VStack(spacing: 8) {
                Divider()
                    .background(AppTheme.surfaceBorder.opacity(0.3))
                    .padding(.horizontal, 12)
                
                HStack(spacing: 10) {
                    // User avatar
                    ZStack {
                        Circle()
                            .fill(AppTheme.primaryPurple.opacity(0.3))
                            .frame(width: 32, height: 32)
                        Text(String((appState.currentUser?.username ?? "U").prefix(1)).uppercased())
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.currentUser?.displayName ?? appState.currentUser?.username ?? "User")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(AppTheme.textPrimary)
                            .lineLimit(1)
                        Text(appState.currentUser?.role.capitalized ?? "")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    
                    Spacer()
                    
                    Button(action: logout) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 13))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Sign Out")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                // Connection status with activity indicator
                HStack(spacing: 6) {
                    if appState.isNetworkActive {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurpleLight))
                            .scaleEffect(0.5)
                            .frame(width: 6, height: 6)
                    } else {
                        Circle()
                            .fill(appState.isConnected ? AppTheme.statusAvailable : AppTheme.statusMissing)
                            .frame(width: 6, height: 6)
                    }
                    Text(appState.isNetworkActive ? "Syncing..." : (appState.isConnected ? "Connected" : "Offline"))
                        .font(.system(size: 10))
                        .foregroundColor(appState.isNetworkActive ? AppTheme.primaryPurpleLight : AppTheme.textMuted)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
                
                // Version number
                HStack {
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(AppTheme.textMuted.opacity(0.6))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(width: AppTheme.sidebarWidth)
        .background(
            ZStack {
                AppTheme.backgroundDark
                AppTheme.sidebarGradient
            }
        )
    }
    
    // MARK: - Sidebar Components
    
    @ViewBuilder
    func sidebarSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(AppTheme.textMuted)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            
            content()
        }
    }
    
    func sidebarButton(_ item: SidebarItem) -> some View {
        Button(action: { selectedTab = item }) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(selectedTab == item ? AppTheme.primaryPurpleLight : AppTheme.textSecondary)
                    .frame(width: 22)
                
                Text(item.rawValue)
                    .font(.system(size: 13, weight: selectedTab == item ? .semibold : .regular))
                    .foregroundColor(selectedTab == item ? AppTheme.textPrimary : AppTheme.textSecondary)
                
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                selectedTab == item ?
                    RoundedRectangle(cornerRadius: 8)
                        .fill(AppTheme.primaryPurple.opacity(0.15))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(AppTheme.primaryPurple.opacity(0.3), lineWidth: 1)
                        )
                    : nil
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }
    
    // MARK: - Functions
    
    private func logout() {
        Task {
            await appState.logout()
        }
    }
}
