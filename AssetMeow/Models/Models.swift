import Foundation

// MARK: - Device Model
struct Device: Codable, Identifiable, Hashable {
    let id: Int?
    var assetTag: String
    var category: String?
    var model: String?
    var sku: String?
    var status: DeviceStatus
    var locationId: Int?
    var assignedLocationId: Int?
    var assignedToId: Int?
    var eventId: Int?
    var account: String?
    var liveOrDummy: String?
    var notes: String?
    var customData: [String: String]?
    var lastScanned: String?
    var createdAt: String?
    var updatedAt: String?
    
    // Joined fields
    var locationName: String?
    var assignedLocationName: String?
    var assignedToName: String?
    var eventName: String?
    var recentActivity: [ActivityEntry]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case assetTag = "asset_tag"
        case category, model, sku, status
        case locationId = "location_id"
        case assignedLocationId = "assigned_location_id"
        case assignedToId = "assigned_to_id"
        case eventId = "event_id"
        case account
        case liveOrDummy = "live_or_dummy"
        case notes
        case customData = "custom_data"
        case lastScanned = "last_scanned"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case locationName = "location_name"
        case assignedLocationName = "assigned_location_name"
        case assignedToName = "assigned_to_name"
        case eventName = "event_name"
        case recentActivity = "recent_activity"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // ID can be Int or String-encoded Int
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        
        assetTag = try container.decode(String.self, forKey: .assetTag)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        model = try? container.decodeIfPresent(String.self, forKey: .model)
        sku = try? container.decodeIfPresent(String.self, forKey: .sku)
        
        // Resilient status decoding - fallback to .available if unknown
        if let statusStr = try? container.decode(String.self, forKey: .status),
           let decoded = DeviceStatus(rawValue: statusStr) {
            status = decoded
        } else {
            status = .available
        }
        
        // Integer fields that might come as strings from PHP
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .locationId) {
            locationId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .locationId), let parsed = Int(strVal) {
            locationId = parsed
        } else {
            locationId = nil
        }
        
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .assignedLocationId) {
            assignedLocationId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .assignedLocationId), let parsed = Int(strVal) {
            assignedLocationId = parsed
        } else {
            assignedLocationId = nil
        }
        
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .assignedToId) {
            assignedToId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .assignedToId), let parsed = Int(strVal) {
            assignedToId = parsed
        } else {
            assignedToId = nil
        }
        
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .eventId) {
            eventId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .eventId), let parsed = Int(strVal) {
            eventId = parsed
        } else {
            eventId = nil
        }
        
        account = try? container.decodeIfPresent(String.self, forKey: .account)
        liveOrDummy = try? container.decodeIfPresent(String.self, forKey: .liveOrDummy)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        
        // custom_data can be a JSON object or null
        customData = try? container.decodeIfPresent([String: String].self, forKey: .customData)
        
        lastScanned = try? container.decodeIfPresent(String.self, forKey: .lastScanned)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        updatedAt = try? container.decodeIfPresent(String.self, forKey: .updatedAt)
        
        locationName = try? container.decodeIfPresent(String.self, forKey: .locationName)
        assignedLocationName = try? container.decodeIfPresent(String.self, forKey: .assignedLocationName)
        assignedToName = try? container.decodeIfPresent(String.self, forKey: .assignedToName)
        eventName = try? container.decodeIfPresent(String.self, forKey: .eventName)
        recentActivity = try? container.decodeIfPresent([ActivityEntry].self, forKey: .recentActivity)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(assetTag)
    }
    
    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id && lhs.assetTag == rhs.assetTag
    }
}

enum DeviceStatus: String, Codable, CaseIterable {
    case available = "Available"
    case checkedOut = "Checked Out"
    case inTransit = "In Transit"
    case missing = "Missing"
    case retired = "Retired"
    
    var color: String {
        switch self {
        case .available: return "green"
        case .checkedOut: return "orange"
        case .inTransit: return "blue"
        case .missing: return "red"
        case .retired: return "gray"
        }
    }
}

