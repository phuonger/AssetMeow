import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    @AppStorage("serverURL") private var serverURL = "https://inventory.tpgeng.net/api.php"
    @AppStorage("apiKey") private var apiKey = ""
    
    @State private var testResult = ""
    @State private var isTesting = false
    
    // Event management
    @State private var newEventName = ""
    @State private var newLocationName = ""
    @State private var newPersonName = ""
    @State private var newPersonRole = ""
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            TabView {
                // Connection tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Server Connection")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Server URL")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            TextField("https://inventory.tpgeng.net/api.php", text: $serverURL)
                                .textFieldStyle(.roundedBorder)
                            Text("The full URL to your api.php file")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("API Key")
                                .font(AppTheme.subheadingFont)
                                .foregroundColor(AppTheme.textPrimary)
                            SecureField("Your API key", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                            Text("Must match the API_KEY in your config.php on the server")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: testConnection) {
                                HStack(spacing: 6) {
                                    Image(systemName: "antenna.radiowaves.left.and.right")
                                    Text("Test Connection")
                                }
                                .primaryButton()
                            }
                            .buttonStyle(.plain)
                            .disabled(isTesting)
                            
                            if isTesting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                                    .scaleEffect(0.7)
                            }
                            
                            if !testResult.isEmpty {
                                Text(testResult)
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(testResult.contains("Success") ? AppTheme.statusAvailable : AppTheme.statusMissing)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                }
                .tabItem { Label("Connection", systemImage: "network") }
                
                // Events & Locations tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Manage Data")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        
                        // Events with nested Locations
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(AppTheme.primaryPurpleLight)
                                Text("Events & Locations")
                                    .font(AppTheme.headingFont)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            Text("Locations are scoped to each event. Expand an event to manage its locations.")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(appState.events, id: \.id) { event in
                                    EventLocationRow(event: event, newLocationName: "", appState: appState)
                                }
                                
                                Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
                                    .padding(.vertical, 4)
                                
                                HStack {
                                    TextField("New event name", text: $newEventName)
                                        .textFieldStyle(.roundedBorder)
                                    Button("Add") {
                                        Task {
                                            if let _ = await appState.createEvent(name: newEventName) {
                                                newEventName = ""
                                            }
                                        }
                                    }
                                    .disabled(newEventName.isEmpty)
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 8)
                            }
                            .padding(12)
                            .background(AppTheme.backgroundDark)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                            )
                        }
                        
                        // People
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(AppTheme.accentOrange)
                                Text("People")
                                    .font(AppTheme.headingFont)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                ScrollView {
                                    ForEach(appState.people, id: \.id) { person in
                                        HStack {
                                            Text(person.name)
                                                .font(AppTheme.bodyFont)
                                                .foregroundColor(AppTheme.textSecondary)
                                            if let role = person.role {
                                                Text("(\(role))")
                                                    .font(AppTheme.captionFont)
                                                    .foregroundColor(AppTheme.textMuted)
                                            }
                                            Spacer()
                                            Text("\(person.deviceCount ?? 0)")
                                                .font(AppTheme.captionFont)
                                                .foregroundColor(AppTheme.textMuted)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                                .frame(maxHeight: 120)
                                
                                Rectangle().fill(AppTheme.surfaceBorder).frame(height: 1)
                                
                                HStack {
                                    TextField("Name", text: $newPersonName)
                                        .textFieldStyle(.roundedBorder)
                                    TextField("Role (optional)", text: $newPersonRole)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 120)
                                    Button("Add") {
                                        Task {
                                            if let _ = await appState.createPerson(name: newPersonName, role: newPersonRole.isEmpty ? nil : newPersonRole) {
                                                newPersonName = ""
                                                newPersonRole = ""
                                            }
                                        }
                                    }
                                    .disabled(newPersonName.isEmpty)
                                }
                            }
                            .padding(12)
                            .background(AppTheme.backgroundDark)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
                            )
                        }
                        
                        Spacer()
                    }
                    .padding(20)
                }
                .tabItem { Label("Data", systemImage: "folder") }
            }
        }
        .frame(width: 600, height: 550)
    }
    
    func testConnection() {
        isTesting = true
        testResult = ""
        Task {
            await appState.testConnection()
            testResult = appState.isConnected ? "Success! Connected." : "Failed: \(appState.statusMessage)"
            isTesting = false
        }
    }
}

