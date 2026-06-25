import SwiftUI

struct CheckInView: View {
    @EnvironmentObject var appState: AppState
    
    enum Step {
        case scan
        case review       // NEW: validation review showing found vs not-found
        case preview      // assignment preview for found devices
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
    
    // Validation results
    @State private var validatedDevices: [ValidatedDevice] = []
    @State private var notFoundTags: [String] = []
    @State private var validationError = ""
    @State private var skippedNotFoundTags: [String] = []
    
    // Preview data
    @State private var previewDevices: [CheckInPreviewItem] = []
    
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
                        stepBadge(2, "Review", active: step == .review)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        stepBadge(3, "Preview", active: step == .preview)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                        stepBadge(4, "Done", active: step == .complete)
                    }
                }
                .padding(20)
                
                switch step {
                case .scan:
                    scanStepView
                case .review:
                    reviewStepView
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
        case .review: return "Review which devices were found in the system"
        case .preview: return "Confirm assigned locations for check-in"
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
                
                Button(action: submitScans) {
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
    
    // MARK: - Step 2: Review (Validation)
    var reviewStepView: some View {
        VStack(spacing: 12) {
            if isFetchingDevices {
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
                        if !validatedDevices.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.statusAvailable)
                                    Text("\(validatedDevices.count) device(s) found in system")
                                        .font(AppTheme.subheadingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                }
                                
                                VStack(spacing: 2) {
                                    ForEach(validatedDevices, id: \.assetTag) { device in
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
                                            Text(device.locationName ?? "—")
                                                .font(AppTheme.captionFont)
                                                .foregroundColor(AppTheme.textMuted)
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
                                
                                Text("These tags don't match any device in inventory. They may be serial numbers or incorrect scans. You can remove them or skip them and continue with the valid devices only.")
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
                            }
                            .cardStyle()
                        }
                        
                        // Empty state - all tags were not found
                        if validatedDevices.isEmpty && notFoundTags.isEmpty {
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
                    Button(action: { backToScan() }) {
                        Text("Back to Scan")
                            .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Skip unknown and continue with valid devices
                    if !notFoundTags.isEmpty && !validatedDevices.isEmpty {
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
                    
                    // Continue with found devices only (when no not-found tags or all removed)
                    if notFoundTags.isEmpty && !validatedDevices.isEmpty {
                        Button(action: proceedToPreview) {
                            Text("Continue to Check-In")
                                .primaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // All not found - no valid devices
                    if !notFoundTags.isEmpty && validatedDevices.isEmpty {
                        Text("No valid devices to check in")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.statusMissing)
                    }
                }
                .padding(20)
            }
        }
    }
    
    // MARK: - Step 3: Preview / Confirmation
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
                    Text("Session Note:")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Applies to all devices in this session...", text: $notes)
                        .darkTextField()
                        .frame(width: 300)
                    Text("(or add per-device notes below)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                // Category/Model breakdown summary
                categorySummaryView
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            
            // Table header
            HStack(spacing: 0) {
                Color.clear.frame(width: 20) // Flag column
                Text("Asset Tag")
                    .frame(width: 130, alignment: .leading)
                Text("Category / Model")
                    .frame(width: 140, alignment: .leading)
                Text("SKU")
                    .frame(width: 100, alignment: .leading)
                Text("Current Location")
                    .frame(width: 140, alignment: .leading)
                Text("Assigned Location (Check-In To)")
                    .frame(minWidth: 160, alignment: .leading)
                Text("Note")
                    .frame(width: 40, alignment: .center)
                Spacer()
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(AppTheme.textMuted)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(AppTheme.backgroundDark.opacity(0.5))
            
            // Never-checked-out warning banner
            if previewDevices.contains(where: { $0.wasNeverCheckedOut }) {
                let flaggedCount = previewDevices.filter({ $0.wasNeverCheckedOut }).count
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.accentOrange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(flaggedCount) device(s) were never checked out")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.accentOrange)
                        Text("These devices still show as \"Available\" — they may have been handed out without scanning. Add a note to explain.")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(AppTheme.accentOrange.opacity(0.08))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.accentOrange.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            
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
                    if !skippedNotFoundTags.isEmpty {
                        Text("\(skippedNotFoundTags.count) unknown tag(s) skipped (will be logged)")
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
                    step = .review
                    previewDevices.removeAll()
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
                        
                        // Category breakdown
                        if !previewDevices.isEmpty {
                            categorySummaryView
                                .padding(.horizontal, 40)
                        }
                        
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
                                    Text("\(log.notFoundEntries.count) Devices Not Found / Skipped")
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
    
    func submitScans() {
        processScannedInput()
        guard !scannedTags.isEmpty else { return }
        
        sessionStartTime = Date()
        validationError = ""
        step = .review
        retryValidation()
    }
    
    func retryValidation() {
        isFetchingDevices = true
        Task {
            do {
                let response = try await APIService.shared.validateDevices(assetTags: scannedTags)
                validatedDevices = response.found ?? []
                notFoundTags = response.notFound ?? []
                
                // If ALL devices are found, skip review and go straight to preview
                if notFoundTags.isEmpty && !validatedDevices.isEmpty {
                    proceedToPreview()
                }
                // Otherwise stay on review step — user sees found + not-found
                
            } catch {
                validationError = "Could not validate devices: \(error.localizedDescription)"
                ToastManager.shared.error("Validation Failed", detail: error.localizedDescription)
            }
            isFetchingDevices = false
        }
    }
    
    func skipUnknownAndProceed() {
        // Save the not-found tags for session logging
        skippedNotFoundTags = notFoundTags
        notFoundTags = []
        
        if validatedDevices.isEmpty {
            ToastManager.shared.warning("No Valid Devices", detail: "All scanned tags were unknown. Nothing to check in.")
        } else {
            ToastManager.shared.info("Skipped \(skippedNotFoundTags.count) Unknown", detail: "Proceeding with \(validatedDevices.count) valid device(s).")
            proceedToPreview()
        }
    }
    
    func proceedToPreview() {
        // Build preview items from validated devices
        var items: [CheckInPreviewItem] = []
        
        for device in validatedDevices {
            // Find the matching Location object for assigned location
            let assignedLoc: Location? = {
                if let name = device.assignedLocationName {
                    return appState.locations.first(where: { $0.name == name })
                }
                return nil
            }()
            
            items.append(CheckInPreviewItem(
                assetTag: device.assetTag,
                category: device.category,
                model: device.model,
                sku: device.sku,
                currentLocationName: device.locationName ?? "Unknown",
                assignedLocation: assignedLoc,
                assignedLocationName: device.assignedLocationName ?? "Not Set",
                deviceId: device.id,
                deviceStatus: device.status
            ))
        }
        
        previewDevices = items
        step = .preview
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
                    let sessionNote = notes.isEmpty ? "" : notes
                    // Build per-device notes dict for this group
                    var groupDeviceNotes: [String: String] = [:]
                    for item in items {
                        if !item.deviceNote.isEmpty {
                            groupDeviceNotes[item.assetTag] = item.deviceNote
                        }
                    }
                    // For check-in: current location = assigned location (device goes home)
                    let result = try await APIService.shared.bulkCheckin(
                        assetTags: tags,
                        locationId: assignedLocId,
                        assignedLocationId: assignedLocId,
                        notes: sessionNote,
                        perDeviceNotes: groupDeviceNotes
                    )
                    
                    if result.success == true {
                        let notFoundResult = result.results?.notFound ?? []
                        totalNotFound.append(contentsOf: notFoundResult)
                        
                        for item in items {
                            let wasNotFound = notFoundResult.contains(item.assetTag)
                            if !wasNotFound { totalCheckedIn += 1 }
                            
                            // Build note string: combine session note + per-device note + flag
                            var noteComponents: [String] = []
                            if item.wasNeverCheckedOut {
                                noteComponents.append("[Never checked out]")
                            }
                            if !item.deviceNote.isEmpty {
                                noteComponents.append(item.deviceNote)
                            }
                            if wasNotFound {
                                noteComponents = ["Device not found in system"]
                            } else if noteComponents.isEmpty {
                                noteComponents.append("Checked in to \(item.assignedLocation?.name ?? item.assignedLocationName)")
                            }
                            
                            allEntries.append(ScanSessionEntry(
                                assetTag: item.assetTag,
                                status: wasNotFound ? .notFound : .success,
                                category: item.category,
                                model: item.model,
                                location: item.assignedLocation?.name ?? item.assignedLocationName,
                                assignedTo: nil,
                                notes: noteComponents.joined(separator: " — "),
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
                
                // Add skipped not-found tags to the session log
                for tag in skippedNotFoundTags {
                    allEntries.append(ScanSessionEntry(
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
    
    // MARK: - Category Summary View
    var categorySummaryView: some View {
        let grouped = Dictionary(grouping: previewDevices) { item -> String in
            let cat = item.category ?? "Unknown"
            let mdl = item.model ?? ""
            return mdl.isEmpty ? cat : "\(cat) — \(mdl)"
        }
        let sorted = grouped.sorted { $0.value.count > $1.value.count }
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.primaryPurpleLight)
                Text("Scan Summary")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Text("\(previewDevices.count) total")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(AppTheme.primaryPurpleLight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(AppTheme.primaryPurpleLight.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Category breakdown chips
            FlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(sorted, id: \.key) { key, devices in
                    HStack(spacing: 4) {
                        Text("\(devices.count)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.primaryPurpleLight)
                        Text(key)
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(AppTheme.surfaceDefault)
                    .cornerRadius(6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                    )
                }
            }
        }
        .padding(12)
        .background(AppTheme.backgroundDark.opacity(0.3))
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
        )
    }
    
    func backToScan() {
        step = .scan
        scanText = ""
        scannedTags.removeAll()
        validatedDevices.removeAll()
        notFoundTags.removeAll()
        skippedNotFoundTags.removeAll()
        validationError = ""
        previewDevices.removeAll()
        isProcessing = false
        scanFieldFocused = true
    }
    
    func resetForm() {
        backToScan()
        notes = ""
        showOverrideAll = false
        overrideAllLocation = nil
        newOverrideLocationName = ""
        showNewOverrideLocation = false
        sessionLog = nil
    }
}

// MARK: - Preview Item Model
struct CheckInPreviewItem: Identifiable {
    let id = UUID()
    var assetTag: String
    var category: String?
    var model: String?
    var sku: String?
    var currentLocationName: String  // Read-only: where device is now
    var assignedLocation: Location?  // Editable: where it will be checked in to
    var assignedLocationName: String // Display name (fallback if no Location object)
    var deviceId: Int?
    var deviceStatus: String?        // Status from DB - detect "never checked out"
    var deviceNote: String = ""      // Per-device note
    
    var wasNeverCheckedOut: Bool {
        guard let status = deviceStatus?.lowercased() else { return false }
        return status == "available" || status == "in stock"
    }
}

// MARK: - Preview Row View
struct CheckInPreviewRow: View {
    @Binding var item: CheckInPreviewItem
    let locations: [Location]
    let appState: AppState
    
    @State private var showLocationPicker = false
    @State private var newLocationName = ""
    @State private var showNewLocation = false
    @State private var showNoteField = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Never-checked-out flag
                if item.wasNeverCheckedOut {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.accentOrange)
                        .frame(width: 20)
                        .help("This device was never checked out")
                } else {
                    Color.clear.frame(width: 20)
                }
                
                // Asset Tag
                CopyableAssetTag(assetTag: item.assetTag)
                    .frame(width: 130, alignment: .leading)
                
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
                .frame(width: 140, alignment: .leading)
                
                // SKU
                Text(item.sku ?? "—")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
                
                // Current Location (read-only)
                Text(item.currentLocationName)
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.textMuted)
                    .frame(width: 140, alignment: .leading)
                
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
                        .frame(width: 140)
                        
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
                }
                .frame(minWidth: 160, alignment: .leading)
                
                // Per-device note toggle
                Button(action: { showNoteField.toggle() }) {
                    HStack(spacing: 2) {
                        Image(systemName: item.deviceNote.isEmpty ? "note.text.badge.plus" : "note.text")
                            .font(.system(size: 12))
                        if !item.deviceNote.isEmpty {
                            Circle()
                                .fill(AppTheme.primaryPurpleLight)
                                .frame(width: 5, height: 5)
                        }
                    }
                    .foregroundColor(item.deviceNote.isEmpty ? AppTheme.textMuted : AppTheme.primaryPurpleLight)
                }
                .buttonStyle(.plain)
                .help(item.deviceNote.isEmpty ? "Add a note for this device" : "Edit device note")
                
                Spacer()
            }
            
            // Per-device note field (expanded)
            if showNoteField {
                HStack(spacing: 8) {
                    if item.wasNeverCheckedOut {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.accentOrange)
                        Text("Never checked out —")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(AppTheme.accentOrange)
                    } else {
                        Image(systemName: "note.text")
                            .font(.system(size: 10))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    TextField(item.wasNeverCheckedOut ? "e.g. Handed to Adam but forgot to scan out" : "Add a note for this device...", text: $item.deviceNote)
                        .darkTextField()
                        .font(.system(size: 11))
                }
                .padding(.leading, 20)
                .padding(.trailing, 8)
                .padding(.vertical, 4)
                .background(item.wasNeverCheckedOut ? AppTheme.accentOrange.opacity(0.05) : AppTheme.backgroundDark.opacity(0.3))
            }
            
            // New location inline
            if showNewLocation {
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
                .padding(.leading, 20)
                .padding(8)
                .background(AppTheme.backgroundDark)
                .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            item.wasNeverCheckedOut
                ? AppTheme.accentOrange.opacity(0.06)
                : AppTheme.surfaceDefault.opacity(0.3)
        )
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    item.wasNeverCheckedOut ? AppTheme.accentOrange.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}
