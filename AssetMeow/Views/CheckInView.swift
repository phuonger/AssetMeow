import SwiftUI

struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    
    enum Step {
        case scan
        case assign
        case complete
    }
    
    @State private var step: Step = .scan
    @State private var scanText = ""
    @State private var scannedTags: [String] = []
    @State private var selectedLocation: Location?
    @State private var selectedAssignedLocation: Location?
    @State private var notes = ""
    @State private var newLocationName = ""
    @State private var newAssignedLocationName = ""
    @State private var showNewAssignedLocation = false
    @State private var showNewLocation = false
    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var isProcessing = false
    
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
                        stepBadge(2, "Location", active: step == .assign)
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
                case .assign:
                    assignmentStepView
                case .complete:
                    completeStepView
                }
            }
        }
    }
    
    var stepDescription: String {
        switch step {
        case .scan: return "Scan devices being returned"
        case .assign: return "Select return location"
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
                        step = .assign
                    }
                }) {
                    Text("Submit\(scannedTags.count > 0 ? " (\(scannedTags.count) items)" : "")")
                        .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(scanText.isEmpty && scannedTags.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 2: Assignment
    var assignmentStepView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Checking in \(scannedTags.count) devices")
                        .font(AppTheme.headingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Select where these devices are being returned to")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Assigned Location (where device belongs)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assigned Location")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Where the device is assigned / stored (home location)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    HStack {
                        Picker("", selection: $selectedAssignedLocation) {
                            Text("-- Select --").tag(nil as Location?)
                            ForEach(appState.locations, id: \.id) { loc in
                                Text(loc.name).tag(Optional(loc))
                            }
                        }
                        .frame(width: 220)
                        .onChange(of: selectedAssignedLocation) { newVal in
                            // Default Current Location to match Assigned Location
                            if selectedLocation == nil {
                                selectedLocation = newVal
                            }
                        }
                        
                        Button(action: { showNewAssignedLocation.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("New")
                            }
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showNewAssignedLocation {
                        HStack(spacing: 8) {
                            TextField("New location name", text: $newAssignedLocationName)
                                .darkTextField()
                                .frame(width: 200)
                            Button(action: {
                                Task {
                                    if let loc = await appState.createLocation(name: newAssignedLocationName) {
                                        if let matched = appState.locations.first(where: { $0.id == loc.id }) {
                                            selectedAssignedLocation = matched
                                            if selectedLocation == nil { selectedLocation = matched }
                                        } else {
                                            selectedAssignedLocation = loc
                                            if selectedLocation == nil { selectedLocation = loc }
                                        }
                                        newAssignedLocationName = ""
                                        showNewAssignedLocation = false
                                    }
                                }
                            }) {
                                Text("Create")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.primaryPurpleLight)
                            }
                            .buttonStyle(.plain)
                            .disabled(newAssignedLocationName.isEmpty)
                        }
                    }
                }
                
                // Current Location (where device physically is now)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Current Location")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Text("Where the device physically is right now (usually same as Assigned)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    HStack {
                        Picker("", selection: $selectedLocation) {
                            Text("-- Select --").tag(nil as Location?)
                            ForEach(appState.locations, id: \.id) { loc in
                                Text(loc.name).tag(Optional(loc))
                            }
                        }
                        .frame(width: 220)
                        
                        Button(action: { showNewLocation.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("New")
                            }
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showNewLocation {
                        HStack(spacing: 8) {
                            TextField("New location name", text: $newLocationName)
                                .darkTextField()
                                .frame(width: 200)
                            Button(action: {
                                Task {
                                    if let loc = await appState.createLocation(name: newLocationName) {
                                        if let matched = appState.locations.first(where: { $0.id == loc.id }) {
                                            selectedLocation = matched
                                        } else {
                                            selectedLocation = loc
                                        }
                                        newLocationName = ""
                                        showNewLocation = false
                                    }
                                }
                            }) {
                                Text("Create")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.primaryPurpleLight)
                            }
                            .buttonStyle(.plain)
                            .disabled(newLocationName.isEmpty)
                        }
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes (optional)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Return notes...", text: $notes)
                        .darkTextField()
                        .frame(width: 350)
                }
            }
            .glowCardStyle()
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            
            // Bottom buttons
            HStack {
                Button(action: { step = .scan }) {
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
                        Text("Check In \(scannedTags.count) Devices")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
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
                            
                            if let loc = log.location {
                                detailRow("Return Location", loc)
                            }
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
                                            location: log.location,
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
    
    func performCheckin() {
        isProcessing = true
        Task {
            do {
                let result = try await APIService.shared.bulkCheckin(
                    assetTags: scannedTags,
                    locationId: selectedLocation?.id,
                    assignedLocationId: selectedAssignedLocation?.id,
                    notes: notes
                )
                
                let now = Date()
                var entries: [ScanSessionEntry] = []
                
                if result.success == true {
                    let notFoundResult = result.results?.notFound ?? []
                    
                    for tag in scannedTags {
                        let wasNotFound = notFoundResult.contains(tag)
                        entries.append(ScanSessionEntry(
                            assetTag: tag,
                            status: wasNotFound ? .notFound : .success,
                            category: nil,
                            model: nil,
                            location: selectedLocation?.name,
                            assignedTo: nil,
                            notes: wasNotFound ? "Device not found in system" : "Checked in",
                            timestamp: now
                        ))
                    }
                } else {
                    for tag in scannedTags {
                        entries.append(ScanSessionEntry(
                            assetTag: tag,
                            status: .error,
                            category: nil,
                            model: nil,
                            location: nil,
                            assignedTo: nil,
                            notes: result.error ?? "Unknown error",
                            timestamp: now
                        ))
                    }
                }
                
                sessionLog = ScanSessionLog(
                    sessionType: .checkin,
                    startTime: sessionStartTime,
                    endTime: now,
                    entries: entries,
                    location: selectedLocation?.name,
                    person: nil,
                    event: appState.currentEvent?.name,
                    performedBy: appState.currentUser?.displayName ?? appState.currentUser?.username,
                    notes: notes.isEmpty ? nil : notes
                )
                
                // Confirm write to database
                if result.success == true {
                    let checkedIn = result.results?.checkedIn ?? scannedTags.count
                    ToastManager.shared.success("Check-In Saved", detail: "\(checkedIn) device(s) checked in and written to database.")
                } else {
                    ToastManager.shared.error("Check-In Failed", detail: result.error ?? "Database write was not confirmed.")
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
        selectedLocation = nil
        selectedAssignedLocation = nil
        notes = ""
        showNewLocation = false
        showNewAssignedLocation = false
        newLocationName = ""
        newAssignedLocationName = ""
        sessionLog = nil
        scanFieldFocused = true
    }
}