// MARK: - Location Model
struct Location: Codable, Identifiable, Hashable {
    let id: Int?
    var name: String
    var eventId: Int?
    var deviceCount: Int?
    var assignedDeviceCount: Int?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case eventId = "event_id"
        case deviceCount = "device_count"
        case assignedDeviceCount = "assigned_device_count"
        case createdAt = "created_at"
    }
    
    init(id: Int?, name: String, eventId: Int? = nil, deviceCount: Int? = nil, assignedDeviceCount: Int? = nil, createdAt: String? = nil) {
        self.id = id
        self.name = name
        self.eventId = eventId
        self.deviceCount = deviceCount
        self.assignedDeviceCount = assignedDeviceCount
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        name = try container.decode(String.self, forKey: .name)
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .eventId) {
            eventId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .eventId), let parsed = Int(strVal) {
            eventId = parsed
        } else {
            eventId = nil
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .deviceCount) {
            deviceCount = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .deviceCount), let parsed = Int(strVal) {
            deviceCount = parsed
        } else {
            deviceCount = nil
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .assignedDeviceCount) {
            assignedDeviceCount = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .assignedDeviceCount), let parsed = Int(strVal) {
            assignedDeviceCount = parsed
        } else {
            assignedDeviceCount = nil
        }
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: Location, rhs: Location) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - Person Model
struct Person: Codable, Identifiable, Hashable {
    let id: Int?
    var name: String
    var role: String?
    var email: String?
    var eventId: Int?
    var deviceCount: Int?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, role, email
        case eventId = "event_id"
        case deviceCount = "device_count"
        case createdAt = "created_at"
    }
    
    init(id: Int?, name: String, role: String? = nil, email: String? = nil, eventId: Int? = nil, deviceCount: Int? = nil, createdAt: String? = nil) {
        self.id = id
        self.name = name
        self.role = role
        self.email = email
        self.eventId = eventId
        self.deviceCount = deviceCount
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        name = try container.decode(String.self, forKey: .name)
        role = try? container.decodeIfPresent(String.self, forKey: .role)
        email = try? container.decodeIfPresent(String.self, forKey: .email)
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .eventId) {
            eventId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .eventId), let parsed = Int(strVal) {
            eventId = parsed
        } else {
            eventId = nil
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .deviceCount) {
            deviceCount = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .deviceCount), let parsed = Int(strVal) {
            deviceCount = parsed
        } else {
            deviceCount = nil
        }
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - Event Model
struct Event: Codable, Identifiable, Hashable {
    let id: Int?
    var name: String
    var startDate: String?
    var endDate: String?
    var deviceCount: Int?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case startDate = "start_date"
        case endDate = "end_date"
        case deviceCount = "device_count"
        case createdAt = "created_at"
    }
    
    init(id: Int?, name: String, startDate: String? = nil, endDate: String? = nil, deviceCount: Int? = nil, createdAt: String? = nil) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.deviceCount = deviceCount
        self.createdAt = createdAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        name = try container.decode(String.self, forKey: .name)
        startDate = try? container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try? container.decodeIfPresent(String.self, forKey: .endDate)
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .deviceCount) {
            deviceCount = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .deviceCount), let parsed = Int(strVal) {
            deviceCount = parsed
        } else {
            deviceCount = nil
        }
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    static func == (lhs: Event, rhs: Event) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
}

// MARK: - Activity Entry
struct ActivityEntry: Codable, Identifiable, Hashable {
    let id: Int?
    var deviceId: Int?
    var action: String?
    var assetTag: String?
    var model: String?
    var category: String?
    var make: String?
    var sku: String?
    var fromLocation: String?
    var toLocation: String?
    var fromPerson: String?
    var toPerson: String?
    var notes: String?
    var performedBy: String?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case deviceId = "device_id"
        case action
        case assetTag = "asset_tag"
        case model
        case category
        case make
        case sku
        case fromLocation = "from_location"
        case toLocation = "to_location"
        case fromPerson = "from_person"
        case toPerson = "to_person"
        case notes
        case performedBy = "performed_by"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .deviceId) {
            deviceId = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .deviceId), let parsed = Int(strVal) {
            deviceId = parsed
        } else {
            deviceId = nil
        }
        action = try? container.decodeIfPresent(String.self, forKey: .action)
        assetTag = try? container.decodeIfPresent(String.self, forKey: .assetTag)
        model = try? container.decodeIfPresent(String.self, forKey: .model)
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        make = try? container.decodeIfPresent(String.self, forKey: .make)
        sku = try? container.decodeIfPresent(String.self, forKey: .sku)
        fromLocation = try? container.decodeIfPresent(String.self, forKey: .fromLocation)
        toLocation = try? container.decodeIfPresent(String.self, forKey: .toLocation)
        fromPerson = try? container.decodeIfPresent(String.self, forKey: .fromPerson)
        toPerson = try? container.decodeIfPresent(String.self, forKey: .toPerson)
        notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        performedBy = try? container.decodeIfPresent(String.self, forKey: .performedBy)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
    }
}

