import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var currentEvent: Event?
    @Published var events: [Event] = []
    @Published var locations: [Location] = []
    @Published var people: [Person] = []
    @Published var isConnected = false
    @Published var isNetworkActive = false
    @Published var statusMessage = ""
    @Published var isLoading = false
    
    // Navigation intent — used to navigate from Dashboard to Inventory with filters
    @Published var inventoryFilterIntent: InventoryFilterIntent?
    @Published var navigateToTab: String?  // Tab name to navigate to
    
    // Auth state
    @Published var isLoggedIn = false
    @Published var currentUser: AppUser?
    @Published var loginError: String?
    
    // Station/Kiosk mode
    @Published var isStationMode = false
    @Published var stationSessionActive = false
    @Published var stationTimeRemaining: Int = 300 // 5 minutes in seconds
    private var stationTimer: Timer?
    
    private let api = APIService.shared
    private let toast = ToastManager.shared
    
    init() {
        // Check if we have a saved auth token
        if api.isLoggedIn {
            isLoggedIn = true
            currentUser = api.currentUser
            Task { await verifySession() }
        }
    }
    
    // MARK: - Auth
    func login(username: String, password: String) async -> Bool {
        isLoading = true
        loginError = nil
        
        do {
            let response = try await api.login(username: username, password: password)
            if response.success == true, let user = response.user {
                isLoggedIn = true
                currentUser = user
                await loadInitialData()
                isLoading = false
                return true
            } else {
                loginError = response.error ?? "Login failed"
                isLoading = false
                return false
            }
        } catch {
            loginError = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func logout() async {
        await api.logout()
        isLoggedIn = false
        currentUser = nil
        events = []
        locations = []
        people = []
        isConnected = false
        // If in station mode, keep station mode active but end session
        if isStationMode {
            stationSessionActive = false
            stationTimer?.invalidate()
            stationTimer = nil
            stationTimeRemaining = 300
        }
    }
    
    // MARK: - Station/Kiosk Mode
    
    func enterStationMode() {
        isStationMode = true
        // Log out current user to show badge login screen
        Task {
            await api.logout()
            isLoggedIn = false
            currentUser = nil
            stationSessionActive = false
            stationTimeRemaining = 300
        }
    }
    
    func exitStationMode() {
        isStationMode = false
        stationSessionActive = false
        stationTimer?.invalidate()
        stationTimer = nil
        stationTimeRemaining = 300
        // Log out to show normal login
        Task {
            await api.logout()
            isLoggedIn = false
            currentUser = nil
        }
    }
    
    func badgeLogin(badgeId: String) async -> Bool {
        isLoading = true
        loginError = nil
        
        do {
            let response = try await api.badgeLogin(badgeId: badgeId)
            if response.success == true, let user = response.user {
                isLoggedIn = true
                currentUser = user
                stationSessionActive = true
                stationTimeRemaining = 300
                startStationTimer()
                await loadInitialData()
                isLoading = false
                return true
            } else {
                loginError = response.error ?? "Badge not recognized"
                isLoading = false
                return false
            }
        } catch let error as APIError {
            switch error {
            case .serverError(_, let msg):
                loginError = msg
            default:
                loginError = error.localizedDescription
            }
            isLoading = false
            return false
        } catch {
            loginError = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func resetStationTimer() {
        stationTimeRemaining = 300
    }
    
    func endStationSession() async {
        stationTimer?.invalidate()
        stationTimer = nil
        stationTimeRemaining = 300
        stationSessionActive = false
        await api.logout()
        isLoggedIn = false
        currentUser = nil
    }
    
    private func startStationTimer() {
        stationTimer?.invalidate()
        stationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.stationTimeRemaining > 0 {
                    self.stationTimeRemaining -= 1
                } else {
                    // Session expired
                    self.stationTimer?.invalidate()
                    self.stationTimer = nil
                    self.stationTimeRemaining = 300
                    self.stationSessionActive = false
                    await self.api.logout()
                    self.isLoggedIn = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    func changePassword(current: String, new: String) async -> (Bool, String) {
        do {
            let response = try await api.changePassword(currentPassword: current, newPassword: new)
            if response.success == true {
                toast.success("Password Changed", detail: "Your password has been updated successfully.")
                return (true, "Password changed successfully!")
            } else {
                let msg = response.error ?? "Failed to change password"
                toast.error("Password Change Failed", detail: msg)
                return (false, msg)
            }
        } catch {
            toast.error("Connection Error", detail: "Could not reach server: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }
    
    private func verifySession() async {
        do {
            let response = try await api.getCurrentUser()
            if let user = response.user {
                currentUser = user
                isLoggedIn = true
                await loadInitialData()
            } else {
                // Token expired
                await logout()
            }
        } catch {
            // Token invalid, clear session
            await logout()
        }
    }
    
    // MARK: - Data Loading
    func loadInitialData(selectEventId: Int? = nil) async {
        isNetworkActive = true
        do {
            let eventsResp = try await api.getEvents()
            events = eventsResp.events
            
            if let selectId = selectEventId ?? UserDefaults.standard.object(forKey: "currentEventId") as? Int {
                currentEvent = events.first { $0.id == selectId }
            }
            
            await loadLocationsAndPeople()
            isConnected = true
            statusMessage = "Connected"
        } catch {
            isConnected = false
            statusMessage = "Not connected: \(error.localizedDescription)"
            toast.error("Connection Failed", detail: "Unable to load data from server.")
        }
        isNetworkActive = false
    }
    
    func loadLocationsAndPeople() async {
        do {
            let locResp = try await api.getLocations(eventId: currentEvent?.id)
            locations = locResp.locations
            
            let pplResp = try await api.getPeople(eventId: currentEvent?.id)
            people = pplResp.people
        } catch {
            print("Error loading locations/people: \(error)")
        }
    }
    
    func selectEvent(_ event: Event?) {
        currentEvent = event
        if let id = event?.id {
            UserDefaults.standard.set(id, forKey: "currentEventId")
        } else {
            UserDefaults.standard.removeObject(forKey: "currentEventId")
        }
        Task { await loadLocationsAndPeople() }
    }
    
    // MARK: - Create Location
    func createLocation(name: String) async -> Location? {
        return await createLocation(name: name, forEventId: currentEvent?.id)
    }
    
    func createLocation(name: String, forEventId eventId: Int?) async -> Location? {
        // Pre-check: verify connectivity
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot create location while offline. Check your connection.")
            return nil
        }
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            toast.warning("Invalid Name", detail: "Location name cannot be empty.")
            return nil
        }
        
        do {
            let resp = try await api.createLocation(name: name, eventId: eventId)
            if resp.success == true, let id = resp.id {
                // Use the backend-returned name (uppercased) to stay consistent
                let returnedName = resp.name ?? name
                let newLoc = Location(id: id, name: returnedName, eventId: eventId, deviceCount: 0, createdAt: nil)
                // Remove any existing location with same id (handles "existing" case from backend)
                locations.removeAll { $0.id == id }
                locations.append(newLoc)
                locations.sort { $0.name < $1.name }
                
                // Confirm write success
                toast.success("Location Saved", detail: "\"\(returnedName)\" written to database (ID: \(id)).")
                return newLoc
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                statusMessage = "Error creating location: \(errorMsg)"
                toast.error("Failed to Create Location", detail: errorMsg)
            }
        } catch {
            statusMessage = "Error creating location: \(error.localizedDescription)"
            toast.error("Connection Error", detail: "Could not save location: \(error.localizedDescription)")
        }
        return nil
    }
    
    func loadLocationsForEvent(_ eventId: Int?) async -> [Location] {
        do {
            let locResp = try await api.getLocations(eventId: eventId)
            return locResp.locations
        } catch {
            print("Error loading locations for event: \(error)")
            return []
        }
    }
    
    // MARK: - Create Person
    func createPerson(name: String, role: String? = nil) async -> Person? {
        // Pre-check: verify connectivity
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot create person while offline. Check your connection.")
            return nil
        }
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            toast.warning("Invalid Name", detail: "Person name cannot be empty.")
            return nil
        }
        
        do {
            let resp = try await api.createPerson(name: name, role: role, eventId: currentEvent?.id)
            if resp.success == true, let id = resp.id {
                // Use the backend-returned name (uppercased) to stay consistent
                let returnedName = resp.name ?? name
                let newPerson = Person(id: id, name: returnedName, role: role != nil ? role!.uppercased() : nil, email: nil, eventId: currentEvent?.id, deviceCount: 0, createdAt: nil)
                // Remove any existing person with same id (handles "existing" case from backend)
                people.removeAll { $0.id == id }
                people.append(newPerson)
                people.sort { $0.name < $1.name }
                
                // Confirm write success
                toast.success("Person Saved", detail: "\"\(returnedName)\" written to database (ID: \(id)).")
                return newPerson
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                statusMessage = "Error creating person: \(errorMsg)"
                toast.error("Failed to Create Person", detail: errorMsg)
            }
        } catch {
            statusMessage = "Error creating person: \(error.localizedDescription)"
            toast.error("Connection Error", detail: "Could not save person: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Create Event
    func createEvent(name: String) async -> Event? {
        // Pre-check: verify connectivity
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot create event while offline. Check your connection.")
            return nil
        }
        
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
            toast.warning("Invalid Name", detail: "Event name cannot be empty.")
            return nil
        }
        
        do {
            let resp = try await api.createEvent(name: name)
            if resp.success == true, let id = resp.id {
                let returnedName = resp.name ?? name
                let newEvent = Event(id: id, name: returnedName, startDate: nil, endDate: nil, deviceCount: 0, createdAt: nil)
                events.removeAll { $0.id == id }
                events.append(newEvent)
                
                // Confirm write success
                toast.success("Event Saved", detail: "\"\(returnedName)\" written to database (ID: \(id)).")
                return newEvent
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                statusMessage = "Error creating event: \(errorMsg)"
                toast.error("Failed to Create Event", detail: errorMsg)
            }
        } catch {
            statusMessage = "Error creating event: \(error.localizedDescription)"
            toast.error("Connection Error", detail: "Could not save event: \(error.localizedDescription)")
        }
        return nil
    }
    
    // MARK: - Delete Event
    func deleteEvent(id: Int) async -> Bool {
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot delete event while offline.")
            return false
        }
        do {
            let resp = try await api.deleteEvent(id: id)
            if resp.success == true {
                events.removeAll { $0.id == id }
                toast.success("Event Deleted", detail: "Event removed successfully.")
                return true
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                toast.error("Failed to Delete Event", detail: errorMsg)
            }
        } catch {
            toast.error("Connection Error", detail: "Could not delete event: \(error.localizedDescription)")
        }
        return false
    }
    
    // MARK: - Delete Location
    func deleteLocation(id: Int) async -> Bool {
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot delete location while offline.")
            return false
        }
        do {
            let resp = try await api.deleteLocation(id: id)
            if resp.success == true {
                toast.success("Location Deleted", detail: "Location removed successfully.")
                return true
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                toast.error("Failed to Delete Location", detail: errorMsg)
            }
        } catch {
            toast.error("Connection Error", detail: "Could not delete location: \(error.localizedDescription)")
        }
        return false
    }
    
    // MARK: - Delete Person
    func deletePerson(id: Int) async -> Bool {
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot delete person while offline.")
            return false
        }
        do {
            let resp = try await api.deletePerson(id: id)
            if resp.success == true {
                people.removeAll { $0.id == id }
                toast.success("Person Deleted", detail: "Person removed successfully.")
                return true
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                toast.error("Failed to Delete Person", detail: errorMsg)
            }
        } catch {
            toast.error("Connection Error", detail: "Could not delete person: \(error.localizedDescription)")
        }
        return false
    }
    
    // MARK: - Update Person
    func updatePerson(id: Int, name: String?, role: String?) async -> Bool {
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot update person while offline.")
            return false
        }
        do {
            let resp = try await api.updatePerson(id: id, name: name, role: role)
            if resp.success == true {
                if let idx = people.firstIndex(where: { $0.id == id }) {
                    if let newName = name { people[idx].name = newName.uppercased() }
                    if let newRole = role { people[idx].role = newRole.isEmpty ? nil : newRole.uppercased() }
                }
                toast.success("Person Updated", detail: "Person updated successfully.")
                return true
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                toast.error("Failed to Update Person", detail: errorMsg)
            }
        } catch {
            toast.error("Connection Error", detail: "Could not update person: \(error.localizedDescription)")
        }
        return false
    }
    
    // MARK: - Update Location
    func updateLocation(id: Int, name: String) async -> Bool {
        guard isConnected else {
            toast.error("No Connection", detail: "Cannot update location while offline.")
            return false
        }
        do {
            let resp = try await api.updateLocation(id: id, name: name)
            if resp.success == true {
                toast.success("Location Updated", detail: "Location renamed successfully.")
                return true
            } else {
                let errorMsg = resp.error ?? "Unknown error"
                toast.error("Failed to Update Location", detail: errorMsg)
            }
        } catch {
            toast.error("Connection Error", detail: "Could not update location: \(error.localizedDescription)")
        }
        return false
    }
    
    // MARK: - Connection Test
    func testConnection() async {
        isLoading = true
        isNetworkActive = true
        do {
            let _ = try await api.testConnection()
            isConnected = true
            statusMessage = "Connected successfully!"
            toast.success("Connected", detail: "Successfully connected to the database server.")
            await loadInitialData()
        } catch {
            isConnected = false
            statusMessage = "Connection failed: \(error.localizedDescription)"
            toast.error("Connection Failed", detail: error.localizedDescription)
        }
        isLoading = false
        isNetworkActive = false
    }
}

// MARK: - Navigation Intent for Dashboard → Inventory
struct InventoryFilterIntent {
    var status: DeviceStatus?
    var category: String?
    var assignedLocationName: String?
    var currentLocationName: String?
    var isUnassigned: Bool = false
    
    var description: String {
        var parts: [String] = []
        if let status = status { parts.append("Status: \(status.rawValue)") }
        if let cat = category { parts.append("Category: \(cat)") }
        if let loc = assignedLocationName { parts.append("Location: \(loc)") }
        if isUnassigned { parts.append("Unassigned") }
        return parts.joined(separator: ", ")
    }
}
