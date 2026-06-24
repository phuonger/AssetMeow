import SwiftUI

struct InventoryListView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var devices: [Device] = []
    @State private var totalCount = 0
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var filterStatus: DeviceStatus?
    @State private var filterCategory = ""
    @State private var filterModel = ""
    @State private var filterSku = ""
    @State private var filterCurrentLocation: Location?
    @State private var filterAssignedLocation: Location?
    @State private var selectedAssetTag: String?
    @State private var editingDevice: Device?
    
    // Multi-select
    @State private var isMultiSelectMode = false
    @State private var selectedDeviceIds: Set<Int> = []
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteResult = ""
    @State private var showDeleteResult = false
    
    // Move/Assign
    @State private var showMovePanel = false
    @State private var moveToEvent: Event?
    @State private var moveAssignedLocation: Location?
    @State private var moveCurrentLocation: Location?
    @State private var isMoving = false
    @State private var moveResult = ""
    @State private var showMoveResult = false
    @State private var showNewLocationSheet = false
    @State private var newLocationName = ""
    @State private var newLocationTarget = "" // "assigned" or "current"
    
    // Computed unique values for filter pickers
    var availableCategories: [String] {
        Array(Set(devices.compactMap { $0.category }.filter { !$0.isEmpty })).sorted()
    }
    
    var availableModels: [String] {
        Array(Set(devices.compactMap { $0.model }.filter { !$0.isEmpty })).sorted()
    }
    
    var availableSkus: [String] {
        Array(Set(devices.compactMap { $0.sku }.filter { !$0.isEmpty })).sorted()
    }
    
    var filteredDevices: [Device] {
        var result = devices
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.assetTag.lowercased().contains(q) ||
                ($0.model?.lowercased().contains(q) ?? false) ||
                ($0.sku?.lowercased().contains(q) ?? false) ||
                ($0.category?.lowercased().contains(q) ?? false) ||
                ($0.locationName?.lowercased().contains(q) ?? false) ||
                ($0.assignedToName?.lowercased().contains(q) ?? false)
            }
        }
        if !filterModel.isEmpty {
            result = result.filter { $0.model == filterModel }
        }
        if !filterSku.isEmpty {
            result = result.filter { $0.sku == filterSku }
        }
        return result
    }
    
    var allFilteredSelected: Bool {
        let ids = Set(filteredDevices.compactMap { $0.id })
        return !ids.isEmpty && ids.isSubset(of: selectedDeviceIds)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Inventory")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Spacer()
                    
                    // Multi-select toggle
                    Button(action: {
                        isMultiSelectMode.toggle()
                        if !isMultiSelectMode { selectedDeviceIds.removeAll() }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: isMultiSelectMode ? "checkmark.circle.fill" : "checkmark.circle")
                            Text(isMultiSelectMode ? "Done" : "Select")
                        }
                        .font(AppTheme.captionFont)
                        .foregroundColor(isMultiSelectMode ? AppTheme.primaryPurpleLight : AppTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    Text("\(filteredDevices.count) / \(totalCount) devices")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textMuted)
                        .padding(.leading, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 12)
                
                // Multi-select action bar
                if isMultiSelectMode && !selectedDeviceIds.isEmpty {
                    HStack(spacing: 12) {
                        Text("\(selectedDeviceIds.count) selected")
                            .font(AppTheme.subheadingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        Spacer()
                        
                        Button(action: { selectedDeviceIds.removeAll() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                Text("Deselect All")
                            }
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showMovePanel.toggle() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Move / Assign")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.primaryPurple)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showDeleteConfirmation = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                Text("Delete Selected")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.statusMissing)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppTheme.primaryPurple.opacity(0.1))
                    
                    // Move/Assign panel
                    if showMovePanel {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Event:")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                Picker("", selection: $moveToEvent) {
                                    Text("-- Don't change --").tag(nil as Event?)
                                    ForEach(appState.events, id: \.id) { event in
                                        Text(event.name).tag(Optional(event))
                                    }
                                }
                                .frame(width: 150)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Assigned Location:")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                HStack(spacing: 4) {
                                    Picker("", selection: $moveAssignedLocation) {
                                        Text("-- Don't change --").tag(nil as Location?)
                                        ForEach(appState.locations, id: \.id) { loc in
                                            Text(loc.name).tag(Optional(loc))
                                        }
                                    }
                                    .frame(width: 140)
                                    Button(action: {
                                        newLocationTarget = "assigned"
                                        newLocationName = ""
                                        showNewLocationSheet = true
                                    }) {
                                        Text("+ New")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(AppTheme.primaryPurpleLight)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Current Location:")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                HStack(spacing: 4) {
                                    Picker("", selection: $moveCurrentLocation) {
                                        Text("-- Don't change --").tag(nil as Location?)
                                        ForEach(appState.locations, id: \.id) { loc in
                                            Text(loc.name).tag(Optional(loc))
                                        }
                                    }
                                    .frame(width: 140)
                                    Button(action: {
                                        newLocationTarget = "current"
                                        newLocationName = ""
                                        showNewLocationSheet = true
                                    }) {
                                        Text("+ New")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(AppTheme.primaryPurpleLight)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            
                            Button(action: executeMoveSelected) {
                                HStack(spacing: 4) {
                                    if isMoving {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.6)
                                    }
                                    Text("Apply")
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(AppTheme.primaryPurple)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .disabled(moveToEvent == nil && moveAssignedLocation == nil && moveCurrentLocation == nil || isMoving)
                            
                            Button(action: { showMovePanel = false }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(AppTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(AppTheme.surfaceDefault.opacity(0.5))
                        .sheet(isPresented: $showNewLocationSheet) {
                            VStack(spacing: 16) {
                                Text("Create New Location")
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                
                                Text("This location will be created under the currently selected event.")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                
                                TextField("Location name", text: $newLocationName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 250)
                                
                                HStack(spacing: 12) {
                                    Button("Cancel") {
                                        showNewLocationSheet = false
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundColor(AppTheme.textMuted)
                                    
                                    Button("Create") {
                                        createNewLocation()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(AppTheme.primaryPurple)
                                    .disabled(newLocationName.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            .padding(24)
                            .frame(width: 320, height: 180)
                            .background(AppTheme.backgroundDark)
                        }
                    }
                }
                
                // Filters bar
                HStack(spacing: 12) {
                    // Search
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.textMuted)
                        TextField("Filter...", text: $searchText)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    .padding(8)
                    .background(AppTheme.backgroundDark)
                    .cornerRadius(AppTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                            .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                    )
                    .frame(maxWidth: 200)
                    
                    // Status filter
                    Picker("Status", selection: $filterStatus) {
                        Text("All Status").tag(nil as DeviceStatus?)
                        ForEach(DeviceStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(Optional(status))
                        }
                    }
                    .frame(width: 140)
                    .onChange(of: filterStatus) { _ in loadDevices() }
                    
                    // Category filter (picker from available values)
                    Picker("Category", selection: $filterCategory) {
                        Text("All Categories").tag("")
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .frame(width: 140)
                    .onChange(of: filterCategory) { _ in loadDevices() }
                    
                    // Model filter (picker from available values)
                    Picker("Model", selection: $filterModel) {
                        Text("All Models").tag("")
                        ForEach(availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    .frame(width: 140)
                    .onChange(of: filterModel) { _ in loadDevices() }
                    
                    // SKU filter (picker from available values)
                    Picker("SKU", selection: $filterSku) {
                        Text("All SKUs").tag("")
                        ForEach(availableSkus, id: \.self) { sku in
                            Text(sku).tag(sku)
                        }
                    }
                    .frame(width: 120)
                    .onChange(of: filterSku) { _ in loadDevices() }
                    
                    // Current Location filter
                    Picker("Current Loc.", selection: $filterCurrentLocation) {
                        Text("All Current Loc.").tag(nil as Location?)
                        ForEach(appState.locations, id: \.id) { loc in
                            Text(loc.name).tag(Optional(loc))
                        }
                    }
                    .frame(width: 150)
                    .onChange(of: filterCurrentLocation) { _ in loadDevices() }
                    
                    // Assigned Location filter
                    Picker("Assigned Loc.", selection: $filterAssignedLocation) {
                        Text("All Assigned Loc.").tag(nil as Location?)
                        ForEach(appState.locations, id: \.id) { loc in
                            Text(loc.name).tag(Optional(loc))
                        }
                    }
                    .frame(width: 150)
                    .onChange(of: filterAssignedLocation) { _ in loadDevices() }
                    
                    Spacer()
                    
                    Button(action: loadDevices) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(AppTheme.primaryPurpleLight)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                
                // Error message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppTheme.accentOrange)
                        Text(error)
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.accentOrange)
                        Spacer()
                        Button("Retry") { loadDevices() }
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.primaryPurpleLight)
                            .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentOrange.opacity(0.1))
                }
                
                // Table
                if isLoading && devices.isEmpty {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                    Text("Loading inventory...")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                } else if devices.isEmpty && errorMessage == nil {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 36))
                            .foregroundColor(AppTheme.textMuted)
                        Text("No devices found")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textSecondary)
                        Text("Try changing your filters or importing devices.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                        Button(action: loadDevices) {
                            Text("Reload")
                                .secondaryButton()
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                    }
                    Spacer()
                } else {
                    // Header row
                    HStack(spacing: 0) {
                        if isMultiSelectMode {
                            Button(action: toggleSelectAll) {
                                Image(systemName: allFilteredSelected ? "checkmark.square.fill" : "square")
                                    .foregroundColor(allFilteredSelected ? AppTheme.primaryPurple : AppTheme.textMuted)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 30)
                        }
                        Text("Asset Tag")
                            .frame(width: 140, alignment: .leading)
                        Text("Category")
                            .frame(width: 80, alignment: .leading)
                        Text("Model")
                            .frame(width: 110, alignment: .leading)
                        Text("SKU")
                            .frame(width: 110, alignment: .leading)
                        Text("Status")
                            .frame(width: 100, alignment: .leading)
                        Text("Current Loc.")
                            .frame(width: 120, alignment: .leading)
                        Text("Assigned Loc.")
                            .frame(width: 120, alignment: .leading)
                        Text("Assigned To")
                            .frame(width: 110, alignment: .leading)
                        Text("Last Scanned")
                            .frame(width: 130, alignment: .leading)
                        Spacer()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppTheme.backgroundDark)
                    
                    Rectangle()
                        .fill(AppTheme.surfaceBorder)
                        .frame(height: 1)
                    
                    // Device list
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(filteredDevices, id: \.assetTag) { device in
                                deviceRow(device)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            loadDevices()
        }
        .onChange(of: appState.currentEvent) { _ in
            loadDevices()
        }
        .sheet(item: $editingDevice) { device in
            DeviceEditSheet(device: device) {
                loadDevices()
            }
            .environmentObject(appState)
        }
        .alert("Delete \(selectedDeviceIds.count) Devices?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { performBulkDelete() }
        } message: {
            Text("This will permanently delete \(selectedDeviceIds.count) devices from the inventory. This action cannot be undone.")
        }
        .alert("Delete Result", isPresented: $showDeleteResult) {
            Button("OK") { }
        } message: {
            Text(deleteResult)
        }
        .alert("Move Result", isPresented: $showMoveResult) {
            Button("OK") { }
        } message: {
            Text(moveResult)
        }
    }
    
    // MARK: - Device Row
    func deviceRow(_ device: Device) -> some View {
        HStack(spacing: 0) {
            if isMultiSelectMode {
                let isSelected = device.id != nil && selectedDeviceIds.contains(device.id!)
                Button(action: { toggleSelection(device) }) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? AppTheme.primaryPurple : AppTheme.textMuted)
                }
                .buttonStyle(.plain)
                .frame(width: 30)
            }
            
            CopyableAssetTag(assetTag: device.assetTag)
                .frame(width: 140, alignment: .leading)
            CopyableText(text: device.category ?? "—")
                .frame(width: 80, alignment: .leading)
            CopyableText(text: device.model ?? "—")
                .frame(width: 110, alignment: .leading)
            CopyableText(text: device.sku ?? "—")
                .frame(width: 110, alignment: .leading)
            Text(device.status.rawValue)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(AppTheme.statusColor(for: device.status.rawValue).opacity(0.2))
                .foregroundColor(AppTheme.statusColor(for: device.status.rawValue))
                .cornerRadius(4)
                .frame(width: 100, alignment: .leading)
            Text(device.locationName ?? "—")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 120, alignment: .leading)
            Text(device.assignedLocationName ?? "—")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 120, alignment: .leading)
            Text(device.assignedToName ?? "—")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 110, alignment: .leading)
            Text(device.lastScanned ?? "Never")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 130, alignment: .leading)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            selectedAssetTag == device.assetTag
                ? AppTheme.primaryPurple.opacity(0.2)
                : (device.id != nil && selectedDeviceIds.contains(device.id!)
                    ? AppTheme.primaryPurple.opacity(0.08)
                    : AppTheme.surfaceDefault.opacity(0.3))
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            // Double-tap opens edit sheet
            editingDevice = device
        }
        .onTapGesture {
            // Single tap selects row (or toggles checkbox in multi-select mode)
            if isMultiSelectMode {
                toggleSelection(device)
            } else {
                selectedAssetTag = device.assetTag
            }
        }
    }
    
    // MARK: - Selection Helpers
    func toggleSelection(_ device: Device) {
        guard let id = device.id else { return }
        if selectedDeviceIds.contains(id) {
            selectedDeviceIds.remove(id)
        } else {
            selectedDeviceIds.insert(id)
        }
    }
    
    func toggleSelectAll() {
        let ids = Set(filteredDevices.compactMap { $0.id })
        if ids.isSubset(of: selectedDeviceIds) {
            // Deselect all filtered
            selectedDeviceIds.subtract(ids)
        } else {
            // Select all filtered
            selectedDeviceIds.formUnion(ids)
        }
    }
    
    // MARK: - Actions
    func loadDevices() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let resp = try await APIService.shared.getDevices(
                    eventId: appState.currentEvent?.id,
                    status: filterStatus?.rawValue,
                    category: filterCategory.isEmpty ? nil : filterCategory,
                    model: filterModel.isEmpty ? nil : filterModel,
                    sku: filterSku.isEmpty ? nil : filterSku,
                    locationId: filterCurrentLocation?.id,
                    assignedLocationId: filterAssignedLocation?.id,
                    limit: 1000
                )
                await MainActor.run {
                    devices = resp.devices
                    totalCount = resp.total ?? resp.devices.count
                    isLoading = false
                    errorMessage = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Load failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    func performBulkDelete() {
        isDeleting = true
        let idsToDelete = Array(selectedDeviceIds)
        
        Task {
            var successCount = 0
            var failCount = 0
            
            for id in idsToDelete {
                do {
                    let _ = try await APIService.shared.deleteDevice(id: id)
                    successCount += 1
                } catch {
                    failCount += 1
                }
            }
            
            await MainActor.run {
                selectedDeviceIds.removeAll()
                isDeleting = false
                
                if failCount == 0 {
                    deleteResult = "Successfully deleted \(successCount) devices."
                } else {
                    deleteResult = "Deleted \(successCount) devices. \(failCount) failed."
                }
                showDeleteResult = true
                loadDevices()
            }
        }
    }
    
    func createNewLocation() {
        let name = newLocationName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        
        Task {
            do {
                let eventId = appState.currentEvent?.id
                let resp = try await APIService.shared.createLocation(name: name, eventId: eventId)
                let returnedName = resp.name ?? name
                let newLoc = Location(id: resp.id, name: returnedName, eventId: eventId, deviceCount: 0, assignedDeviceCount: 0, createdAt: nil)
                await MainActor.run {
                    appState.locations.removeAll { $0.id == newLoc.id }
                    appState.locations.append(newLoc)
                    appState.locations.sort { $0.name < $1.name }
                    // Find from updated array to ensure picker tag match
                    let matched = appState.locations.first(where: { $0.id == newLoc.id }) ?? newLoc
                    if newLocationTarget == "assigned" {
                        moveAssignedLocation = matched
                    } else {
                        moveCurrentLocation = matched
                    }
                    showNewLocationSheet = false
                    newLocationName = ""
                }
            } catch {
                await MainActor.run {
                    showNewLocationSheet = false
                }
            }
        }
    }
    
    func executeMoveSelected() {
        guard moveToEvent != nil || moveAssignedLocation != nil || moveCurrentLocation != nil else { return }
        isMoving = true
        
        // Get asset tags for selected device IDs
        let selectedTags = devices.filter { device in
            guard let id = device.id else { return false }
            return selectedDeviceIds.contains(id)
        }.map { $0.assetTag }
        
        Task {
            do {
                let result = try await APIService.shared.bulkMove(
                    assetTags: selectedTags,
                    toLocationId: moveCurrentLocation?.id,
                    toAssignedLocationId: moveAssignedLocation?.id,
                    toEventId: moveToEvent?.id,
                    toPersonId: nil,
                    notes: ""
                )
                await MainActor.run {
                    let moved = result.results?.moved ?? 0
                    moveResult = "Successfully moved \(moved) devices."
                    if let nf = result.results?.notFound, !nf.isEmpty {
                        moveResult += "\nNot found: \(nf.joined(separator: ", "))"
                    }
                    showMoveResult = true
                    showMovePanel = false
                    moveToEvent = nil
                    moveAssignedLocation = nil
                    moveCurrentLocation = nil
                    selectedDeviceIds.removeAll()
                    isMoving = false
                    loadDevices()
                }
            } catch {
                await MainActor.run {
                    moveResult = "Error: \(error.localizedDescription)"
                    showMoveResult = true
                    isMoving = false
                }
            }
        }
    }
}

// MARK: - Device Edit Sheet
struct DeviceEditSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    let device: Device
    let onSave: () -> Void
    
    @State private var category: String
    @State private var model: String
    @State private var sku: String
    @State private var status: DeviceStatus
    @State private var selectedLocation: Location?
    @State private var selectedAssignedLocation: Location?
    @State private var selectedPerson: Person?
    @State private var account: String
    @State private var liveOrDummy: String
    @State private var notes: String
    @State private var customFields: [(key: String, value: String)]
    @State private var newCustomFieldName = ""
    @State private var newCustomFieldValue = ""
    @State private var isSaving = false
    
    init(device: Device, onSave: @escaping () -> Void) {
        self.device = device
        self.onSave = onSave
        _category = State(initialValue: device.category ?? "")
        _model = State(initialValue: device.model ?? "")
        _sku = State(initialValue: device.sku ?? "")
        _status = State(initialValue: device.status)
        _account = State(initialValue: device.account ?? "")
        _liveOrDummy = State(initialValue: device.liveOrDummy ?? "N/A")
        _notes = State(initialValue: device.notes ?? "")
        
        var cf: [(key: String, value: String)] = []
        if let customData = device.customData {
            for (key, value) in customData.sorted(by: { $0.key < $1.key }) {
                cf.append((key: key, value: value))
            }
        }
        _customFields = State(initialValue: cf)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("Edit Device")
                        .font(AppTheme.headingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    CopyableAssetTag(assetTag: device.assetTag)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Standard Fields
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Standard Fields")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            editFieldRow("Category", $category)
                            editFieldRow("Model", $model)
                            editFieldRow("SKU / Style", $sku)
                            
                            HStack {
                                Text("Status")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $status) {
                                    ForEach(DeviceStatus.allCases, id: \.self) { s in
                                        Text(s.rawValue).tag(s)
                                    }
                                }
                                .frame(width: 180)
                            }
                            
                            HStack {
                                Text("Current Location")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $selectedLocation) {
                                    Text("-- None --").tag(nil as Location?)
                                    ForEach(appState.locations, id: \.id) { loc in
                                        Text(loc.name).tag(Optional(loc))
                                    }
                                }
                                .frame(width: 180)
                            }
                            
                            HStack {
                                Text("Assigned Location")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $selectedAssignedLocation) {
                                    Text("-- None --").tag(nil as Location?)
                                    ForEach(appState.locations, id: \.id) { loc in
                                        Text(loc.name).tag(Optional(loc))
                                    }
                                }
                                .frame(width: 180)
                            }
                            
                            HStack {
                                Text("Assigned To")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $selectedPerson) {
                                    Text("-- None --").tag(nil as Person?)
                                    ForEach(appState.people, id: \.id) { p in
                                        Text(p.name).tag(Optional(p))
                                    }
                                }
                                .frame(width: 180)
                            }
                            
                            editFieldRow("Account", $account)
                            
                            HStack {
                                Text("Live/Dummy")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                    .frame(width: 100, alignment: .trailing)
                                Picker("", selection: $liveOrDummy) {
                                    Text("N/A").tag("N/A")
                                    Text("Live").tag("Live")
                                    Text("Dummy").tag("Dummy")
                                }
                                .frame(width: 180)
                            }
                            
                            editFieldRow("Notes", $notes)
                        }
                        .glowCardStyle()
                        
                        // Custom Fields
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Custom Fields")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            
                            if customFields.isEmpty {
                                Text("No custom fields")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                            } else {
                                ForEach(Array(customFields.enumerated()), id: \.offset) { index, field in
                                    HStack {
                                        Text(field.key)
                                            .font(AppTheme.captionFont)
                                            .foregroundColor(AppTheme.textMuted)
                                            .frame(width: 100, alignment: .trailing)
                                        TextField(field.key, text: Binding(
                                            get: { customFields[index].value },
                                            set: { customFields[index].value = $0 }
                                        ))
                                        .darkTextField()
                                        .frame(width: 180)
                                        Button(action: { customFields.remove(at: index) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(AppTheme.statusMissing)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            // Add new
                            HStack {
                                TextField("Field Name", text: $newCustomFieldName)
                                    .darkTextField()
                                    .frame(width: 100)
                                TextField("Value", text: $newCustomFieldValue)
                                    .darkTextField()
                                    .frame(width: 150)
                                Button(action: {
                                    if !newCustomFieldName.isEmpty {
                                        customFields.append((key: newCustomFieldName, value: newCustomFieldValue))
                                        newCustomFieldName = ""
                                        newCustomFieldValue = ""
                                    }
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(AppTheme.statusAvailable)
                                }
                                .buttonStyle(.plain)
                                .disabled(newCustomFieldName.isEmpty)
                            }
                        }
                        .glowCardStyle()
                    }
                    .padding(.horizontal)
                }
                
                // Buttons
                HStack {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    Button(action: saveDevice) {
                        HStack(spacing: 6) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            }
                            Text("Save")
                        }
                        .primaryButton()
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .padding()
            }
        }
        .frame(width: 500, height: 550)
        .onAppear {
            selectedLocation = appState.locations.first { $0.id == device.locationId }
            selectedAssignedLocation = appState.locations.first { $0.id == device.assignedLocationId }
            selectedPerson = appState.people.first { $0.id == device.assignedToId }
        }
    }
    
    func editFieldRow(_ label: String, _ value: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 100, alignment: .trailing)
            TextField(label, text: value)
                .darkTextField()
                .frame(width: 180)
        }
    }
    
    func saveDevice() {
        guard let id = device.id else { return }
        isSaving = true
        
        var updates: [String: Any] = [
            "category": category,
            "model": model,
            "sku": sku,
            "status": status.rawValue,
            "account": account,
            "live_or_dummy": liveOrDummy,
            "notes": notes
        ]
        if let locId = selectedLocation?.id { updates["location_id"] = locId }
        if let assignedLocId = selectedAssignedLocation?.id { updates["assigned_location_id"] = assignedLocId }
        if let personId = selectedPerson?.id { updates["assigned_to_id"] = personId }
        
        var customDataDict: [String: String] = [:]
        for field in customFields {
            if !field.key.isEmpty {
                customDataDict[field.key] = field.value
            }
        }
        updates["custom_data"] = customDataDict
        
        Task {
            do {
                let _ = try await APIService.shared.updateDevice(id: id, updates: updates)
                onSave()
                dismiss()
            } catch {
                print("Error saving: \(error)")
            }
            isSaving = false
        }
    }
}