// MARK: - API Response Types
struct DevicesResponse: Codable {
    let devices: [Device]
    let total: Int?
    let count: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Use a lossy decode for devices array - skip any device that fails to decode
        // instead of failing the entire response
        if let devicesArray = try? container.decode([Device].self, forKey: .devices) {
            devices = devicesArray
        } else {
            // Fallback: try to decode as [FailableDevice] to skip bad entries
            let failableDevices = try container.decode([FailableDecodable<Device>].self, forKey: .devices)
            devices = failableDevices.compactMap { $0.value }
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .total) {
            total = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .total), let parsed = Int(strVal) {
            total = parsed
        } else {
            total = nil
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .count) {
            count = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .count), let parsed = Int(strVal) {
            count = parsed
        } else {
            count = nil
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case devices, total, count
    }
}

// Helper to allow partial array decoding (skip bad elements)
struct FailableDecodable<T: Decodable>: Decodable {
    let value: T?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(T.self)
    }
}

struct LocationsResponse: Codable {
    let locations: [Location]
}

struct PeopleResponse: Codable {
    let people: [Person]
}

struct EventsResponse: Codable {
    let events: [Event]
}

struct ActivityResponse: Codable {
    let activity: [ActivityEntry]
}

struct LookupResponse: Codable {
    let device: Device?
    let found: Bool
}

// MARK: - Validate Response (for checking which tags exist)
struct ValidateResponse: Codable {
    let success: Bool?
    let found: [ValidatedDevice]?
    let notFound: [String]?
    let foundCount: Int?
    let notFoundCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case success, found
        case notFound = "not_found"
        case foundCount = "found_count"
        case notFoundCount = "not_found_count"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try? container.decodeIfPresent(Bool.self, forKey: .success)
        found = try? container.decodeIfPresent([ValidatedDevice].self, forKey: .found)
        foundCount = try? container.decodeIfPresent(Int.self, forKey: .foundCount)
        notFoundCount = try? container.decodeIfPresent(Int.self, forKey: .notFoundCount)
        
        // Handle not_found array where items might be strings OR integers (due to JSON_NUMERIC_CHECK)
        if let stringArray = try? container.decodeIfPresent([String].self, forKey: .notFound) {
            notFound = stringArray
        } else if let mixedArray = try? container.decodeIfPresent([FlexibleString].self, forKey: .notFound) {
            notFound = mixedArray.map { $0.value }
        } else {
            notFound = nil
        }
    }
}

// Helper to decode values that might be String or Int from JSON
struct FlexibleString: Codable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            value = str
        } else if let num = try? container.decode(Int.self) {
            value = String(num)
        } else if let dbl = try? container.decode(Double.self) {
            value = String(dbl)
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

struct ValidatedDevice: Codable, Identifiable, Hashable {
    let id: Int?
    let assetTag: String
    let category: String?
    let model: String?
    let sku: String?
    let status: String?
    let locationName: String?
    let assignedLocationName: String?
    let assignedToName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case assetTag = "asset_tag"
        case category, model, sku, status
        case locationName = "location_name"
        case assignedLocationName = "assigned_location_name"
        case assignedToName = "assigned_to_name"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try? container.decodeIfPresent(Int.self, forKey: .id)
        
        // asset_tag might come as String or Int (due to JSON_NUMERIC_CHECK)
        if let str = try? container.decode(String.self, forKey: .assetTag) {
            assetTag = str
        } else if let num = try? container.decode(Int.self, forKey: .assetTag) {
            assetTag = String(num)
        } else {
            assetTag = ""
        }
        
        category = try? container.decodeIfPresent(String.self, forKey: .category)
        model = try? container.decodeIfPresent(String.self, forKey: .model)
        sku = try? container.decodeIfPresent(String.self, forKey: .sku)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        locationName = try? container.decodeIfPresent(String.self, forKey: .locationName)
        assignedLocationName = try? container.decodeIfPresent(String.self, forKey: .assignedLocationName)
        assignedToName = try? container.decodeIfPresent(String.self, forKey: .assignedToName)
    }
}

struct BulkResult: Codable {
    let success: Bool?
    let error: String?
    let results: BulkResultDetails?
}

struct BulkResultDetails: Codable {
    let checkedOut: Int?
    let checkedIn: Int?
    let created: Int?
    let imported: Int?
    let updated: Int?
    let moved: Int?
    let verified: Int?
    let skipped: Int?
    let newDevices: Int?
    let notFound: [String]?
    let tagsVerified: [String]?
    let tagsNew: [String]?
    let errors: [String]?
    
    enum CodingKeys: String, CodingKey {
        case checkedOut = "checked_out"
        case checkedIn = "checked_in"
        case created, imported, updated, moved, verified, skipped
        case newDevices = "new_devices"
        case notFound = "not_found"
        case tagsVerified = "tags_verified"
        case tagsNew = "tags_new"
        case errors
    }
}