// MARK: - Event Location Row (expandable)
struct EventLocationRow: View {
    let event: Event
    @State var newLocationName: String
    @ObservedObject var appState: AppState
    
    @State private var isExpanded = false
    @State private var eventLocations: [Location] = []
    @State private var isLoadingLocations = false
    @State private var showDeleteEventConfirm = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event header row
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                    if isExpanded && eventLocations.isEmpty {
                        loadLocations()
                    }
                }) {
                    HStack {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(AppTheme.textMuted)
                            .frame(width: 16)
                        Image(systemName: "calendar")
                            .foregroundColor(AppTheme.primaryPurpleLight)
                            .font(.system(size: 12))
                        Text(event.name)
                            .font(AppTheme.bodyFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Text("\(event.deviceCount ?? 0) devices")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Delete event button (only if 0 devices)
                if (event.deviceCount ?? 0) == 0 {
                    Button(action: {
                        showDeleteEventConfirm = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(AppTheme.statusMissing.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Delete event")
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .alert("Delete Event?", isPresented: $showDeleteEventConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        if let eventId = event.id {
                            let _ = await appState.deleteEvent(id: eventId)
                        }
                    }
                }
            } message: {
                Text("Are you sure you want to delete \"\(event.name)\"? This cannot be undone.")  
            }
            
            // Expanded locations list
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    if isLoadingLocations {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                                .scaleEffect(0.6)
                            Text("Loading locations...")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                        }
                        .padding(.leading, 40)
                    } else {
                        ForEach(eventLocations, id: \.id) { loc in
                            HStack {
                                Image(systemName: "mappin")
                                    .font(.system(size: 10))
                                    .foregroundColor(AppTheme.accentCyan)
                                Text(loc.name)
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textSecondary)
                                Spacer()
                                Text("\(loc.deviceCount ?? 0)")
                                    .font(AppTheme.captionFont)
                                    .foregroundColor(AppTheme.textMuted)
                                // Delete location button (only if 0 devices)
                                if (loc.deviceCount ?? 0) == 0 {
                                    Button(action: {
                                        Task {
                                            if let locId = loc.id {
                                                if await appState.deleteLocation(id: locId) {
                                                    eventLocations.removeAll { $0.id == loc.id }
                                                }
                                            }
                                        }
                                    }) {
                                        Image(systemName: "trash")
                                            .font(.system(size: 10))
                                            .foregroundColor(AppTheme.statusMissing.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Delete location")
                                }
                            }
                            .padding(.vertical, 3)
                            .padding(.leading, 40)
                            .padding(.trailing, 8)
                        }
                        
                        if eventLocations.isEmpty {
                            Text("No locations yet")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textMuted)
                                .italic()
                                .padding(.leading, 40)
                        }
                    }
                    
                    // Add new location for this event
                    HStack {
                        TextField("New location", text: $newLocationName)
                            .textFieldStyle(.roundedBorder)
                            .font(AppTheme.captionFont)
                        Button("Add") {
                            Task {
                                if let newLoc = await appState.createLocation(name: newLocationName, forEventId: event.id) {
                                    eventLocations.append(newLoc)
                                    eventLocations.sort { $0.name < $1.name }
                                    newLocationName = ""
                                }
                            }
                        }
                        .font(AppTheme.captionFont)
                        .disabled(newLocationName.isEmpty)
                    }
                    .padding(.leading, 40)
                    .padding(.trailing, 8)
                    .padding(.top, 4)
                }
                .padding(.bottom, 8)
                .background(AppTheme.surfaceDefault.opacity(0.3))
            }
            
            Rectangle().fill(AppTheme.surfaceBorder.opacity(0.5)).frame(height: 1)
        }
    }
    
    private func loadLocations() {
        isLoadingLocations = true
        Task {
            eventLocations = await appState.loadLocationsForEvent(event.id)
            isLoadingLocations = false
        }
    }
}
