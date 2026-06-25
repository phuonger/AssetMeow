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
    
    // Auth state
    @Published var isLoggedIn = false
    @Published var currentUser: AppUser?
    @Published var loginError: String?
    
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
