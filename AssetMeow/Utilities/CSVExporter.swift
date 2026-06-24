import Foundation
import AppKit
import UniformTypeIdentifiers

// MARK: - Session Log Entry
struct ScanSessionEntry: Identifiable {
    let id = UUID()
    let assetTag: String
    let status: ScanEntryStatus
    let category: String?
    let model: String?
    let location: String?
    let assignedTo: String?
    let notes: String?
    let timestamp: Date
    
    enum ScanEntryStatus: String {
        case success = "Success"
        case notFound = "Not Found"
        case created = "Created (New)"
        case error = "Error"
        case alreadyCheckedIn = "Already Checked In"
    }
}

// MARK: - Session Log
struct ScanSessionLog {
    let sessionType: SessionType
    let startTime: Date
    let endTime: Date
    let entries: [ScanSessionEntry]
    let location: String?
    let person: String?
    let event: String?
    let performedBy: String?
    let notes: String?
    
    enum SessionType: String {
        case checkout = "Check Out"
        case checkin = "Check In"
    }
    
    var successCount: Int { entries.filter { $0.status == .success || $0.status == .created }.count }
    var notFoundCount: Int { entries.filter { $0.status == .notFound }.count }
    var errorCount: Int { entries.filter { $0.status == .error }.count }
    
    var notFoundEntries: [ScanSessionEntry] { entries.filter { $0.status == .notFound } }
    var successEntries: [ScanSessionEntry] { entries.filter { $0.status == .success || $0.status == .created } }
}

// MARK: - CSV Exporter
class CSVExporter {
    
    static func exportSessionLog(_ log: ScanSessionLog) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = dateFormatter.string(from: log.startTime)
        
        let typeStr = log.sessionType == .checkout ? "checkout" : "checkin"
        let filename = "scan_session_\(typeStr)_\(dateStr).csv"
        
        var csv = generateSessionCSV(log)
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.commaSeparatedText]
        
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    static func generateSessionCSV(_ log: ScanSessionLog) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var lines: [String] = []
        
        // Header metadata
        lines.append("# Session Report")
        lines.append("# Type: \(log.sessionType.rawValue)")
        lines.append("# Date: \(dateFormatter.string(from: log.startTime))")
        if let loc = log.location { lines.append("# Location: \(loc)") }
        if let person = log.person { lines.append("# Assigned To: \(person)") }
        if let event = log.event { lines.append("# Event: \(event)") }
        if let user = log.performedBy { lines.append("# Performed By: \(user)") }
        if let notes = log.notes, !notes.isEmpty { lines.append("# Notes: \(notes)") }
        lines.append("# Total Scanned: \(log.entries.count)")
        lines.append("# Successful: \(log.successCount)")
        lines.append("# Not Found: \(log.notFoundCount)")
        lines.append("# Errors: \(log.errorCount)")
        lines.append("")
        
        // CSV header
        lines.append("Asset Tag,Status,Category,Model,Location,Assigned To,Notes,Timestamp")
        
        // CSV rows
        for entry in log.entries {
            let row = [
                escapeCSV(entry.assetTag),
                escapeCSV(entry.status.rawValue),
                escapeCSV(entry.category ?? ""),
                escapeCSV(entry.model ?? ""),
                escapeCSV(entry.location ?? ""),
                escapeCSV(entry.assignedTo ?? ""),
                escapeCSV(entry.notes ?? ""),
                escapeCSV(dateFormatter.string(from: entry.timestamp))
            ]
            lines.append(row.joined(separator: ","))
        }
        
        return lines.joined(separator: "\n")
    }
    
    static func exportNotFoundLog(_ notFoundTags: [String], sessionType: String, location: String?, event: String?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = dateFormatter.string(from: Date())
        
        let filename = "not_found_devices_\(dateStr).csv"
        
        var lines: [String] = []
        lines.append("# Not Found Devices Report")
        lines.append("# Session Type: \(sessionType)")
        lines.append("# Date: \(dateFormatter.string(from: Date()))")
        if let loc = location { lines.append("# Location: \(loc)") }
        if let event = event { lines.append("# Event: \(event)") }
        lines.append("# Total Not Found: \(notFoundTags.count)")
        lines.append("")
        lines.append("Asset Tag,Status,Action Required")
        
        for tag in notFoundTags {
            lines.append("\(escapeCSV(tag)),Not Found,Needs Investigation")
        }
        
        let csv = lines.joined(separator: "\n")
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.commaSeparatedText]
        
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    static func exportActivityLog(_ entries: [ActivityEntry], filename: String? = nil) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateStr = dateFormatter.string(from: Date())
        
        let fname = filename ?? "activity_log_\(dateStr).csv"
        
        var lines: [String] = []
        lines.append("Date,Action,Asset Tag,Model,From Location,To Location,From Person,To Person,Notes,Performed By")
        
        for entry in entries {
            let row = [
                escapeCSV(entry.createdAt ?? ""),
                escapeCSV(entry.action ?? ""),
                escapeCSV(entry.assetTag ?? ""),
                escapeCSV(entry.model ?? ""),
                escapeCSV(entry.fromLocation ?? ""),
                escapeCSV(entry.toLocation ?? ""),
                escapeCSV(entry.fromPerson ?? ""),
                escapeCSV(entry.toPerson ?? ""),
                escapeCSV(entry.notes ?? ""),
                escapeCSV(entry.performedBy ?? "")
            ]
            lines.append(row.joined(separator: ","))
        }
        
        let csv = lines.joined(separator: "\n")
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fname
        panel.allowedContentTypes = [.commaSeparatedText]
        
        if panel.runModal() == .OK, let url = panel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }
    
    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
