import SwiftUI
import UniformTypeIdentifiers

struct ImportExportView: View {
    @EnvironmentObject var appState: AppState
    
    // Import state
    @State private var isImporting = false
    @State private var importResult = ""
    @State private var showImportResult = false
    @State private var rawCSVRows: [[String: String]] = []
    @State private var availableColumns: [String] = []
    
    // Wizard steps
    @State private var importStep: ImportStep = .selectFile
    
    // Step 1: Column mapping
    @State private var columnMapping: [String: String] = [:]
    @State private var customFieldColumns: [String] = []
    @State private var unmappedColumns: [String] = []
    
    // Step 2: Overwrite options
    @State private var fieldsToOverwrite: Set<String> = []
    @State private var overwriteAll = true
    
    // Export state
    @State private var isExporting = false
    @State private var exportFilterEvent: Event? = nil
    @State private var exportFilterStatus: String = ""
    @State private var exportFilterCategory: String = ""
    @State private var exportFilterLocation: Location? = nil
    
    // Known target fields
    let targetFields = ["asset_tag", "category", "model", "sku", "status", "location", "assigned_to", "account", "live_or_dummy", "notes"]
    let targetFieldLabels: [String: String] = [
        "asset_tag": "Asset Tag",
        "category": "Category",
        "model": "Model",
        "sku": "SKU/Style",
        "status": "Status",
        "location": "Location",
        "assigned_to": "Assigned To",
        "account": "Account",
        "live_or_dummy": "Live/Dummy",
        "notes": "Notes"
    ]
    
    enum ImportStep {
        case selectFile
        case mapColumns
        case overwriteOptions
        case importing
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Import / Export")
                                .font(AppTheme.titleFont)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Import Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(AppTheme.primaryPurpleLight)
                            Text("Import")
                                .font(AppTheme.headingFont)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        
                        importWizardView
                    }
                    .glowCardStyle()
                    .padding(.horizontal, 20)
                    
