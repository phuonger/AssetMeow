import SwiftUI

struct QuickLookupView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var scanInput = ""
    @State private var lookupResult: Device?
    @State private var notFound = false
    @State private var isLoading = false
    @State private var searchResults: [Device] = []
    @State private var isSearchMode = false
    
    // Display toggles
    @State private var showCategory = true
    @State private var showModel = true
    @State private var showSKU = false
    @State private var showStatus = true
    @State private var showLocation = true
    @State private var showAssignedLocation = true
    @State private var showAssignedTo = true
    @State private var showAccount = false
    @State private var showLiveDummy = false
    @State private var showLastScanned = true
    @State private var showEvent = false
    @State private var showNotes = false
    @State private var showDisplayOptions = false
    
    @FocusState private var inputFocused: Bool
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Quick Lookup")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Scan a barcode or type asset tags. Comma-separate for bulk search.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Input
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textMuted)
                        TextField("Scan or type asset tag(s)...", text: $scanInput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.textPrimary)
                            .focused($inputFocused)
                            .onSubmit { performLookup() }
                    }
                    .padding(10)
                    .background(AppTheme.backgroundDark)
                    .cornerRadius(AppTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                    )
                    
                    Button(action: performLookup) {
                        Text("Lookup")
                            .primaryButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(scanInput.isEmpty)
                    
                    if lookupResult != nil || !searchResults.isEmpty {
                        Button(action: {
                            lookupResult = nil
                            searchResults.removeAll()
                            notFound = false
                            scanInput = ""
                            inputFocused = true
                        }) {
                            Text("Clear")
                                .secondaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                
                // Divider
                Rectangle()
                    .fill(AppTheme.surfaceBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                
                // Results
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                    Text("Looking up...")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                } else if notFound {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentOrange.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 32))
                                .foregroundColor(AppTheme.accentOrange)
                        }
                        Text("Device Not Found")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Asset tag not in database. It may need to be imported first.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                } else if let device = lookupResult {
                    ScrollView {
                        deviceDetailCard(device)
                            .padding(.horizontal, 20)
                    }
                } else if !searchResults.isEmpty {
                    multiResultView
                } else {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(AppTheme.textMuted)
                        Text("Scan or type to look up a device")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Spacer()
                }
            }
        }
        .onAppear { inputFocused = true }
    }
    
    // MARK: - Multi-Result View
    var multiResultView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Results header
            HStack {
                Text("\(searchResults.count) devices found")
                    .font(AppTheme.subheadingFont)
                    .foregroundColor(AppTheme.textPrimary)
                
                Spacer()
                
                Button(action: { showDisplayOptions.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Display Options")
                    }
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.primaryPurpleLight)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.surfaceDefault)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            
            // Display options panel
            if showDisplayOptions {
                displayOptionsPanel
            }
            
            // Table header
            HStack(spacing: 0) {
                Text("Asset Tag")
                    .frame(width: 120, alignment: .leading)
                if showCategory { Text("Category").frame(width: 80, alignment: .leading) }
                if showModel { Text("Model").frame(width: 100, alignment: .leading) }
                if showSKU { Text("SKU").frame(width: 100, alignment: .leading) }
                if showStatus { Text("Status").frame(width: 90, alignment: .leading) }
                if showLocation { Text("Current Location").frame(width: 120, alignment: .leading) }
                if showAssignedLocation { Text("Assigned Location").frame(width: 130, alignment: .leading) }
                if showAssignedTo { Text("Assigned To").frame(width: 110, alignment: .leading) }
                if showAccount { Text("Account").frame(width: 90, alignment: .leading) }
                if showLiveDummy { Text("Live/Dummy").frame(width: 80, alignment: .leading) }
                if showLastScanned { Text("Last Scanned").frame(width: 130, alignment: .leading) }
                if showEvent { Text("Event").frame(width: 100, alignment: .leading) }
                if showNotes { Text("Notes").frame(width: 150, alignment: .leading) }
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textMuted)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundDark)
            
            // Results list
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(searchResults, id: \.assetTag) { device in
                        HStack(spacing: 0) {
                            CopyableAssetTag(assetTag: device.assetTag)
                                .frame(width: 120, alignment: .leading)
                            if showCategory {
                                Text(device.category ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 80, alignment: .leading)
                            }
                            if showModel {
                                Text(device.model ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 100, alignment: .leading)
                            }
                            if showSKU {
                                Text(device.sku ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 100, alignment: .leading)
                            }
                            if showStatus {
                                themedStatusBadge(device.status)
                                    .frame(width: 90, alignment: .leading)
                            }
                            if showLocation {
                                Text(device.locationName ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 120, alignment: .leading)
                            }
                            if showAssignedLocation {
                                Text(device.assignedLocationName ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 130, alignment: .leading)
                            }
                            if showAssignedTo {
                                Text(device.assignedToName ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 110, alignment: .leading)
                            }
                            if showAccount {
                                Text(device.account ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 90, alignment: .leading)
                            }
                            if showLiveDummy {
                                Text(device.liveOrDummy ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 80, alignment: .leading)
                            }
                            if showLastScanned {
                                Text(device.lastScanned ?? "Never")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 130, alignment: .leading)
                            }
                            if showEvent {
                                Text(device.eventName ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 100, alignment: .leading)
                            }
                            if showNotes {
                                Text(device.notes ?? "—")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .lineLimit(1)
                                    .frame(width: 150, alignment: .leading)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceDefault.opacity(0.5))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            lookupResult = device
                            searchResults.removeAll()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Display Options Panel
    var displayOptionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose columns to display:")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130))], spacing: 6) {
                Toggle("Category", isOn: $showCategory).toggleStyle(.checkbox)
                Toggle("Model", isOn: $showModel).toggleStyle(.checkbox)
                Toggle("SKU / Style", isOn: $showSKU).toggleStyle(.checkbox)
                Toggle("Status", isOn: $showStatus).toggleStyle(.checkbox)
                Toggle("Current Location", isOn: $showLocation).toggleStyle(.checkbox)
                Toggle("Assigned Location", isOn: $showAssignedLocation).toggleStyle(.checkbox)
                Toggle("Assigned To", isOn: $showAssignedTo).toggleStyle(.checkbox)
                Toggle("Account", isOn: $showAccount).toggleStyle(.checkbox)
                Toggle("Live/Dummy", isOn: $showLiveDummy).toggleStyle(.checkbox)
                Toggle("Last Scanned", isOn: $showLastScanned).toggleStyle(.checkbox)
                Toggle("Event", isOn: $showEvent).toggleStyle(.checkbox)
                Toggle("Notes", isOn: $showNotes).toggleStyle(.checkbox)
            }
            .font(AppTheme.captionFont)
            .foregroundColor(AppTheme.textPrimary)
        }
        .padding(12)
        .background(AppTheme.surfaceDefault)
        .cornerRadius(AppTheme.cornerRadius)
        .padding(.horizontal, 20)
    }
    
    // MARK: - Device Detail Card
    func deviceDetailCard(_ device: Device) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Back button
            if !scanInput.isEmpty && scanInput.contains(",") {
                Button(action: {
                    lookupResult = nil
                    performLookup()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back to results")
                    }
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.primaryPurpleLight)
                }
                .buttonStyle(.plain)
            }
            
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    CopyableAssetTag(assetTag: device.assetTag)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                    if let model = device.model {
                        CopyableText(text: model, font: AppTheme.bodyFont, color: AppTheme.textSecondary)
                    }
                }
                Spacer()
                themedStatusBadge(device.status)
            }
            
            Rectangle()
                .fill(AppTheme.surfaceBorder)
                .frame(height: 1)
            
            // Info grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                infoField("Category", device.category ?? "—")
                infoField("SKU / Style", device.sku ?? "—")
                infoField("Current Location", device.locationName ?? "—")
                infoField("Assigned Location", device.assignedLocationName ?? "—")
                infoField("Assigned To", device.assignedToName ?? "—")
                infoField("Event", device.eventName ?? "—")
                infoField("Account", device.account ?? "—")
                infoField("Live/Dummy", device.liveOrDummy ?? "—")
                infoField("Last Scanned", device.lastScanned ?? "Never")
            }
            
            if let notes = device.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textMuted)
                    Text(notes)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textPrimary)
                }
            }
            
            // Custom Fields
            if let customData = device.customData, !customData.isEmpty {
                Rectangle()
                    .fill(AppTheme.surfaceBorder)
                    .frame(height: 1)
                Text("Custom Fields")
                    .font(AppTheme.subheadingFont)
                    .foregroundColor(AppTheme.textPrimary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(customData.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        infoField(key, value)
                    }
                }
            }
            
            // Activity history
            if let activity = device.recentActivity, !activity.isEmpty {
                Rectangle()
                    .fill(AppTheme.surfaceBorder)
                    .frame(height: 1)
                Text("Recent Activity")
                    .font(AppTheme.subheadingFont)
                    .foregroundColor(AppTheme.textPrimary)
                
                ForEach(activity, id: \.id) { entry in
                    HStack(alignment: .top) {
                        Image(systemName: activityIcon(entry.action ?? ""))
                            .foregroundColor(AppTheme.primaryPurpleLight)
                            .frame(width: 20)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.action ?? "")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textPrimary)
                            if let to = entry.toLocation {
                                Text("→ \(to)")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            if let tp = entry.toPerson {
                                Text("→ \(tp)")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            if let notes = entry.notes, !notes.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "note.text")
                                        .font(.system(size: 9))
                                    Text(notes)
                                        .font(.system(size: 10))
                                        .lineLimit(2)
                                }
                                .foregroundColor(AppTheme.textSecondary)
                                .padding(.top, 1)
                            }
                        }
                        Spacer()
                        Text(entry.createdAt ?? "")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .glowCardStyle()
    }
    
    // MARK: - Helpers
    func themedStatusBadge(_ status: DeviceStatus) -> some View {
        Text(status.rawValue)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(AppTheme.statusColor(for: status.rawValue).opacity(0.2))
            .foregroundColor(AppTheme.statusColor(for: status.rawValue))
            .cornerRadius(6)
    }
    
    func infoField(_ label: String, _ value: String) -> some View {
        CopyableField(label: label, value: value)
    }
    
    func activityIcon(_ action: String) -> String {
        switch action {
        case "Check Out": return "arrow.up.right"
        case "Check In": return "arrow.down.left"
        case "Move": return "arrow.right"
        case "Scan": return "barcode"
        default: return "circle"
        }
    }
    
    // MARK: - Actions
    func performLookup() {
        let input = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        
        isLoading = true
        lookupResult = nil
        searchResults.removeAll()
        notFound = false
        
        Task {
            do {
                if input.contains(",") {
                    let result = try await APIService.shared.searchDevices(tags: input)
                    searchResults = result.devices
                    if searchResults.isEmpty { notFound = true }
                } else {
                    let result = try await APIService.shared.lookupDevice(assetTag: input)
                    if result.found, let device = result.device {
                        lookupResult = device
                    } else {
                        notFound = true
                    }
                }
            } catch {
                notFound = true
            }
            isLoading = false
        }
    }
}