struct GenericResponse: Codable {
    let success: Bool?
    let error: String?
    let id: Int?
    let name: String?
    let updated: Int?
}

struct StatsResponse: Codable {
    let totalDevices: Int?
    let available: Int?
    let checkedOut: Int?
    let missing: Int?
    let byCategory: [[String: AnyCodable]]?
    let byLocation: [[String: AnyCodable]]?
    
    enum CodingKeys: String, CodingKey {
        case totalDevices = "total_devices"
        case available
        case checkedOut = "checked_out"
        case missing
        case byCategory = "by_category"
        case byLocation = "by_location"
    }
}

// MARK: - Custom Fields Response
struct CustomFieldEntry: Codable, Identifiable, Hashable {
    let id: Int?
    let fieldName: String
    let fieldType: String?
    let fieldLabel: String?
    let isRequired: Int?
    let fieldOrder: Int?
    let createdAt: String?
    let source: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case fieldName = "field_name"
        case fieldType = "field_type"
        case fieldLabel = "field_label"
        case isRequired = "is_required"
        case fieldOrder = "field_order"
        case createdAt = "created_at"
        case source
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decodeIfPresent(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        fieldName = (try? container.decode(String.self, forKey: .fieldName)) ?? ""
        fieldType = try? container.decodeIfPresent(String.self, forKey: .fieldType)
        fieldLabel = try? container.decodeIfPresent(String.self, forKey: .fieldLabel)
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .isRequired) {
            isRequired = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .isRequired), let parsed = Int(strVal) {
            isRequired = parsed
        } else {
            isRequired = nil
        }
        if let intVal = try? container.decodeIfPresent(Int.self, forKey: .fieldOrder) {
            fieldOrder = intVal
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .fieldOrder), let parsed = Int(strVal) {
            fieldOrder = parsed
        } else {
            fieldOrder = nil
        }
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        source = try? container.decodeIfPresent(String.self, forKey: .source)
    }
}

struct CustomFieldsResponse: Codable {
    let customFields: [CustomFieldEntry]
    let fieldNames: [String]?
    let count: Int?
    
    enum CodingKeys: String, CodingKey {
        case customFields = "custom_fields"
        case fieldNames = "field_names"
        case count
    }
}

// MARK: - User Model
struct AppUser: Codable, Identifiable, Hashable {
    let id: Int?
    var username: String
    var role: String
    var displayName: String?
    var isActive: Bool
    var createdAt: String?
    var lastLogin: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username, role
        case displayName = "display_name"
        case isActive = "is_active"
        case createdAt = "created_at"
        case lastLogin = "last_login"
    }
    
    init(id: Int?, username: String, role: String = "user", displayName: String? = nil, isActive: Bool = true, createdAt: String? = nil, lastLogin: String? = nil) {
        self.id = id
        self.username = username
        self.role = role
        self.displayName = displayName
        self.isActive = isActive
        self.createdAt = createdAt
        self.lastLogin = lastLogin
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intId = try? container.decode(Int.self, forKey: .id) {
            id = intId
        } else if let strId = try? container.decode(String.self, forKey: .id), let parsed = Int(strId) {
            id = parsed
        } else {
            id = nil
        }
        username = try container.decode(String.self, forKey: .username)
        role = (try? container.decodeIfPresent(String.self, forKey: .role)) ?? "user"
        displayName = try? container.decodeIfPresent(String.self, forKey: .displayName)
        // isActive can come as Bool or as Int (0/1) or String
        if let boolVal = try? container.decodeIfPresent(Bool.self, forKey: .isActive) {
            isActive = boolVal ?? true
        } else if let intVal = try? container.decodeIfPresent(Int.self, forKey: .isActive) {
            isActive = (intVal ?? 1) != 0
        } else if let strVal = try? container.decodeIfPresent(String.self, forKey: .isActive) {
            isActive = strVal != "0" && strVal.lowercased() != "false"
        } else {
            isActive = true
        }
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
        lastLogin = try? container.decodeIfPresent(String.self, forKey: .lastLogin)
    }
    
    var isAdmin: Bool {
        return role == "admin"
    }
}

// MARK: - Auth Response Types
struct LoginResponse: Codable {
    let success: Bool?
    let token: String?
    let user: AppUser?
    let error: String?
}

struct UsersResponse: Codable {
    let users: [AppUser]
}

struct ChangePasswordResponse: Codable {
    let success: Bool?
    let error: String?
}

// Helper for mixed-type JSON values
struct AnyCodable: Codable, Hashable {
    let value: String
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = String(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            value = String(doubleVal)
        } else if let strVal = try? container.decode(String.self) {
            value = strVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = String(boolVal)
        } else {
            value = ""
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