                    // Export Section
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "square.and.arrow.up.fill")
                                .foregroundColor(AppTheme.primaryPurpleLight)
                            Text("Export")
                                .font(AppTheme.headingFont)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        
                        Text("Export inventory to CSV. Use filters to export specific subsets.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        // Filter options
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Export Filters")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                                .textCase(.uppercase)
                            
                            HStack(spacing: 16) {
                                // Event filter
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Event")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                    Picker("", selection: $exportFilterEvent) {
                                        Text("All Events").tag(nil as Event?)
                                        ForEach(appState.events, id: \.id) { event in
                                            Text(event.name).tag(Optional(event))
                                        }
                                    }
                                    .frame(width: 180)
                                }
                                
                                // Status filter
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Status")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                    Picker("", selection: $exportFilterStatus) {
                                        Text("All Statuses").tag("")
                                        Text("Available").tag("Available")
                                        Text("Checked Out").tag("Checked Out")
                                        Text("In Transit").tag("In Transit")
                                        Text("Missing").tag("Missing")
                                        Text("Retired").tag("Retired")
                                    }
                                    .frame(width: 150)
                                }
                                
                                // Category filter
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Category")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                    TextField("e.g. Radio, Camera", text: $exportFilterCategory)
                                        .darkTextField()
                                        .frame(width: 140)
                                }
                                
                                // Location filter
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                    Picker("", selection: $exportFilterLocation) {
                                        Text("All Locations").tag(nil as Location?)
                                        ForEach(appState.locations, id: \.id) { loc in
                                            Text(loc.name).tag(Optional(loc))
                                        }
                                    }
                                    .frame(width: 180)
                                }
                            }
                            
                            // Active filters summary
                            if hasActiveExportFilters {
                                HStack(spacing: 6) {
                                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                        .foregroundColor(AppTheme.accentCyan)
                                    Text("Filters active: exporting subset of devices")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.accentCyan)
                                    Spacer()
                                    Button("Clear Filters") {
                                        exportFilterEvent = nil
                                        exportFilterStatus = ""
                                        exportFilterCategory = ""
                                        exportFilterLocation = nil
                                    }
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.statusMissing)
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(12)
                        .background(AppTheme.backgroundDark)
                        .cornerRadius(AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                        )
                        
                        HStack {
                            Button(action: exportCSV) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text(hasActiveExportFilters ? "Export Filtered CSV" : "Export All to CSV")
                                }
                                .primaryButton()
                            }
                            .buttonStyle(.plain)
                            
                            if isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                    .glowCardStyle()
                    .padding(.horizontal, 20)
                    
                    Spacer()
                }
            }
        }
        .alert("Import Result", isPresented: $showImportResult) {
            Button("OK") { resetWizard() }
        } message: {
            Text(importResult)
        }
    }
    
    // MARK: - Import Wizard View
    @ViewBuilder
    var importWizardView: some View {
        // Progress indicator
        if importStep != .selectFile {
            HStack(spacing: 4) {
                stepIndicator(step: 1, label: "Map Columns", active: importStep == .mapColumns)
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textMuted)
                    .font(.caption2)
                stepIndicator(step: 2, label: "Update Options", active: importStep == .overwriteOptions)
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.textMuted)
                    .font(.caption2)
                stepIndicator(step: 3, label: "Import", active: importStep == .importing)
                Spacer()
                
                Button(action: resetWizard) {
                    Text("Start Over")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.statusMissing)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
            
            Rectangle()
                .fill(AppTheme.surfaceBorder)
                .frame(height: 1)
        }
        
        switch importStep {
        case .selectFile:
            selectFileView
        case .mapColumns:
            mapColumnsView
        case .overwriteOptions:
            overwriteOptionsView
        case .importing:
            importingView
        }
    }
    
    func stepIndicator(step: Int, label: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(active ? AppTheme.primaryPurple : AppTheme.surfaceBorder)
                .frame(width: 20, height: 20)
                .overlay(
                    Text("\(step)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                )
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(active ? AppTheme.textPrimary : AppTheme.textMuted)
        }
    }
    
    // MARK: - Step: Select File
    var selectFileView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Import devices from a CSV file. You'll be able to map columns, create custom fields, and choose what to overwrite.")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
            
            Button(action: selectFile) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.badge.plus")
                    Text("Select CSV File...")
                }
                .primaryButton()
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Step: Map Columns
    var mapColumnsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Column Mapping")
                    .font(AppTheme.subheadingFont)
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(rawCSVRows.count) rows loaded")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.statusAvailable)
            }
            
            Text("Map your CSV columns to inventory fields. Unmapped columns can be saved as Custom Fields.")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
            
            // Standard field mapping
            VStack(alignment: .leading, spacing: 10) {
                Text("Standard Fields")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                    .textCase(.uppercase)
                
                ForEach(targetFields, id: \.self) { field in
                    HStack {
                        HStack(spacing: 4) {
                            Text(targetFieldLabels[field] ?? field)
                                .font(AppTheme.bodyFont)
                                .foregroundColor(AppTheme.textSecondary)
                            if field == "asset_tag" {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(AppTheme.statusMissing)
                                    .font(.caption)
                                    .help("Required - used as unique identifier")
                            }
                        }
                        .frame(width: 120, alignment: .trailing)
                        
                        Picker("", selection: Binding(
                            get: { columnMapping[field] ?? "" },
                            set: { newVal in
                                columnMapping[field] = newVal
                                recalculateUnmapped()
                            }
                        )) {
                            Text("-- Skip --").tag("")
                            ForEach(availableColumns, id: \.self) { col in
                                Text(col).tag(col)
                            }
                        }
                        .frame(width: 200)
                    }
                }
            }
            .padding(12)
            .background(AppTheme.backgroundDark)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
            )
            
            // Unmapped columns → Custom Fields
            if !unmappedColumns.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Unmapped Columns → Custom Fields")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textMuted)
                        .textCase(.uppercase)
                    
                    Text("Check the ones you want to import as custom fields:")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    ForEach(unmappedColumns, id: \.self) { col in
                        HStack {
                            Toggle(isOn: Binding(
                                get: { customFieldColumns.contains(col) },
                                set: { isOn in
                                    if isOn {
                                        if !customFieldColumns.contains(col) {
                                            customFieldColumns.append(col)
                                        }
                                    } else {
                                        customFieldColumns.removeAll { $0 == col }
                                    }
                                }
                            )) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppTheme.accentCyan)
                                        .font(.caption)
                                    Text(col)
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("→ Custom Field")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .toggleStyle(.checkbox)
                            Spacer()
                        }
                    }
                    
                    if !customFieldColumns.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .foregroundColor(AppTheme.accentCyan)
                            Text("Custom fields will be stored with each device and included in exports.")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(12)
                .background(AppTheme.backgroundDark)
                .cornerRadius(AppTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.accentCyan.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Preview
            previewSection
            
            // Navigation
            HStack {
                Spacer()
                Button(action: {
                    fieldsToOverwrite = Set(targetFields.filter { field in
                        if let mapped = columnMapping[field], !mapped.isEmpty { return true }
                        return false
                    })
                    if !customFieldColumns.isEmpty {
                        fieldsToOverwrite.insert("custom_fields")
                    }
                    importStep = .overwriteOptions
                }) {
                    HStack(spacing: 4) {
                        Text("Next: Update Options")
                        Image(systemName: "arrow.right")
                    }
                    .primaryButton()
                }
                .buttonStyle(.plain)
                .disabled(columnMapping["asset_tag"]?.isEmpty ?? true)
            }
        }
    }
    
    // MARK: - Preview Section
    var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview (first 3 rows)")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
            
            ScrollView(.horizontal) {
                VStack(alignment: .leading, spacing: 2) {
                    // Header
                    HStack(spacing: 0) {
                        ForEach(mappedFieldLabels(), id: \.self) { label in
                            Text(label)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.textMuted)
                                .frame(width: 90, alignment: .leading)
                                .lineLimit(1)
                        }
                        ForEach(customFieldColumns, id: \.self) { col in
                            Text("✦ \(col)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.accentCyan)
                                .frame(width: 90, alignment: .leading)
                                .lineLimit(1)
                        }
                    }
                    
                    Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
                    
                    ForEach(Array(rawCSVRows.prefix(3).enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 0) {
                            ForEach(mappedFields(), id: \.self) { field in
                                let sourceCol = columnMapping[field] ?? ""
                                Text(sourceCol.isEmpty ? "—" : (row[sourceCol] ?? "—"))
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.textSecondary)
                                    .frame(width: 90, alignment: .leading)
                                    .lineLimit(1)
                            }
                            ForEach(customFieldColumns, id: \.self) { col in
                                Text(row[col] ?? "—")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.accentCyan)
                                    .frame(width: 90, alignment: .leading)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(AppTheme.backgroundDark)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Step: Overwrite Options
    var overwriteOptionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Field Update Options")
                .font(AppTheme.subheadingFont)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("When a device already exists (matched by Asset Tag), which fields should be overwritten with the new import data?")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
            
            // Toggle all
            Toggle(isOn: $overwriteAll) {
                Text("Overwrite all mapped fields")
                    .font(AppTheme.bodyFont)
                    .foregroundColor(AppTheme.textPrimary)
            }
            .toggleStyle(.checkbox)
            .onChange(of: overwriteAll) { newVal in
                if newVal {
                    fieldsToOverwrite = Set(targetFields.filter { field in
                        if let mapped = columnMapping[field], !mapped.isEmpty, field != "asset_tag" { return true }
                        return false
                    })
                    if !customFieldColumns.isEmpty {
                        fieldsToOverwrite.insert("custom_fields")
                    }
                } else {
                    fieldsToOverwrite.removeAll()
                }
            }
            
            Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
            
            if !overwriteAll {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppTheme.accentOrange)
                    Text("Select which fields to overwrite (unchecked fields will keep their existing value):")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.accentOrange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(targetFields.filter { $0 != "asset_tag" }, id: \.self) { field in
                        if let mapped = columnMapping[field], !mapped.isEmpty {
                            Toggle(isOn: Binding(
                                get: { fieldsToOverwrite.contains(field) },
                                set: { isOn in
                                    if isOn { fieldsToOverwrite.insert(field) }
                                    else { fieldsToOverwrite.remove(field) }
                                }
                            )) {
                                HStack {
                                    Text(targetFieldLabels[field] ?? field)
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .frame(width: 100, alignment: .leading)
                                    Text("← \(mapped)")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    
                    if !customFieldColumns.isEmpty {
                        Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
                        Toggle(isOn: Binding(
                            get: { fieldsToOverwrite.contains("custom_fields") },
                            set: { isOn in
                                if isOn { fieldsToOverwrite.insert("custom_fields") }
                                else { fieldsToOverwrite.remove("custom_fields") }
                            }
                        )) {
                            HStack {
                                Text("Custom Fields")
                                    .font(AppTheme.bodyFont)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .frame(width: 100, alignment: .leading)
                                Text("(\(customFieldColumns.joined(separator: ", ")))")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.accentCyan)
                            }
                        }
                        .toggleStyle(.checkbox)
                    }
                }
                .padding(12)
                .background(AppTheme.backgroundDark)
                .cornerRadius(AppTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                        .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                )
                
                // Hint
                HStack(spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(AppTheme.accentOrange)
                    Text("Example: Check only \"Location\" to move devices without changing who they're assigned to.")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .padding(.top, 4)
            }
            
            // Summary
            VStack(alignment: .leading, spacing: 6) {
                Text("Import Summary")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
                    .textCase(.uppercase)
                
                VStack(alignment: .leading, spacing: 4) {
                    summaryRow("Rows to process", "\(rawCSVRows.count)")
                    summaryRow("Match key", "Asset Tag")
                    summaryRow("New devices", "All fields will be set")
                    if overwriteAll {
                        summaryRow("Existing devices", "All mapped fields overwritten", color: AppTheme.accentOrange)
                    } else {
                        let count = fieldsToOverwrite.count
                        summaryRow("Existing devices", "\(count) field\(count == 1 ? "" : "s") overwritten",
                                   color: count == 0 ? AppTheme.statusAvailable : AppTheme.accentOrange)
                    }
                    if !customFieldColumns.isEmpty {
                        summaryRow("Custom fields", customFieldColumns.joined(separator: ", "), color: AppTheme.accentCyan)
                    }
                }
            }
            .padding(12)
            .background(AppTheme.backgroundDark)
            .cornerRadius(AppTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
            )
            
            // Navigation
            HStack {
                Button(action: { importStep = .mapColumns }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back to Mapping")
                    }
                    .secondaryButton()
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                HStack(spacing: 12) {
                    if isImporting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                            .scaleEffect(0.7)
                    }
                    Button(action: performImport) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle.fill")
                            Text("Import Now")
                        }
                        .primaryButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)
                }
            }
        }
    }
    
    func summaryRow(_ label: String, _ value: String, color: Color = AppTheme.textSecondary) -> some View {
        HStack(spacing: 6) {
            Text("•")
                .foregroundColor(AppTheme.textMuted)
            Text(label + ":")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
            Text(value)
                .font(AppTheme.captionFont)
                .foregroundColor(color)
        }
    }
    
    // MARK: - Step: Importing
    var importingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
            Text("Importing \(rawCSVRows.count) devices...")
                .font(AppTheme.bodyFont)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    func mappedFields() -> [String] {
        return targetFields.filter { field in
            if let mapped = columnMapping[field], !mapped.isEmpty { return true }
            return false
        }
    }
    
    func mappedFieldLabels() -> [String] {
        return mappedFields().map { targetFieldLabels[$0] ?? $0 }
    }
    
    func recalculateUnmapped() {
        let mappedSourceColumns = Set(columnMapping.values.filter { !$0.isEmpty })
        unmappedColumns = availableColumns.filter { col in
            !mappedSourceColumns.contains(col)
        }
        customFieldColumns = customFieldColumns.filter { unmappedColumns.contains($0) }
    }
    
    func resetWizard() {
        importStep = .selectFile
        rawCSVRows = []
        availableColumns = []
        columnMapping = [:]
        customFieldColumns = []
        unmappedColumns = []
        fieldsToOverwrite = []
        overwriteAll = true
    }
    
    // MARK: - File Selection
    func selectFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.commaSeparatedText, UTType(filenameExtension: "csv")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            parseCSV(url: url)
        }
    }
    
    func parseCSV(url: URL) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            guard lines.count > 1 else {
                importResult = "File appears empty or has no data rows."
                showImportResult = true
                return
            }
            
            let headers = parseCSVLine(lines[0])
            availableColumns = headers
            
            rawCSVRows = []
            for i in 1..<lines.count {
                let values = parseCSVLine(lines[i])
                var row: [String: String] = [:]
                for (index, header) in headers.enumerated() {
                    if index < values.count {
                        row[header] = values[index]
                    }
                }
                rawCSVRows.append(row)
            }
            
            autoMapColumns(headers)
            recalculateUnmapped()
            importStep = .mapColumns
            
        } catch {
            importResult = "Error reading file: \(error.localizedDescription)"
            showImportResult = true
        }
    }
    
    func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))
        return result
    }
    
    func autoMapColumns(_ headers: [String]) {
        let mappings: [String: [String]] = [
            "asset_tag": ["Asset Tag", "Asset Tag ID", "Serial Number", "Serial", "Barcode", "asset_tag"],
            "category": ["Category", "Type", "Device Type", "category"],
            "model": ["Model", "Device Model", "Brand", "model"],
            "sku": ["SKU", "Style", "Frame Style", "SKU/Style", "sku"],
            "status": ["Status", "Device Status", "status"],
            "location": ["Location", "Current Location", "Site", "location"],
            "assigned_to": ["Assigned To", "Checked Out To", "Person", "assigned_to"],
            "account": ["Account", "account"],
            "live_or_dummy": ["Live or Dummy", "(Wearable) Live or Dummy", "Live/Dummy", "live_or_dummy"],
            "notes": ["Notes", "Comments", "notes"]
        ]
        
        columnMapping = [:]
        for (field, possibleNames) in mappings {
            for name in possibleNames {
                if let match = headers.first(where: { $0.lowercased() == name.lowercased() }) {
                    columnMapping[field] = match
                    break
                }
            }
        }
    }
    
    // MARK: - Perform Import
    func performImport() {
        isImporting = true
        importStep = .importing
        
        let devices: [[String: Any]] = rawCSVRows.compactMap { row in
            var mapped: [String: Any] = [:]
            
            for field in targetFields {
                if let sourceCol = columnMapping[field], !sourceCol.isEmpty, let value = row[sourceCol], !value.isEmpty {
                    mapped[field] = value
                }
            }
            
            for cfCol in customFieldColumns {
                if let value = row[cfCol], !value.isEmpty {
                    mapped[cfCol] = value
                }
            }
            
            guard mapped["asset_tag"] != nil else { return nil }
            return mapped
        }
        
        var fieldsToUpdateArray: [String]? = nil
        if !overwriteAll {
            fieldsToUpdateArray = Array(fieldsToOverwrite)
        }
        
        Task {
            do {
                let result = try await APIService.shared.importDevices(
                    devices: devices,
                    eventId: appState.currentEvent?.id,
                    fieldsToUpdate: fieldsToUpdateArray,
                    customFieldNames: customFieldColumns
                )
                if result.success == true {
                    let details = result.results
                    var msg = "Import complete!\n"
                    msg += "New devices created: \(details?.imported ?? details?.created ?? 0)\n"
                    msg += "Existing devices updated: \(details?.updated ?? 0)\n"
                    if let skipped = details?.skipped, skipped > 0 {
                        msg += "Skipped (no changes): \(skipped)\n"
                    }
                    if let errors = details?.errors, !errors.isEmpty {
                        msg += "Errors: \(errors.count)"
                    }
                    importResult = msg
                } else {
                    importResult = result.error ?? "Unknown error"
                }
            } catch {
                importResult = "Error: \(error.localizedDescription)"
            }
            isImporting = false
            showImportResult = true
        }
    }
    
    // MARK: - Export
    var hasActiveExportFilters: Bool {
        exportFilterEvent != nil || !exportFilterStatus.isEmpty || !exportFilterCategory.isEmpty || exportFilterLocation != nil
    }
    
    func exportCSV() {
        isExporting = true
        Task {
            do {
                let eventId = exportFilterEvent?.id ?? appState.currentEvent?.id
                let status: String? = exportFilterStatus.isEmpty ? nil : exportFilterStatus
                let category: String? = exportFilterCategory.isEmpty ? nil : exportFilterCategory
                let locationId: Int? = exportFilterLocation?.id
                
                let data = try await APIService.shared.exportCSV(
                    eventId: eventId,
                    status: status,
                    category: category,
                    locationId: locationId
                )
                
                var filename = "inventory_export"
                if let event = exportFilterEvent { filename += "_\(event.name.replacingOccurrences(of: " ", with: "_"))" }
                if let s = status { filename += "_\(s.replacingOccurrences(of: " ", with: "_"))" }
                if let c = category { filename += "_\(c.replacingOccurrences(of: " ", with: "_"))" }
                if let loc = exportFilterLocation { filename += "_\(loc.name.replacingOccurrences(of: " ", with: "_"))" }
                filename += "_\(formattedDate()).csv"
                
                let panel = NSSavePanel()
                panel.allowedContentTypes = [UTType.commaSeparatedText]
                panel.nameFieldStringValue = filename
                
                if panel.runModal() == .OK, let url = panel.url {
                    try data.write(to: url)
                    importResult = "Exported successfully to \(url.lastPathComponent)"
                    showImportResult = true
                }
            } catch {
                importResult = "Export error: \(error.localizedDescription)"
                showImportResult = true
            }
            isExporting = false
        }
    }
    
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        return formatter.string(from: Date())
    }
}
