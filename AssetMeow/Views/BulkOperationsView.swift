import SwiftUI

import UniformTypeIdentifiers

struct BulkOperationsView: View {
    @EnvironmentObject var appState: AppState
    
    enum BulkMode: String, CaseIterable {
        case move = "Bulk Move"
        case update = "Bulk Update"
        case verify = "Scan & Verify"
    }
    
    @State private var selectedMode: BulkMode = .move
    @State private var assetTagsInput = ""
    @State private var parsedTags: [String] = []
    
    // Move options
    @State private var moveToAssignedLocation: Location?
    @State private var moveToCurrentLocation: Location?
    @State private var moveToPerson: Person?
    @State private var moveNotes = ""
    
    // Update options
    @State private var updateCategory = ""
    @State private var updateModel = ""
    @State private var updateSku = ""
    @State private var updateStatus: DeviceStatus?
    @State private var updateAssignedLocation: Location?
    @State private var updateCurrentLocation: Location?
    @State private var updateNotes = ""
    
    // Verify results
    @State private var verifyFoundTags: [String] = []
    @State private var verifyNotFoundTags: [String] = []
    
    // Results
    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var isProcessing = false
    
    // New location/person
    @State private var showNewAssignedLocation = false
    @State private var showNewCurrentLocation = false
    @State private var newLocationName = ""
    @State private var showNewPerson = false
    @State private var newPersonName = ""
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bulk Operations")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Perform actions on multiple devices at once")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Mode selector
                HStack(spacing: 2) {
                    ForEach(BulkMode.allCases, id: \.self) { mode in
                        Button(action: { selectedMode = mode }) {
                            Text(mode.rawValue)
                                .font(AppTheme.captionFont)
                                .foregroundColor(selectedMode == mode ? .white : AppTheme.textSecondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    selectedMode == mode
                                        ? AppTheme.primaryPurple
                                        : AppTheme.surfaceDefault
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                // Content
                HStack(alignment: .top, spacing: 20) {
                    // Left: Asset tags input
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Asset Tags")
                            .font(AppTheme.subheadingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Enter asset tags (one per line, comma-separated, or scan with Zebra)")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                        
                        TextEditor(text: $assetTagsInput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(AppTheme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 200)
                            .padding(10)
                            .background(AppTheme.backgroundDark)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                            )
                        
                        HStack {
                            Button(action: parseTags) {
                                Text("Parse")
                                    .secondaryButton()
                            }
                            .buttonStyle(.plain)
                            
                            if !parsedTags.isEmpty {
                                Text("\(parsedTags.count) tags parsed")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.statusAvailable)
                            }
                            Spacer()
                            Button(action: {
                                assetTagsInput = ""
                                parsedTags.removeAll()
                            }) {
                                Text("Clear")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.statusMissing)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Divider
                    Rectangle()
                        .fill(AppTheme.surfaceBorder)
                        .frame(width: 1)
                    
                    // Right: Options based on mode
                    VStack(alignment: .leading, spacing: 12) {
                        switch selectedMode {
                        case .move:
                            moveOptionsView
                        case .update:
                            updateOptionsView
                        case .verify:
                            verifyOptionsView
                        }
                        
                        Spacer()
                        
                        // Execute button
                        Button(action: executeOperation) {
                            HStack(spacing: 6) {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.7)
                                }
                                Text("Execute \(selectedMode.rawValue)")
                            }
                            .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(parsedTags.isEmpty && assetTagsInput.isEmpty || isProcessing)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .alert("Result", isPresented: $showResult) {
            Button("OK") {}
        } message: {
            Text(resultMessage)
        }
    }
    
    // MARK: - Move Options
    var moveOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move To")
                .font(AppTheme.subheadingFont)
                .foregroundColor(AppTheme.textPrimary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Assigned Location:")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                HStack {
                    Picker("", selection: $moveToAssignedLocation) {
                        Text("-- None --").tag(nil as Location?)
                        ForEach(appState.locations, id: \.id) { loc in
                            Text(loc.name).tag(Optional(loc))
                        }
                    }
                    .frame(width: 180)
                    Button(action: { showNewAssignedLocation.toggle() }) {
                        Text("+ New")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                }
                if showNewAssignedLocation {
                    HStack {
                        TextField("Name", text: $newLocationName)
                            .darkTextField()
                            .frame(width: 150)
                        Button("Create") {
                            Task {
                                if let loc = await appState.createLocation(name: newLocationName) {
                                    if let matched = appState.locations.first(where: { $0.id == loc.id }) {
                                        moveToAssignedLocation = matched
                                    } else {
                                        moveToAssignedLocation = loc
                                    }
                                    newLocationName = ""
                                    showNewAssignedLocation = false
                                }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryPurpleLight)
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Location:")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                HStack {
                    Picker("", selection: $moveToCurrentLocation) {
                        Text("-- None --").tag(nil as Location?)
                        ForEach(appState.locations, id: \.id) { loc in
                            Text(loc.name).tag(Optional(loc))
                        }
                    }
                    .frame(width: 180)
                    Button(action: { showNewCurrentLocation.toggle() }) {
                        Text("+ New")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                }
                if showNewCurrentLocation {
                    HStack {
                        TextField("Name", text: $newLocationName)
                            .darkTextField()
                            .frame(width: 150)
                        Button("Create") {
                            Task {
                                if let loc = await appState.createLocation(name: newLocationName) {
                                    if let matched = appState.locations.first(where: { $0.id == loc.id }) {
                                        moveToCurrentLocation = matched
                                    } else {
                                        moveToCurrentLocation = loc
                                    }
                                    newLocationName = ""
                                    showNewCurrentLocation = false
                                }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryPurpleLight)
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Person:")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                HStack {
                    Picker("", selection: $moveToPerson) {
                        Text("-- None --").tag(nil as Person?)
                        ForEach(appState.people, id: \.id) { p in
                            Text(p.name).tag(Optional(p))
                        }
                    }
                    .frame(width: 180)
                    Button(action: { showNewPerson.toggle() }) {
                        Text("+ New")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                }
                if showNewPerson {
                    HStack {
                        TextField("Name", text: $newPersonName)
                            .darkTextField()
                            .frame(width: 150)
                        Button("Create") {
                            Task {
                                if let p = await appState.createPerson(name: newPersonName) {
                                    // Find from updated array to ensure picker tag match
                                    if let matched = appState.people.first(where: { $0.id == p.id }) {
                                        moveToPerson = matched
                                    } else {
                                        moveToPerson = p
                                    }
                                    newPersonName = ""
                                    showNewPerson = false
                                }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.primaryPurpleLight)
                        .buttonStyle(.plain)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Notes:")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                TextField("Notes", text: $moveNotes)
                    .darkTextField()
            }
        }
    }
    
    // MARK: - Update Options
    var updateOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Update Fields")
                .font(AppTheme.subheadingFont)
                .foregroundColor(AppTheme.textPrimary)
            Text("Only filled fields will be updated")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
            
            TextField("Category", text: $updateCategory)
                .darkTextField()
            TextField("Model", text: $updateModel)
                .darkTextField()
            TextField("SKU / Style", text: $updateSku)
                .darkTextField()
            
            Picker("Status", selection: $updateStatus) {
                Text("-- Don't change --").tag(nil as DeviceStatus?)
                ForEach(DeviceStatus.allCases, id: \.self) { s in
                    Text(s.rawValue).tag(Optional(s))
                }
            }
            .frame(width: 200)
            
            Picker("Assigned Location", selection: $updateAssignedLocation) {
                Text("-- Don't change --").tag(nil as Location?)
                ForEach(appState.locations, id: \.id) { loc in
                    Text(loc.name).tag(Optional(loc))
                }
            }
            .frame(width: 200)
            
            Picker("Current Location", selection: $updateCurrentLocation) {
                Text("-- Don't change --").tag(nil as Location?)
                ForEach(appState.locations, id: \.id) { loc in
                    Text(loc.name).tag(Optional(loc))
                }
            }
            .frame(width: 200)
            
            TextField("Notes", text: $updateNotes)
                .darkTextField()
        }
    }
    
    // MARK: - Verify Options
    var verifyOptionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan & Verify")
                .font(AppTheme.subheadingFont)
                .foregroundColor(AppTheme.textPrimary)
            Text("Verify which asset tags exist in the system. Read-only — no changes are made.")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
            
            if !verifyFoundTags.isEmpty || !verifyNotFoundTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.statusAvailable)
                        Text("Found: \(verifyFoundTags.count)")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.statusAvailable)
                    }
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.statusMissing)
                        Text("Not Found: \(verifyNotFoundTags.count)")
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.statusMissing)
                    }
                    
                    Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
                    
                    Button(action: exportVerifyLog) {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Verification Log")
                        }
                        .secondaryButton()
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(AppTheme.backgroundDark)
                .cornerRadius(AppTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Results will appear here after verification.")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textMuted)
                        .italic()
                }
            }
        }
    }
    
    func exportVerifyLog() {
        var csv = "Asset Tag,Status\n"
        for tag in verifyFoundTags {
            csv += "\(tag),Found\n"
        }
        for tag in verifyNotFoundTags {
            csv += "\(tag),Not Found\n"
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "verification_log.csv"
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    // MARK: - Actions
    func parseTags() {
        let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: "\t,"))
        let tags = assetTagsInput.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        parsedTags = Array(Set(tags))
    }
    
    func executeOperation() {
        if parsedTags.isEmpty { parseTags() }
        guard !parsedTags.isEmpty else { return }
        
        isProcessing = true
        Task {
            do {
                switch selectedMode {
                case .move:
                    let result = try await APIService.shared.bulkMove(
                        assetTags: parsedTags,
                        toLocationId: moveToCurrentLocation?.id,
                        toAssignedLocationId: moveToAssignedLocation?.id,
                        toPersonId: moveToPerson?.id,
                        notes: moveNotes
                    )
                    let movedCount = result.results?.moved ?? 0
                    resultMessage = "Moved \(movedCount) devices."
                    if let nf = result.results?.notFound, !nf.isEmpty {
                        resultMessage += "\nNot found: \(nf.joined(separator: ", "))"
                    }
                    ToastManager.shared.success("Bulk Move Saved", detail: "\(movedCount) device(s) updated in database.")
                    
                case .update:
                    var updates: [String: Any] = [:]
                    if !updateCategory.isEmpty { updates["category"] = updateCategory }
                    if !updateModel.isEmpty { updates["model"] = updateModel }
                    if !updateSku.isEmpty { updates["sku"] = updateSku }
                    if let status = updateStatus { updates["status"] = status.rawValue }
                    if let loc = updateAssignedLocation { updates["assigned_location_id"] = loc.id }
                    if let loc = updateCurrentLocation { updates["location_id"] = loc.id }
                    if !updateNotes.isEmpty { updates["notes"] = updateNotes }
                    
                    let result = try await APIService.shared.bulkUpdate(assetTags: parsedTags, updates: updates)
                    let updatedCount = result.results?.moved ?? 0
                    resultMessage = "Updated \(updatedCount) devices."
                    ToastManager.shared.success("Bulk Update Saved", detail: "\(updatedCount) device(s) updated in database.")
                    
                case .verify:
                    let result = try await APIService.shared.scanVerify(
                        assetTags: parsedTags,
                        eventId: appState.currentEvent?.id,
                        locationId: nil
                    )
                    let details = result.results
                    verifyFoundTags = details?.tagsVerified ?? []
                    verifyNotFoundTags = details?.notFound ?? []
                    resultMessage = "Verified: \(verifyFoundTags.count) found, \(verifyNotFoundTags.count) not found"
                    ToastManager.shared.info("Verification Complete", detail: "\(verifyFoundTags.count) found, \(verifyNotFoundTags.count) not found.")
                }
            } catch {
                resultMessage = "Error: \(error.localizedDescription)"
                ToastManager.shared.error("Operation Failed", detail: error.localizedDescription)
            }
            isProcessing = false
            showResult = true
        }
    }
}
