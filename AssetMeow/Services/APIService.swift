import Foundation

class APIService {
    static let shared = APIService()
    
    private var baseURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? "https://inventory.tpgeng.net/api.php"
    }
    
    private var apiKey: String {
        UserDefaults.standard.string(forKey: "apiKey") ?? ""
    }
    
    // Auth token stored in UserDefaults
    var authToken: String? {
        get { UserDefaults.standard.string(forKey: "authToken") }
        set { UserDefaults.standard.set(newValue, forKey: "authToken") }
    }
    
    var currentUser: AppUser? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "currentUser") else { return nil }
            return try? JSONDecoder().decode(AppUser.self, from: data)
        }
        set {
            if let user = newValue, let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: "currentUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentUser")
            }
        }
    }
    
    var isLoggedIn: Bool {
        return authToken != nil && currentUser != nil
    }
    
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }
    
    // MARK: - Generic Request
    private func request<T: Codable>(_ endpoint: String, method: String = "GET", body: [String: Any]? = nil, queryParams: [String: String]? = nil) async throws -> T {
        var urlString = "\(baseURL)?action=\(endpoint)"
        
        if let params = queryParams {
            for (key, value) in params {
                urlString += "&\(key)=\(value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value)"
            }
        }
        
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        // Add auth token if available
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw APIError.unauthorized
        }
        
        if httpResponse.statusCode >= 400 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw APIError.serverError(httpResponse.statusCode, errorMsg)
        }
        
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            let rawJSON = String(data: data, encoding: .utf8) ?? "no data"
            print("Decode error for \(endpoint): \(error)\nRaw: \(rawJSON)")
            throw APIError.decodingError("\(error.localizedDescription)")
        }
    }
    
    // MARK: - Auth
    func login(username: String, password: String) async throws -> LoginResponse {
        let body: [String: Any] = ["username": username, "password": password]
        let response: LoginResponse = try await request("auth/login", method: "POST", body: body)
        
        if let token = response.token, let user = response.user {
            self.authToken = token
            self.currentUser = user
        }
        
        return response
    }
    
    func logout() async {
        // Try to invalidate on server
        if authToken != nil {
            let _: GenericResponse? = try? await request("auth/logout", method: "POST")
        }
        authToken = nil
        currentUser = nil
    }
    
    func getCurrentUser() async throws -> LoginResponse {
        return try await request("auth/me")
    }
    
    func changePassword(currentPassword: String, newPassword: String) async throws -> ChangePasswordResponse {
        let body: [String: Any] = ["current_password": currentPassword, "new_password": newPassword]
        return try await request("auth/change-password", method: "POST", body: body)
    }
    
    // MARK: - User Management (Admin only)
    func getUsers() async throws -> UsersResponse {
        return try await request("users")
    }
    
    func createUser(username: String, password: String, role: String) async throws -> GenericResponse {
        let body: [String: Any] = ["username": username, "password": password, "role": role]
        return try await request("users", method: "POST", body: body)
    }
    
    func updateUser(id: Int, updates: [String: Any]) async throws -> GenericResponse {
        return try await request("users", method: "PUT", body: updates, queryParams: ["id": "\(id)"])
    }
    
    func deleteUser(id: Int) async throws -> GenericResponse {
        return try await request("users", method: "DELETE", queryParams: ["id": "\(id)"])
    }
    
    func resetUserPassword(id: Int, newPassword: String) async throws -> GenericResponse {
        let body: [String: Any] = ["id": id, "new_password": newPassword]
        return try await request("users/reset-password", method: "POST", body: body)
    }
    
    // MARK: - Devices
    func getDevices(eventId: Int? = nil, status: String? = nil, category: String? = nil, model: String? = nil, sku: String? = nil, locationId: Int? = nil, assignedLocationId: Int? = nil, limit: Int = 1000, offset: Int = 0) async throws -> DevicesResponse {
        var params: [String: String] = ["limit": "\(limit)", "offset": "\(offset)"]
        if let eventId = eventId { params["event_id"] = "\(eventId)" }
        if let status = status { params["status"] = status }
        if let category = category { params["category"] = category }
        if let model = model { params["model"] = model }
        if let sku = sku { params["sku"] = sku }
        if let locationId = locationId { params["location_id"] = "\(locationId)" }
        if let assignedLocationId = assignedLocationId { params["assigned_location_id"] = "\(assignedLocationId)" }
        return try await request("devices", queryParams: params)
    }
    
    func searchDevices(query: String? = nil, tags: String? = nil) async throws -> DevicesResponse {
        var params: [String: String] = [:]
        if let query = query { params["q"] = query }
        if let tags = tags { params["tags"] = tags }
        return try await request("devices/search", queryParams: params)
    }
    
    func lookupDevice(assetTag: String) async throws -> LookupResponse {
        return try await request("devices/lookup", queryParams: ["asset_tag": assetTag])
    }
    
    func createDevice(_ device: [String: Any]) async throws -> GenericResponse {
        return try await request("devices", method: "POST", body: device)
    }
    
    func updateDevice(id: Int, updates: [String: Any]) async throws -> GenericResponse {
        return try await request("devices", method: "PUT", body: updates, queryParams: ["id": "\(id)"])
    }
    
    func deleteDevice(id: Int) async throws -> GenericResponse {
        return try await request("devices", method: "DELETE", queryParams: ["id": "\(id)"])
    }
    
    // MARK: - Validate (check which tags exist)
    func validateDevices(assetTags: [String]) async throws -> ValidateResponse {
        let body: [String: Any] = ["asset_tags": assetTags]
        return try await request("devices/validate", method: "POST", body: body)
    }
    
    // MARK: - Bulk Create (create new devices before checkout)
    func bulkCreate(devices: [[String: Any]], eventId: Int?) async throws -> BulkResult {
        var body: [String: Any] = ["devices": devices]
        if let eventId = eventId { body["event_id"] = eventId }
        return try await request("devices/bulk-create", method: "POST", body: body)
    }
    
    // MARK: - Bulk Operations
    func bulkCheckout(assetTags: [String], locationId: Int?, personId: Int?, eventId: Int?, notes: String = "") async throws -> BulkResult {
        var body: [String: Any] = ["asset_tags": assetTags, "notes": notes]
        if let locationId = locationId { body["location_id"] = locationId }
        if let personId = personId { body["person_id"] = personId }
        if let eventId = eventId { body["event_id"] = eventId }
        return try await request("devices/bulk-checkout", method: "POST", body: body)
    }
    
    func bulkCheckin(assetTags: [String], locationId: Int?, assignedLocationId: Int? = nil, notes: String = "") async throws -> BulkResult {
        var body: [String: Any] = ["asset_tags": assetTags, "notes": notes]
        if let locationId = locationId { body["location_id"] = locationId }
        if let assignedLocationId = assignedLocationId { body["assigned_location_id"] = assignedLocationId }
        return try await request("devices/bulk-checkin", method: "POST", body: body)
    }
    
    func bulkMove(assetTags: [String]? = nil, deviceIds: [Int]? = nil, toLocationId: Int?, toAssignedLocationId: Int? = nil, toEventId: Int? = nil, toPersonId: Int?, notes: String = "") async throws -> BulkResult {
        var body: [String: Any] = ["notes": notes]
        if let tags = assetTags { body["asset_tags"] = tags }
        if let ids = deviceIds { body["device_ids"] = ids }
        if let locId = toLocationId { body["to_location_id"] = locId }
        if let aLocId = toAssignedLocationId { body["to_assigned_location_id"] = aLocId }
        if let eventId = toEventId { body["to_event_id"] = eventId }
        if let personId = toPersonId { body["to_person_id"] = personId }
        return try await request("devices/bulk-move", method: "POST", body: body)
    }
    
    func bulkUpdate(assetTags: [String]? = nil, deviceIds: [Int]? = nil, updates: [String: Any]) async throws -> BulkResult {
        var body: [String: Any] = ["updates": updates]
        if let tags = assetTags { body["asset_tags"] = tags }
        if let ids = deviceIds { body["device_ids"] = ids }
        return try await request("devices/bulk-update", method: "POST", body: body)
    }
    
    func scanVerify(assetTags: [String], eventId: Int?, locationId: Int?) async throws -> BulkResult {
        var body: [String: Any] = ["asset_tags": assetTags]
        if let eventId = eventId { body["event_id"] = eventId }
        if let locationId = locationId { body["location_id"] = locationId }
        return try await request("devices/scan-verify", method: "POST", body: body)
    }
    
    // MARK: - Import (with custom fields + selective overwrite)
    func importDevices(devices: [[String: Any]], eventId: Int?, fieldsToUpdate: [String]? = nil, customFieldNames: [String] = []) async throws -> BulkResult {
        var body: [String: Any] = ["devices": devices]
        if let eventId = eventId { body["event_id"] = eventId }
        if let fields = fieldsToUpdate { body["fields_to_update"] = fields }
        if !customFieldNames.isEmpty { body["custom_field_names"] = customFieldNames }
        return try await request("devices/import", method: "POST", body: body)
    }
    
    // MARK: - Custom Fields
    func getCustomFields() async throws -> CustomFieldsResponse {
        return try await request("devices/custom-fields")
    }
    
    func addCustomField(fieldName: String, fieldType: String = "text", fieldLabel: String, isRequired: Bool = false, fieldOrder: Int = 0) async throws -> GenericResponse {
        let body: [String: Any] = [
            "field_name": fieldName,
            "field_type": fieldType,
            "field_label": fieldLabel,
            "is_required": isRequired ? 1 : 0,
            "field_order": fieldOrder
        ]
        return try await request("devices/custom-fields", method: "POST", body: body)
    }
    
    func deleteCustomField(fieldName: String, removeData: Bool = false) async throws -> GenericResponse {
        var params: [String: String] = ["field_name": fieldName]
        if removeData { params["remove_data"] = "1" }
        return try await request("devices/custom-fields", method: "DELETE", queryParams: params)
    }
    
    func getExportURL(eventId: Int? = nil, format: String = "csv") -> URL? {
        var urlString = "\(baseURL)?action=devices/export&format=\(format)"
        if let eventId = eventId { urlString += "&event_id=\(eventId)" }
        return URL(string: urlString)
    }
    
    // MARK: - Locations
    func getLocations(eventId: Int? = nil) async throws -> LocationsResponse {
        var params: [String: String] = [:]
        if let eventId = eventId { params["event_id"] = "\(eventId)" }
        return try await request("locations", queryParams: params)
    }
    
    func createLocation(name: String, eventId: Int?) async throws -> GenericResponse {
        var body: [String: Any] = ["name": name]
        if let eventId = eventId { body["event_id"] = eventId }
        return try await request("locations", method: "POST", body: body)
    }
    
    // MARK: - People
    func getPeople(eventId: Int? = nil) async throws -> PeopleResponse {
        var params: [String: String] = [:]
        if let eventId = eventId { params["event_id"] = "\(eventId)" }
        return try await request("people", queryParams: params)
    }
    
    func createPerson(name: String, role: String? = nil, email: String? = nil, eventId: Int?) async throws -> GenericResponse {
        var body: [String: Any] = ["name": name]
        if let role = role { body["role"] = role }
        if let email = email { body["email"] = email }
        if let eventId = eventId { body["event_id"] = eventId }
        return try await request("people", method: "POST", body: body)
    }
    
    // MARK: - Events
    func getEvents() async throws -> EventsResponse {
        return try await request("events")
    }
    
    func createEvent(name: String, startDate: String? = nil, endDate: String? = nil) async throws -> GenericResponse {
        var body: [String: Any] = ["name": name]
        if let start = startDate { body["start_date"] = start }
        if let end = endDate { body["end_date"] = end }
        return try await request("events", method: "POST", body: body)
    }
    
    // MARK: - Activity
    func getActivity(deviceId: Int? = nil, action: String? = nil, limit: Int = 50) async throws -> ActivityResponse {
        var params: [String: String] = ["limit": "\(limit)"]
        if let deviceId = deviceId { params["device_id"] = "\(deviceId)" }
        if let action = action { params["action"] = action }
        return try await request("activity", queryParams: params)
    }
    
    // MARK: - Stats
    func getStats(eventId: Int? = nil) async throws -> StatsResponse {
        var params: [String: String] = [:]
        if let eventId = eventId { params["event_id"] = "\(eventId)" }
        return try await request("stats", queryParams: params)
    }
    
    // MARK: - Export (download CSV)
    func exportCSV(eventId: Int? = nil, status: String? = nil, category: String? = nil, locationId: Int? = nil) async throws -> Data {
        var urlString = "\(baseURL)?action=devices/export&format=csv"
        if let eventId = eventId { urlString += "&event_id=\(eventId)" }
        if let status = status { urlString += "&status=\(status.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? status)" }
        if let category = category { urlString += "&category=\(category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? category)" }
        if let locationId = locationId { urlString += "&location_id=\(locationId)" }
        
        guard let url = URL(string: urlString) else { throw APIError.invalidURL }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await session.data(for: request)
        return data
    }
    
    // MARK: - Connection Test
    func testConnection() async throws -> Bool {
        let _: EventsResponse = try await request("events")
        return true
    }
}

// MARK: - API Errors
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case serverError(Int, String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid server URL. Check Settings."
        case .invalidResponse: return "Invalid response from server."
        case .unauthorized: return "Unauthorized. Check your credentials."
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .decodingError(let msg): return "Data error: \(msg)"
        }
    }
}
