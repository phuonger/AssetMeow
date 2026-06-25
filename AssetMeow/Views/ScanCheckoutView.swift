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
    @State private var perDeviceNotes: [String: String] = [:]  // assetTag -> note
    @State private var expandedNoteTag: String? = nil  // which device note is expanded
    
    // Status
    @State private var isProcessing = false
    @State private var resultMessage = ""
    @State private var showResult = false
    @State private var validationError = ""
    
    // Session log
    @State private var sessionLog: ScanSessionLog?
    @State private var sessionStartTime = Date()
    
    // Track skipped tags for session log
    @State private var skippedNotFoundTags: [String] = []
    
    // Confirmation dialog
    @State private var showConfirmBack = false
    
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
                Text("Scan or type an asset tag and press Enter to add it to the list.")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Single-line scan input
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.accentCyan)
                    
                    TextField("Scan or type asset tag...", text: $scanText)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                        .textFieldStyle(.plain)
                        .focused($scanFieldFocused)
                        .onSubmit {
                            addScannedTag()
                        }
                        .onChange(of: scanText) { newValue in
                            // Handle TAB-separated or newline-pasted input
                            let separators = CharacterSet.newlines.union(CharacterSet(charactersIn: "\t"))
                            if newValue.rangeOfCharacter(from: separators) != nil {
                                addScannedTag()
                            }
                        }
                    
                    if !scanText.isEmpty {
                        Button(action: { addScannedTag() }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.statusAvailable)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(AppTheme.backgroundDark)
                .cornerRadius(AppTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(scanFieldFocused ? AppTheme.accentCyan.opacity(0.5) : AppTheme.surfaceBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal, 40)
            
            // Confirmed tags list
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(scannedTags.count) items scanned")
                        .font(AppTheme.subheadingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    Spacer()
                    if !scannedTags.isEmpty {
                        Button(action: { scannedTags.removeAll() }) {
                            Text("Clear All")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.statusMissing)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if scannedTags.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 24))
                                .foregroundColor(AppTheme.textMuted.opacity(0.5))
                            Text("No items scanned yet")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(.vertical, 20)
                        Spacer()
                    }
                } else {
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
                    .frame(maxHeight: 180)
                }
            }
            .padding(10)
            .background(AppTheme.backgroundDark)
            .cornerRadius(AppTheme.cornerRadius)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Bottom buttons
            HStack {
                Spacer()
                
                Button(action: submitScans) {
                    HStack(spacing: 6) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.7)
                        }
                        Text("Submit\(scannedTags.count > 0 ? " (\(scannedTags.count) items)" : "")")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(scannedTags.isEmpty || isProcessing)
            }
            .padding(20)
        }
        .onAppear {
            scanFieldFocused = true
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
            } else if !validationError.isEmpty {
                // Show error with retry option
                Spacer()
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.statusMissing.opacity(0.15))
                            .frame(width: 60, height: 60)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(AppTheme.statusMissing)
                    }
                    Text("Validation Error")
                        .font(AppTheme.headingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    Text(validationError)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
                HStack {
                    Button(action: { backToScan() }) {
                        Text("Back to Scan")
                            .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(action: { validationError = ""; retryValidation() }) {
                        Text("Retry")
                            .primaryButton()
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
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
                                            CopyableText(text: device.category ?? "\u{2014}")
                                                .frame(width: 80, alignment: .leading)
                                            CopyableText(text: device.model ?? "\u{2014}")
                                                .frame(width: 100, alignment: .leading)
                                            CopyableText(text: device.sku ?? "\u{2014}")
                                                .frame(width: 90, alignment: .leading)
                                            Text(device.status ?? "\u{2014}")
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
                        
                        // Not found devices — warning section
                        if !notFoundTags.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.statusCheckedOut)
                                    Text("\(notFoundTags.count) tag(s) NOT found in system")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Spacer()
                                }
                                
                                Text("These tags don't match any device in inventory. You can remove them, create them as new devices, or skip them and continue with the valid devices only.")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .padding(.bottom, 4)
                                
                                VStack(spacing: 4) {
                                    ForEach(Array(notFoundTags.enumerated()), id: \.offset) { index, tag in
                                        HStack(spacing: 8) {
                                            CopyableAssetTag(assetTag: tag)
                                                .frame(width: 160, alignment: .leading)
                                            
                                            Text("Not Found")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundColor(AppTheme.statusMissing)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.statusMissing.opacity(0.1))
                                                .cornerRadius(4)
                                            
                                            Spacer()
                                            
                                            // Remove button
                                            Button(action: {
                                                notFoundTags.remove(at: index)
                                                newDeviceEntries.removeAll { $0.assetTag == tag }
                                            }) {
                                                HStack(spacing: 2) {
                                                    Image(systemName: "xmark.circle.fill")
                                                    Text("Remove")
                                                }
                                                .font(.system(size: 10))
                                                .foregroundColor(AppTheme.statusMissing)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                        .background(AppTheme.statusMissing.opacity(0.05))
                                        .cornerRadius(6)
                                    }
                                }
                                
                                // Option to create new devices
                                if !newDeviceEntries.isEmpty {
                                    Divider()
                                        .background(AppTheme.surfaceBorder)
                                    
                                    Text("Fill in details to create these as new devices:")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                    
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
                            }
                            .cardStyle()
                        }
                        
                        // Empty state - all tags were not found and none are valid
                        if foundDevices.isEmpty && notFoundTags.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "tray")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.textMuted)
                                Text("No devices to process")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(20)
                }
                
                // Bottom buttons
                HStack {
                    Button(action: { showConfirmBack = true }) {
                        Text("Back to Scan")
                            .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    .alert("Go Back to Scan?", isPresented: $showConfirmBack) {
                        Button("Cancel", role: .cancel) { }
                        Button("Go Back", role: .destructive) {
                            backToScan()
                        }
                    } message: {
                        Text("Going back will clear all scanned devices from the list. Use 'Add More Devices' instead if you want to scan additional items.")
                    }
                    
                    Button(action: { addMoreDevices() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 10))
                            Text("Add More Devices")
                        }
                        .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Skip unknown and continue with valid devices
                    if !notFoundTags.isEmpty && !foundDevices.isEmpty {
                        Button(action: skipUnknownAndProceed) {
                            HStack(spacing: 4) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 10))
                                Text("Skip Unknown (\(notFoundTags.count))")
                            }
                            .secondaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Create new devices and proceed (if user filled in details)
                    if !newDeviceEntries.isEmpty {
                        Button(action: createNewDevicesAndProceed) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 10))
                                Text("Create & Continue")
                            }
                            .primaryButton()
                        }
                        .buttonStyle(.plain)
                        .disabled(isProcessing)
                    }
                    
                    // Continue with found devices only (when no not-found tags or all removed)
                    if notFoundTags.isEmpty && !foundDevices.isEmpty {
                        Button(action: {
                            scannedTags = foundDevices.map { $0.assetTag }
                            step = .assign
                        }) {
                            Text("Continue to Assignment")
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
    }
    
    // MARK: - Step 3: Assign
    var assignStepView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assigning \(scannedTags.count) devices")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Choose where these devices are going")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        // Show skipped warning if any
                        if !skippedNotFoundTags.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.accentOrange)
                                Text("\(skippedNotFoundTags.count) unknown tag(s) were skipped and will be logged")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.accentOrange)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    // Assignment form
                    VStack(spacing: 16) {
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
                        
                        // Session Notes
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Session Note (applies to all)")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                            TextField("Optional checkout notes for entire session", text: $checkoutNotes)
                                .darkTextField()
                                .frame(width: 350)
                        }
                    }
                    .glowCardStyle()
                    .padding(.horizontal, 40)
                    
                    // Per-device list with notes
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Devices (\(scannedTags.count))")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Text("Click note icon to add per-device note")
                                .font(.system(size: 10))
                                .foregroundColor(AppTheme.textMuted)
                        }
                        
                        ForEach(scannedTags, id: \.self) { tag in
                            checkoutDeviceRow(tag: tag)
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            
            // Summary
            if selectedLocation == nil && selectedPerson == nil {
                Text("Please select at least a location or person")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.statusMissing)
                    .padding(.top, 8)
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
    
    // MARK: - Checkout Device Row with Per-Device Note
    func checkoutDeviceRow(tag: String) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                // Device info from foundDevices
                let device = foundDevices.first(where: { $0.assetTag == tag })
                
                CopyableAssetTag(assetTag: tag)
                
                if let cat = device?.category, !cat.isEmpty {
                    Text(cat)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.primaryPurple.opacity(0.1))
                        .cornerRadius(3)
                }
                
                if let model = device?.model, !model.isEmpty {
                    Text(model)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                if let sku = device?.sku, !sku.isEmpty {
                    Text(sku)
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppTheme.accentCyan.opacity(0.1))
                        .cornerRadius(3)
                }
                
                Spacer()
                
                // Note indicator / toggle
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if expandedNoteTag == tag {
                            expandedNoteTag = nil
                        } else {
                            expandedNoteTag = tag
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: perDeviceNotes[tag]?.isEmpty == false ? "note.text" : "note.text.badge.plus")
                            .font(.system(size: 11))
                        if let note = perDeviceNotes[tag], !note.isEmpty {
                            Text(note)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .frame(maxWidth: 100)
                        }
                    }
                    .foregroundColor(perDeviceNotes[tag]?.isEmpty == false ? AppTheme.accentOrange : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            
            // Expanded note field
            if expandedNoteTag == tag {
                HStack(spacing: 8) {
                    TextField("Add note for \(tag)...", text: Binding(
                        get: { perDeviceNotes[tag] ?? "" },
                        set: { perDeviceNotes[tag] = $0 }
                    ))
                    .darkTextField()
                    .font(.system(size: 11))
                    
                    Button(action: { expandedNoteTag = nil }) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppTheme.statusAvailable)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .background(AppTheme.backgroundDark)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.surfaceBorder, lineWidth: 0.5)
        )
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
                        
                        // Not found / skipped list
                        if !log.notFoundEntries.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.statusMissing)
                                    Text("\(log.notFoundEntries.count) Devices Not Found / Skipped")
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
                                            Text(entry.notes ?? "Not Found")
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
    
    func addScannedTag() {
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
    
    func parseInput() {
        addScannedTag()
    }
    
    func submitScans() {
        parseInput()
        guard !scannedTags.isEmpty else { return }
        
        sessionStartTime = Date()
        isProcessing = true
        validationError = ""
        step = .review
        
        retryValidation()
    }
    
    func retryValidation() {
        isProcessing = true
        Task {
            do {
                let response = try await APIService.shared.validateDevices(assetTags: scannedTags)
                foundDevices = response.found ?? []
                notFoundTags = response.notFound ?? []
                
                newDeviceEntries = notFoundTags.map { tag in
                    NewDeviceEntry(assetTag: tag, category: "", model: "", sku: "")
                }
                
                // If ALL devices are found, skip review and go straight to assign
                if notFoundTags.isEmpty && !foundDevices.isEmpty {
                    scannedTags = foundDevices.map { $0.assetTag }
                    step = .assign
                }
                // Otherwise stay on review step — user sees found + not-found
                
            } catch {
                validationError = "Could not validate devices: \(error.localizedDescription)"
                ToastManager.shared.error("Validation Failed", detail: error.localizedDescription)
            }
            isProcessing = false
        }
    }
    
    func skipUnknownAndProceed() {
        // Save the not-found tags for session logging
        skippedNotFoundTags = notFoundTags
        
        // Proceed with only the found devices
        scannedTags = foundDevices.map { $0.assetTag }
        newDeviceEntries = []
        
        if scannedTags.isEmpty {
            ToastManager.shared.warning("No Valid Devices", detail: "All scanned tags were unknown. Nothing to check out.")
        } else {
            ToastManager.shared.info("Skipped \(skippedNotFoundTags.count) Unknown", detail: "Proceeding with \(scannedTags.count) valid device(s).")
            step = .assign
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
                    notFoundTags = []
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
                // Filter out empty per-device notes
                let activeDeviceNotes = perDeviceNotes.filter { !$0.value.trimmingCharacters(in: .whitespaces).isEmpty }
                
                let result = try await APIService.shared.bulkCheckout(
                    assetTags: scannedTags,
                    locationId: selectedLocation?.id,
                    personId: selectedPerson?.id,
                    eventId: appState.currentEvent?.id,
                    notes: checkoutNotes,
                    perDeviceNotes: activeDeviceNotes
                )
                
                let now = Date()
                var entries: [ScanSessionEntry] = []
                
                // Build session log entries
                if result.success == true {
                    let notFoundResult = result.results?.notFound ?? []
                    
                    for tag in scannedTags {
                        let device = foundDevices.first { $0.assetTag == tag }
                        let wasNotFound = notFoundResult.contains(tag)
                        let deviceNote = perDeviceNotes[tag]
                        
                        // Combine session note + per-device note
                        var entryNote: String? = nil
                        if wasNotFound {
                            entryNote = "Device not found in system"
                        } else if let dn = deviceNote, !dn.isEmpty {
                            entryNote = dn
                        }
                        
                        entries.append(ScanSessionEntry(
                            assetTag: tag,
                            status: wasNotFound ? .notFound : .success,
                            category: device?.category,
                            model: device?.model,
                            location: selectedLocation?.name,
                            assignedTo: selectedPerson?.name,
                            notes: entryNote,
                            timestamp: now
                        ))
                    }
                    
                    // Add skipped not-found tags to the session log
                    for tag in skippedNotFoundTags {
                        entries.append(ScanSessionEntry(
                            assetTag: tag,
                            status: .notFound,
                            category: nil,
                            model: nil,
                            location: nil,
                            assignedTo: nil,
                            notes: "Skipped — not found in system (possible accidental scan)",
                            timestamp: now
                        ))
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
                    // Still log skipped tags
                    for tag in skippedNotFoundTags {
                        entries.append(ScanSessionEntry(
                            assetTag: tag,
                            status: .notFound,
                            category: nil,
                            model: nil,
                            location: nil,
                            assignedTo: nil,
                            notes: "Skipped — not found in system",
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
    
    func backToScan() {
        step = .scan
        scanText = ""
        scannedTags = []
        foundDevices = []
        notFoundTags = []
        newDeviceEntries = []
        skippedNotFoundTags = []
        validationError = ""
        isProcessing = false
        scanFieldFocused = true
    }
    
    func addMoreDevices() {
        // Go back to scan step but PRESERVE the existing scannedTags list
        step = .scan
        scanText = ""
        foundDevices = []
        notFoundTags = []
        newDeviceEntries = []
        skippedNotFoundTags = []
        validationError = ""
        isProcessing = false
        scanFieldFocused = true
    }
    
    func resetAll() {
        backToScan()
        selectedLocation = nil
        selectedPerson = nil
        showNewLocation = false
        showNewPerson = false
        newLocationName = ""
        newPersonName = ""
        newPersonRole = ""
        checkoutNotes = ""
        perDeviceNotes = [:]
        expandedNoteTag = nil
        sessionLog = nil
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
