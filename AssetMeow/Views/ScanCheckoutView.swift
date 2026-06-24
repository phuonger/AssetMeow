import SwiftUI

struct ScanCheckoutView: View {
    @EnvironmentObject var appState: AppState
    
    enum Step {
        case scan
        case review
        case assign
        case complete
    }
    
    @State private var step: Step = .scan
    @State private var scanText = ""
    @State private var scannedTags: [String] = []
    
    // Validation results
    @State private var foundDevices: [ValidatedDevice] = []
    @State private var notFoundTags: [String] = []
    
    // New device creation
    @State private var newDeviceEntries: [NewDeviceEntry] = []
    
    // Assignment
    @State private var selectedLocation: Location?
    @State private var selectedPerson: Person?
    @State private var showNewLocation = false
    @State private var showNewPerson = false
    @State private var newLocationName = ""
    @State private var newPersonName = ""
    @State private var newPersonRole = ""
    @State private var checkoutNotes = ""
    
    // Status
    @State private var isProcessing = false
    @State private var resultMessage = ""
    @State private var showResult = false
    
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
                        Text("Scan & Checkout")
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
                        stepBadge(2, "Review", active: step == .review)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        stepBadge(3, "Assign", active: step == .assign)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        stepBadge(4, "Done", active: step == .complete)
                    }
                }
                .padding(20)
                
                // Content
                switch step {
                case .scan:
                    scanStepView
                case .review:
                    reviewStepView
                case .assign:
                    assignStepView
                case .complete:
                    completeStepView
                }
            }
        }
    }
    
    var stepDescription: String {
        switch step {
        case .scan: return "Scan barcodes with your Zebra scanner or type asset tags"
        case .review: return "Review scanned devices before assignment"
        case .assign: return "Choose location and person for checkout"
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
                    .fill(AppTheme.primaryPurple.opacity(0.15))
                    .frame(width: 80, height: 80)
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(AppTheme.primaryGradient)
            }
            
            VStack(spacing: 6) {
                Text("Scan Barcodes to Check Out")
                    .font(AppTheme.headingFont)
                    .foregroundColor(AppTheme.textPrimary)
                Text("Scan with your Zebra scanner (TAB-separated) or paste asset tags, one per line.")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
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
                    .frame(minHeight: 180, maxHeight: 300)
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
            
            Text("Each barcode scan adds a new line (TAB = new line). You can also paste or type asset tags.")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
            
            Spacer()
            
            // Bottom buttons
            HStack {
                Button(action: parseInput) {
                    Text("Parse Input")
                        .secondaryButton()
                }
                .buttonStyle(.plain)
                .disabled(scanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                
                Spacer()
                
                if !scannedTags.isEmpty {
                    Text("\(scannedTags.count) tags parsed")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentCyan)
                }
                
                Button(action: submitScans) {
                    Text("Submit")
                        .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(scanText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && scannedTags.isEmpty)
                .keyboardShortcut(.return, modifiers: [])
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 2: Review
    var reviewStepView: some View {
        VStack(spacing: 12) {
            if isProcessing {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                Text("Validating devices...")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textSecondary)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Found devices
                        if !foundDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.statusAvailable)
                                    Text("\(foundDevices.count) devices found in system")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                
                                VStack(spacing: 2) {
                                    ForEach(foundDevices, id: \.assetTag) { device in
                                        HStack {
                                            CopyableAssetTag(assetTag: device.assetTag)
                                                .frame(width: 140, alignment: .leading)
                                            CopyableText(text: device.category ?? "—")
                                                .frame(width: 80, alignment: .leading)
                                            CopyableText(text: device.model ?? "—")
                                                .frame(width: 100, alignment: .leading)
                                            Text(device.status ?? "—")
                                                .font(AppTheme.captionFont)
                                                .foregroundColor(AppTheme.statusColor(for: device.status ?? ""))
                                            Spacer()
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.statusAvailable.opacity(0.05))
                                        .cornerRadius(6)
                                    }
                                }
                            }
                            .cardStyle()
                        }
                        
                        // Not found devices
                        if !notFoundTags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.statusCheckedOut)
                                    Text("\(notFoundTags.count) devices NOT in system")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                    Text("Fill in details to create them")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                
                                VStack(spacing: 4) {
                                    ForEach($newDeviceEntries, id: \.assetTag) { $entry in
                                        HStack(spacing: 8) {
                                            CopyableAssetTag(assetTag: entry.assetTag)
                                                .frame(width: 130, alignment: .leading)
                                            TextField("Category", text: $entry.category)
                                                .darkTextField()
                                                .frame(width: 100)
                                            TextField("Model", text: $entry.model)
                                                .darkTextField()
                                                .frame(width: 120)
                                            TextField("SKU", text: $entry.sku)
                                                .darkTextField()
                                                .frame(width: 120)
                                            Button(action: {
                                                newDeviceEntries.removeAll { $0.assetTag == entry.assetTag }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(AppTheme.statusMissing.opacity(0.7))
                                            }
                                            .buttonStyle(.plain)
                                            Spacer()
                                        }
                                    }
                                }
                                
                                // Quick fill
                                HStack(spacing: 12) {
                                    Text("Quick fill:")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                    QuickFillField(label: "Category", entries: $newDeviceEntries, keyPath: \.category)
                                    QuickFillField(label: "Model", entries: $newDeviceEntries, keyPath: \.model)
                                    QuickFillField(label: "SKU", entries: $newDeviceEntries, keyPath: \.sku)
                                }
                            }
                            .cardStyle()
                        }
                    }
                    .padding(20)
                }
                
                // Bottom buttons
                HStack {
                    Button(action: resetAll) {
                        Text("Cancel")
                            .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if !notFoundTags.isEmpty && !newDeviceEntries.isEmpty {
                        Button(action: {
                            newDeviceEntries = []
                            scannedTags = foundDevices.map { $0.assetTag }
                            if scannedTags.isEmpty {
                                resultMessage = "No existing devices to check out."
                                showResult = true
                            } else {
                                step = .assign
                            }
                        }) {
                            Text("Skip Unknown")
                                .secondaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button(action: {
                        if !newDeviceEntries.isEmpty {
                            createNewDevicesAndProceed()
                        } else {
                            scannedTags = foundDevices.map { $0.assetTag }
                            step = .assign
                        }
                    }) {
                        Text("Continue to Assignment")
                            .primaryButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(foundDevices.isEmpty && newDeviceEntries.isEmpty)
                }
                .padding(20)
            }
        }
    }
    
    // MARK: - Step 3: Assign
    var assignStepView: some View {
        VStack(spacing: 20) {
            // Assignment form
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Assigning \(scannedTags.count) devices")
                        .font(AppTheme.headingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Choose where these devices are going")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Location (destination = current location during checkout)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Destination (Current Location)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    HStack {
                        Picker("", selection: $selectedLocation) {
                            Text("-- Select --").tag(nil as Location?)
                            ForEach(appState.locations, id: \.id) { loc in
                                Text(loc.name).tag(Optional(loc))
                            }
                        }
                        .frame(width: 220)
                        
                        Button(action: { showNewLocation.toggle(); showNewPerson = false }) {
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
                                        // Find the location from the updated array to ensure picker tag match
                                        if let matchedLoc = appState.locations.first(where: { $0.id == loc.id }) {
                                            selectedLocation = matchedLoc
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
                            .disabled(newLocationName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                
                // Person
                VStack(alignment: .leading, spacing: 6) {
                    Text("Assigned To")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    HStack {
                        Picker("", selection: $selectedPerson) {
                            Text("-- None --").tag(nil as Person?)
                            ForEach(appState.people, id: \.id) { person in
                                Text(person.name).tag(Optional(person))
                            }
                        }
                        .frame(width: 220)
                        
                        Button(action: { showNewPerson.toggle(); showNewLocation = false }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("New")
                            }
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if showNewPerson {
                        HStack(spacing: 8) {
                            TextField("Person name", text: $newPersonName)
                                .darkTextField()
                                .frame(width: 140)
                            TextField("Role (optional)", text: $newPersonRole)
                                .darkTextField()
                                .frame(width: 120)
                            Button(action: {
                                Task {
                                    let role = newPersonRole.isEmpty ? nil : newPersonRole
                                    if let person = await appState.createPerson(name: newPersonName, role: role) {
                                        // Find the person from the updated people array to ensure picker tag match
                                        if let matchedPerson = appState.people.first(where: { $0.id == person.id }) {
                                            selectedPerson = matchedPerson
                                        } else {
                                            selectedPerson = person
                                        }
                                        newPersonName = ""
                                        newPersonRole = ""
                                        showNewPerson = false
                                    }
                                }
                            }) {
                                Text("Create")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.primaryPurpleLight)
                            }
                            .buttonStyle(.plain)
                            .disabled(newPersonName.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
                
                // Notes
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Optional checkout notes", text: $checkoutNotes)
                        .darkTextField()
                        .frame(width: 350)
                }
            }
            .glowCardStyle()
            .padding(.horizontal, 40)
            .padding(.top, 20)
            
            Spacer()
            
            // Summary
            if selectedLocation == nil && selectedPerson == nil {
                Text("Please select at least a location or person")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.statusMissing)
            }
            
            // Bottom buttons
            HStack {
                Button(action: { step = .review }) {
                    Text("Back")
                        .secondaryButton()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: performCheckout) {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        }
                        Text("Complete Checkout")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || (selectedLocation == nil && selectedPerson == nil))
            }
            .padding(20)
        }
    }
    
    // MARK: - Step 4: Complete (Session Summary)
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
                        
                        Text("Checkout Complete")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(.top, 20)
                    
                    if let log = sessionLog {
                        // Summary stats
                        HStack(spacing: 20) {
                            statCard("Total Scanned", "\(log.entries.count)", AppTheme.primaryPurple)
                            statCard("Successful", "\(log.successCount)", AppTheme.statusAvailable)
                            statCard("Not Found", "\(log.notFoundCount)", AppTheme.statusMissing)
                        }
                        .padding(.horizontal, 40)
                        
                        // Session details
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Session Details")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            if let loc = log.location {
                                detailRow("Location", loc)
                            }
                            if let person = log.person {
                                detailRow("Assigned To", person)
                            }
                            if let event = log.event {
                                detailRow("Event", event)
                            }
                            if let notes = log.notes, !notes.isEmpty {
                                detailRow("Notes", notes)
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
                                            sessionType: "Check Out",
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
                                    Text("\(log.successEntries.count) Devices Checked Out")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                
                                VStack(spacing: 2) {
                                    ForEach(log.successEntries) { entry in
                                        HStack {
                                            CopyableAssetTag(assetTag: entry.assetTag)
                                            Spacer()
                                            CopyableText(text: entry.category ?? "")
                                            CopyableText(text: entry.model ?? "")
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
                
                Button(action: resetAll) {
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
                .frame(width: 100, alignment: .trailing)
            CopyableText(text: value, font: AppTheme.bodyFont, color: AppTheme.textPrimary)
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    func parseInput() {
        let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: "\t"))
        let tags = scanText.components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        for tag in tags {
            if !scannedTags.contains(tag) {
                scannedTags.append(tag)
            }
        }
        scanText = ""
        scanFieldFocused = true
    }
    
    func submitScans() {
        parseInput()
        guard !scannedTags.isEmpty else { return }
        
        sessionStartTime = Date()
        isProcessing = true
        step = .review
        
        Task {
            do {
                let response = try await APIService.shared.validateDevices(assetTags: scannedTags)
                foundDevices = response.found ?? []
                notFoundTags = response.notFound ?? []
                
                newDeviceEntries = notFoundTags.map { tag in
                    NewDeviceEntry(assetTag: tag, category: "", model: "", sku: "")
                }
                
                if notFoundTags.isEmpty && !foundDevices.isEmpty {
                    scannedTags = foundDevices.map { $0.assetTag }
                    step = .assign
                }
            } catch {
                resultMessage = "Error validating devices: \(error.localizedDescription)"
                showResult = true
                step = .scan
            }
            isProcessing = false
        }
    }
    
    func createNewDevicesAndProceed() {
        isProcessing = true
        Task {
            do {
                let devicesToCreate = newDeviceEntries.map { entry -> [String: Any] in
                    var dict: [String: Any] = ["asset_tag": entry.assetTag]
                    if !entry.category.isEmpty { dict["category"] = entry.category }
                    if !entry.model.isEmpty { dict["model"] = entry.model }
                    if !entry.sku.isEmpty { dict["sku"] = entry.sku }
                    return dict
                }
                
                let result = try await APIService.shared.bulkCreate(devices: devicesToCreate, eventId: appState.currentEvent?.id)
                
                if result.success == true {
                    let createdTags = newDeviceEntries.map { $0.assetTag }
                    scannedTags = foundDevices.map { $0.assetTag } + createdTags
                    ToastManager.shared.success("Devices Created", detail: "\(createdTags.count) device(s) written to database.")
                    newDeviceEntries = []
                    step = .assign
                } else {
                    let errorMsg = result.error ?? "Unknown"
                    resultMessage = "Error creating devices: \(errorMsg)"
                    showResult = true
                    ToastManager.shared.error("Failed to Create Devices", detail: errorMsg)
                }
            } catch {
                resultMessage = "Error creating devices: \(error.localizedDescription)"
                showResult = true
                ToastManager.shared.error("Connection Error", detail: "Could not create devices: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    func performCheckout() {
        isProcessing = true
        Task {
            do {
                let result = try await APIService.shared.bulkCheckout(
                    assetTags: scannedTags,
                    locationId: selectedLocation?.id,
                    personId: selectedPerson?.id,
                    eventId: appState.currentEvent?.id,
                    notes: checkoutNotes
                )
                
                let now = Date()
                var entries: [ScanSessionEntry] = []
                
                // Build session log entries
                if result.success == true {
                    let notFoundResult = result.results?.notFound ?? []
                    
                    for tag in scannedTags {
                        let device = foundDevices.first { $0.assetTag == tag }
                        let wasNotFound = notFoundResult.contains(tag)
                        
                        entries.append(ScanSessionEntry(
                            assetTag: tag,
                            status: wasNotFound ? .notFound : .success,
                            category: device?.category,
                            model: device?.model,
                            location: selectedLocation?.name,
                            assignedTo: selectedPerson?.name,
                            notes: wasNotFound ? "Device not found in system" : nil,
                            timestamp: now
                        ))
                    }
                    
                    // Add any not-found tags from the original scan that were skipped
                    for tag in notFoundTags {
                        if !scannedTags.contains(tag) {
                            entries.append(ScanSessionEntry(
                                assetTag: tag,
                                status: .notFound,
                                category: nil,
                                model: nil,
                                location: nil,
                                assignedTo: nil,
                                notes: "Skipped - not in system",
                                timestamp: now
                            ))
                        }
                    }
                } else {
                    // Error case
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
                    sessionType: .checkout,
                    startTime: sessionStartTime,
                    endTime: now,
                    entries: entries,
                    location: selectedLocation?.name,
                    person: selectedPerson?.name,
                    event: appState.currentEvent?.name,
                    performedBy: appState.currentUser?.displayName ?? appState.currentUser?.username,
                    notes: checkoutNotes
                )
                
                // Confirm write to database
                if result.success == true {
                    let checkedOut = result.results?.checkedOut ?? scannedTags.count
                    ToastManager.shared.success("Checkout Saved", detail: "\(checkedOut) device(s) checked out and written to database.")
                } else {
                    ToastManager.shared.error("Checkout Failed", detail: result.error ?? "Database write was not confirmed.")
                }
                
                step = .complete
                
            } catch {
                resultMessage = "Error: \(error.localizedDescription)"
                showResult = true
                ToastManager.shared.error("Connection Error", detail: "Could not complete checkout: \(error.localizedDescription)")
            }
            isProcessing = false
        }
    }
    
    func resetAll() {
        step = .scan
        scanText = ""
        scannedTags = []
        foundDevices = []
        notFoundTags = []
        newDeviceEntries = []
        selectedLocation = nil
        selectedPerson = nil
        showNewLocation = false
        showNewPerson = false
        newLocationName = ""
        newPersonName = ""
        newPersonRole = ""
        checkoutNotes = ""
        sessionLog = nil
        scanFieldFocused = true
    }
}

// MARK: - New Device Entry
struct NewDeviceEntry: Identifiable, Hashable {
    var id: String { assetTag }
    var assetTag: String
    var category: String
    var model: String
    var sku: String
}

// MARK: - Quick Fill Field Helper
struct QuickFillField: View {
    let label: String
    @Binding var entries: [NewDeviceEntry]
    let keyPath: WritableKeyPath<NewDeviceEntry, String>
    
    @State private var text = ""
    
    var body: some View {
        HStack(spacing: 4) {
            TextField(label, text: $text)
                .darkTextField()
                .frame(width: 90)
            Button("Set") {
                for i in entries.indices {
                    if entries[i][keyPath: keyPath].isEmpty {
                        entries[i][keyPath: keyPath] = text
                    }
                }
            }
            .font(AppTheme.captionFont)
            .foregroundColor(AppTheme.primaryPurpleLight)
            .buttonStyle(.plain)
            .disabled(text.isEmpty)
        }
    }
}
