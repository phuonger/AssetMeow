import SwiftUI

struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    
    enum Step {
        case scan
        case preview
        case complete
    }
    
    @State private var step: Step = .scan
    @State private var scanText = ""
    @State private var scannedTags: [String] = []
    @State private var notes = ""
    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var isProcessing = false
    @State private var isFetchingDevices = false
    
    // Preview data
    @State private var previewDevices: [CheckInPreviewItem] = []
    @State private var notFoundTags: [String] = []
    
    // Override all
    @State private var showOverrideAll = false
    @State private var overrideAllLocation: Location?
    @State private var newOverrideLocationName = ""
    @State private var showNewOverrideLocation = false
    
    // Session log
    @State private var sessionLog: ScanSessionLog?
    @State private var sessionStartTime = Date()
    
    @FocusState private var scanFieldFocused: Bool
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Check In")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(stepDescription)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    // Step indicator
                    HStack(spacing: 8) {
                        stepBadge(1, "Scan", active: step == .scan)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        stepBadge(2, "Preview", active: step == .preview)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        stepBadge(3, "Done", active: step == .complete)
                    }
                }
                .padding(20)
                
                switch step {
                case .scan:
                    scanStepView
                case .preview:
                    previewStepView
                case .complete:
                    completeStepView
                }
            }
        }
    }
    
    var stepDescription: String {
        switch step {
        case .scan: return "Scan devices being returned"
        case .preview: return "Review devices and confirm assigned locations"
        case .complete: return "Session complete — review results and download log"
        }
    }
    
    func stepBadge(_ number: Int, _ label: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Text("\(number)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(active ? .white : AppTheme.textMuted)
                .frame(width: 18, height: 18)
                .background(active ? AppTheme.primaryPurple : AppTheme.surfaceDefault)
                .clipShape(Circle())
            Text(label)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .foregroundColor(active ? AppTheme.textPrimary : AppTheme.textMuted)
        }
    }
    
    // MARK: - Step 1: Scan
    var scanStepView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.statusAvailable.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "arrow.down.to.line")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(AppTheme.statusAvailable)
            }
            
            VStack(spacing: 6) {
                Text("Scan Barcodes to Check In")
                    .font(AppTheme.headingFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Scan devices being returned. Press Enter when done.")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
            }
            
            // Scan area
            VStack(alignment: .leading, spacing: 8) {
                Text("Scan Area")
                    .font(AppTheme.subheadingFont)
                    .foregroundColor(AppTheme.textPrimary)
                
                TextEditor(text: $scanText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150, maxHeight: 250)
                    .padding(12)
                    .background(AppTheme.backgroundDark)
                    .cornerRadius(AppTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                    )
                    .focused($scanFieldFocused)
            }
            .padding(.horizontal, 40)
            
            // Scanned tags list
            if !scannedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(scannedTags.count) items scanned")
                            .font(AppTheme.subheadingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button(action: { scannedTags.removeAll(); scanText = "" }) {
                            Text("Clear All")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.statusMissing)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(scannedTags.enumerated()), id: \.offset) { index, tag in
                                HStack {
                                    Text("\(index + 1).")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                        .frame(width: 30, alignment: .trailing)
                                    CopyableAssetTag(assetTag: tag)
                                    Spacer()
                                    Button(action: { scannedTags.remove(at: index) }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(AppTheme.statusMissing.opacity(0.7))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 120)
                    .padding(10)
                    .background(AppTheme.backgroundDark)
                    .cornerRadius(AppTheme.cornerRadius)
                }
                .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Bottom buttons
            HStack {
                Button(action: processScannedInput) {
                    Text("Parse Input")
                        .secondaryButton()
                }
                .buttonStyle(.plain)
                .disabled(scanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
                
                Button(action: {
                    if scannedTags.isEmpty { processScannedInput() }
                    if !scannedTags.isEmpty {
                        sessionStartTime = Date()
                        fetchDevicesForPreview()
                    }
                }) {
                    HStack(spacing: 6) {
                        if isFetchingDevices {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        }
                        Text("Submit\(scannedTags.count > 0 ? " (\(scannedTags.count) items)" : "")")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled((scanText.isEmpty && scannedTags.isEmpty) || isFetchingDevices)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 2: Preview / Confirmation
    var previewStepView: some View {
        VStack(spacing: 0) {
            // Header info
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Review Check-In")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Devices will be checked in to their Assigned Location. Override if needed.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    // Override All button
                    Button(action: { showOverrideAll.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Override All")
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentOrange)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentOrange.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                // Override All panel
                if showOverrideAll {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set Assigned Location for ALL devices:")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        HStack(spacing: 8) {
                            Picker("", selection: $overrideAllLocation) {
                                Text("-- Select --").tag(nil as Location?)
                                ForEach(appState.locations, id: \.id) { loc in
                                    Text(loc.name).tag(Optional(loc))
                                }
                            }
                            .frame(width: 220)
                            
                            Button(action: { showNewOverrideLocation.toggle() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                    Text("New")
                                }
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.primaryPurpleLight)
                            }
                            .buttonStyle(.plain)
                            
                            Button(action: applyOverrideAll) {
                                Text("Apply to All")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(AppTheme.accentOrange)
                                    .cornerRadius(5)
                            }
                            .buttonStyle(.plain)
                            .disabled(overrideAllLocation == nil)
                        }
                        
                        if showNewOverrideLocation {
                            HStack(spacing: 8) {
                                TextField("New location name", text: $newOverrideLocationName)
                                    .darkTextField()
                                    .frame(width: 200)
                                Button(action: {
                                    Task {
                                        if let loc = await appState.createLocation(name: newOverrideLocationName) {
                                            if let matched = appState.locations.first(where: { $0.id == loc.id }) {
                                                overrideAllLocation = matched
                                            } else {
                                                overrideAllLocation = loc
                                            }
                                            newOverrideLocationName = ""
                                            showNewOverrideLocation = false
                                        }
                                    }
                                }) {
                                    Text("Create")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.primaryPurpleLight)
                                }
                                .buttonStyle(.plain)
                                .disabled(newOverrideLocationName.isEmpty)
                            }
                        }
                    }
                    .padding(12)
                    .background(AppTheme.accentOrange.opacity(0.05))
                    .cornerRadius(AppTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.accentOrange.opacity(0.2), lineWidth: 1)
                    )
                }
                
                // Notes
                HStack(spacing: 8) {
                    Text("Notes:")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Optional check-in notes...", text: $notes)
                        .darkTextField()
                        .frame(width: 300)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            
            // Not found warning
            if !notFoundTags.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.statusMissing)
                    Text("\(notFoundTags.count) device(s) not found in inventory:")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.statusMissing)
                    Text(notFoundTags.joined(separator: ", "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(AppTheme.statusMissing.opacity(0.08))
            }
            
            // Table header
            HStack(spacing: 0) {
                Text("Asset Tag")
                    .frame(width: 140, alignment: .leading)
                Text("Category / Model")
                    .frame(width: 180, alignment: .leading)
                Text("Current Location")
                    .frame(width: 160, alignment: .leading)
                Text("Assigned Location (Check-In To)")
                    .frame(minWidth: 200, alignment: .leading)
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textMuted)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundDark.opacity(0.5))
            
            // Device list
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach($previewDevices) { $item in
                        CheckInPreviewRow(item: $item, locations: appState.locations, appState: appState)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            
            // Summary bar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(previewDevices.count) device(s) ready for check-in")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    if !notFoundTags.isEmpty {
                        Text("\(notFoundTags.count) not found (will be skipped)")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.statusMissing)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppTheme.surfaceDefault.opacity(0.3))
            
            // Bottom buttons
            HStack {
                Button(action: {
                    step = .scan
                    previewDevices.removeAll()
                    notFoundTags.removeAll()
                }) {
                    Text("Back")
                        .secondaryButton()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: performCheckin) {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        }
                        Text("Confirm Check-In (\(previewDevices.count) Devices)")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || previewDevices.isEmpty)
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 3: Complete (Session Summary)
    var completeStepView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // Success header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.statusAvailable.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(AppTheme.statusAvailable)
                        }
                        
                        Text("Check-In Complete")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, 20)
                    
                    if let log = sessionLog {
                        // Summary stats
                        HStack(spacing: 20) {
                            statCard("Total Scanned", "\(log.entries.count)", AppTheme.primaryPurple)
                            statCard("Checked In", "\(log.successCount)", AppTheme.statusAvailable)
                            statCard("Not Found", "\(log.notFoundCount)", AppTheme.statusMissing)
                        }
                        .padding(.horizontal, 40)
                        
                        // Session details
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Session Details")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            if let event = log.event {
                                detailRow("Event", event)
                            }
                            if let logNotes = log.notes, !logNotes.isEmpty {
                                detailRow("Notes", logNotes)
                            }
                            detailRow("Performed By", log.performedBy ?? "Unknown")
                            
                            let dateFormatter = DateFormatter()
                            let _ = dateFormatter.dateFormat = "MMM d, yyyy h:mm a"
                            detailRow("Time", dateFormatter.string(from: log.startTime))
                        }
                        .glowCardStyle()
                        .padding(.horizontal, 40)
                        
                        // Not found list
                        if !log.notFoundEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.statusMissing)
                                    Text("\(log.notFoundEntries.count) Devices Not Found")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Button(action: {
                                        CSVExporter.exportNotFoundLog(
                                            log.notFoundEntries.map { $0.assetTag },
                                            sessionType: "Check In",
                                            location: nil,
                                            event: log.event
                                        )
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "arrow.down.doc")
                                            Text("Export Not Found")
                                        }
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.accentOrange)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                VStack(spacing: 2) {
                                    ForEach(log.notFoundEntries) { entry in
                                        HStack {
                                            CopyableAssetTag(assetTag: entry.assetTag)
                                            Spacer()
                                            Text("Not Found")
                                                .font(AppTheme.captionFont)
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.statusMissing.opacity(0.05))
                                        .cornerRadius(4)
                                    }
                                }
                            }
                            .cardStyle()
                            .padding(.horizontal, 40)
                        }
                        
                        // Successful list
                        if !log.successEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.statusAvailable)
                                    Text("\(log.successEntries.count) Devices Checked In")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                
                                VStack(spacing: 2) {
                                    ForEach(log.successEntries) { entry in
                                        HStack {
                                            CopyableAssetTag(assetTag: entry.assetTag)
                                            Spacer()
                                            if let loc = entry.location {
                                                Text("→ \(loc)")
                                                    .font(AppTheme.captionFont)
                                                    .foregroundColor(AppTheme.textSecondary)
                                            }
                                            Text("Checked In")
                                                .font(AppTheme.captionFont)
                                                .foregroundColor(AppTheme.statusAvailable)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.statusAvailable.opacity(0.05))
                                        .cornerRadius(4)
                                    }
                                }
                            }
                            .cardStyle()
                            .padding(.horizontal, 40)
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            
            // Bottom action buttons
            HStack(spacing: 12) {
                Button(action: {
                    if let log = sessionLog {
                        CSVExporter.exportSessionLog(log)
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("Download Session Log")
                    }
                    .secondaryButton()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: resetForm) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("New Scan Session")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
    }
    
    // MARK: - Helper Views
    func statCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(title)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.08))
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 120, alignment: .trailing)
            CopyableText(text: value, font: AppTheme.bodyFont, color: AppTheme.textPrimary)
            Spacer()
        }
    }
    
    // MARK: - Actions
    func processScannedInput() {
        let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: "\t"))
        let tags = scanText.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        for tag in tags {
            if !scannedTags.contains(tag) { scannedTags.append(tag) }
        }
        scanText = ""
        scanFieldFocused = true
    }
    
    func fetchDevicesForPreview() {
        isFetchingDevices = true
        Task {
            do {
                // Fetch device details for all scanned tags
                let tagsString = scannedTags.joined(separator: ",")
                let response = try await APIService.shared.searchDevices(tags: tagsString)
                
                var foundDevices: [CheckInPreviewItem] = []
                var notFound: [String] = []
                
                let devicesByTag = Dictionary(grouping: response.devices ?? [], by: { $0.assetTag })
                
                for tag in scannedTags {
                    if let device = devicesByTag[tag]?.first {
                        // Find the matching Location object for assigned location
                        let assignedLoc: Location? = {
                            if let alId = device.assignedLocationId {
                                return appState.locations.first(where: { $0.id == alId })
                            }
                            return nil
                        }()
                        
                        foundDevices.append(CheckInPreviewItem(
                            assetTag: device.assetTag,
                            category: device.category,
                            model: device.model,
                            currentLocationName: device.locationName ?? "Unknown",
                            assignedLocation: assignedLoc,
                            assignedLocationName: device.assignedLocationName ?? "Not Set",
                            deviceId: device.id
                        ))
                    } else {
                        notFound.append(tag)
                    }
                }
                
                previewDevices = foundDevices
                notFoundTags = notFound
                step = .preview
                
            } catch {
                ToastManager.shared.error("Fetch Failed", detail: "Could not retrieve device details: \(error.localizedDescription)")
            }
            isFetchingDevices = false
        }
    }
    
    func applyOverrideAll() {
        guard let location = overrideAllLocation else { return }
        for i in previewDevices.indices {
            previewDevices[i].assignedLocation = location
            previewDevices[i].assignedLocationName = location.name
        }
        showOverrideAll = false
        ToastManager.shared.info("Override Applied", detail: "All devices set to \(location.name)")
    }
    
    func performCheckin() {
        isProcessing = true
        Task {
            do {
                // Group devices by their target assigned location
                var groups: [Int?: [CheckInPreviewItem]] = [:]
                for item in previewDevices {
                    let locId = item.assignedLocation?.id
                    groups[locId, default: []].append(item)
                }
                
                var totalCheckedIn = 0
                var totalNotFound: [String] = []
                var allEntries: [ScanSessionEntry] = []
                let now = Date()
                
                for (assignedLocId, items) in groups {
                    let tags = items.map { $0.assetTag }
                    // For check-in: current location = assigned location (device goes home)
                    let result = try await APIService.shared.bulkCheckin(
                        assetTags: tags,
                        locationId: assignedLocId,
                        assignedLocationId: assignedLocId,
                        notes: notes
                    )
                    
                    if result.success == true {
                        let notFoundResult = result.results?.notFound ?? []
                        totalNotFound.append(contentsOf: notFoundResult)
                        
                        for item in items {
                            let wasNotFound = notFoundResult.contains(item.assetTag)
                            if !wasNotFound { totalCheckedIn += 1 }
                            allEntries.append(ScanSessionEntry(
                                assetTag: item.assetTag,
                                status: wasNotFound ? .notFound : .success,
                                category: item.category,
                                model: item.model,
                                location: item.assignedLocation?.name ?? item.assignedLocationName,
                                assignedTo: nil,
                                notes: wasNotFound ? "Device not found in system" : "Checked in to \(item.assignedLocation?.name ?? item.assignedLocationName)",
                                timestamp: now
                            ))
                        }
                    } else {
                        for item in items {
                            allEntries.append(ScanSessionEntry(
                                assetTag: item.assetTag,
                                status: .error,
                                category: item.category,
                                model: item.model,
                                location: nil,
                                assignedTo: nil,
                                notes: result.error ?? "Unknown error",
                                timestamp: now
                            ))
                        }
                    }
                }
                
                // Add not-found tags from the initial scan
                for tag in notFoundTags {
                    allEntries.append(ScanSessionEntry(
                        assetTag: tag,
                        status: .notFound,
                        category: nil,
                        model: nil,
                        location: nil,
                        assignedTo: nil,
                        notes: "Device not found in inventory",
                        timestamp: now
                    ))
                }
                
                sessionLog = ScanSessionLog(
                    sessionType: .checkin,
                    startTime: sessionStartTime,
                    endTime: now,
                    entries: allEntries,
                    location: nil,
                    person: nil,
                    event: appState.currentEvent?.name,
                    performedBy: appState.currentUser?.displayName ?? appState.currentUser?.username,
                    notes: notes.isEmpty ? nil : notes
                )
                
                // Toast confirmation
                if totalCheckedIn > 0 {
                    ToastManager.shared.success("Check-In Saved", detail: "\(totalCheckedIn) device(s) checked in and written to database.")
                } else if !totalNotFound.isEmpty {
                    ToastManager.shared.warning("Partial Check-In", detail: "\(totalNotFound.count) device(s) were not found.")
                } else {
                    ToastManager.shared.error("Check-In Failed", detail: "No devices were checked in.")
                }
                
                step = .complete
                
            } catch {
                resultMessage = "Error: \(error.localizedDescription)"
                showResult = true
                ToastManager.shared.error("Connection Error", detail: "Could not complete check-in: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    func resetForm() {
        step = .scan
        scannedTags.removeAll()
        scanText = ""
        notes = ""
        previewDevices.removeAll()
        notFoundTags.removeAll()
        showOverrideAll = false
        overrideAllLocation = nil
        newOverrideLocationName = ""
        showNewOverrideLocation = false
        sessionLog = nil
        scanFieldFocused = true
    }
}

// MARK: - Preview Item Model
struct CheckInPreviewItem: Identifiable {
    let id = UUID()
    var assetTag: String
    var category: String?
    var model: String?
    var currentLocationName: String  // Read-only: where device is now
    var assignedLocation: Location?  // Editable: where it will be checked in to
    var assignedLocationName: String // Display name (fallback if no Location object)
    var deviceId: Int?
}

// MARK: - Preview Row View
struct CheckInPreviewRow: View {
    @Binding var item: CheckInPreviewItem
    let locations: [Location]
    let appState: AppState
    
    @State private var showLocationPicker = false
    @State private var newLocationName = ""
    @State private var showNewLocation = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Asset Tag
            CopyableAssetTag(assetTag: item.assetTag)
                .frame(width: 140, alignment: .leading)
            
            // Category / Model
            VStack(alignment: .leading, spacing: 1) {
                if let category = item.category {
                    Text(category)
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.textSecondary)
                }
                if let model = item.model {
                    Text(model)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .lineLimit(1)
                }
            }
            .frame(width: 180, alignment: .leading)
            
            // Current Location (read-only)
            Text(item.currentLocationName)
                .font(.system(size: 11))
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 160, alignment: .leading)
            
            // Assigned Location (editable)
            HStack(spacing: 6) {
                if showLocationPicker {
                    Picker("", selection: Binding(
                        get: { item.assignedLocation },
                        set: { newLoc in
                            item.assignedLocation = newLoc
                            item.assignedLocationName = newLoc?.name ?? item.assignedLocationName
                            showLocationPicker = false
                        }
                    )) {
                        Text("-- Select --").tag(nil as Location?)
                        ForEach(locations, id: \.id) { loc in
                            Text(loc.name).tag(Optional(loc))
                        }
                    }
                    .frame(width: 160)
                    
                    Button(action: { showNewLocation.toggle() }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { showLocationPicker = false }) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(item.assignedLocation?.name ?? item.assignedLocationName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(AppTheme.statusAvailable)
                    
                    Button(action: { showLocationPicker = true }) {
                        Image(systemName: "pencil.circle")
                            .font(.system(size: 12))
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                    .help("Change assigned location for this device")
                }
                
                Spacer()
            }
            .frame(minWidth: 200, alignment: .leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(AppTheme.surfaceDefault.opacity(0.3))
        .cornerRadius(4)
        .overlay(
            Group {
                if showNewLocation {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            TextField("New location", text: $newLocationName)
                                .darkTextField()
                                .frame(width: 160)
                            Button(action: {
                                Task {
                                    if let loc = await appState.createLocation(name: newLocationName) {
                                        let matched = appState.locations.first(where: { $0.id == loc.id }) ?? loc
                                        item.assignedLocation = matched
                                        item.assignedLocationName = matched.name
                                        newLocationName = ""
                                        showNewLocation = false
                                        showLocationPicker = false
                                    }
                                }
                            }) {
                                Text("Create")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.primaryPurpleLight)
                            }
                            .buttonStyle(.plain)
                            .disabled(newLocationName.isEmpty)
                            Button(action: { showNewLocation = false }) {
                                Text("Cancel")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(AppTheme.backgroundDark)
                        .cornerRadius(6)
                    }
                }
            }
        )
    }
}
