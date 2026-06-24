import SwiftUI

// MARK: - CopyableField
// A reusable component that displays a label + value with a quick copy button.
// Use for asset tags, custom fields, device info fields, etc.

struct CopyableField: View {
    let label: String
    let value: String
    var isMono: Bool = false
    var accentColor: Color = AppTheme.textPrimary
    
    @State private var showCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
            
            HStack(spacing: 6) {
                Text(value)
                    .font(isMono ? AppTheme.monoFont : AppTheme.bodyFont)
                    .foregroundColor(accentColor)
                    .textSelection(.enabled)
                
                if value != "—" && value != "Never" && !value.isEmpty {
                    Button(action: copyToClipboard) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(showCopied ? AppTheme.statusAvailable : AppTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                    .help("Copy to clipboard")
                }
            }
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}

// MARK: - CopyableAssetTag
// Inline copy button specifically for asset tags in table rows and lists.

struct CopyableAssetTag: View {
    let assetTag: String
    
    @State private var showCopied = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(assetTag)
                .font(AppTheme.monoFont)
                .foregroundColor(AppTheme.accentCyan)
                .textSelection(.enabled)
            
            Button(action: copyToClipboard) {
                Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(showCopied ? AppTheme.statusAvailable : AppTheme.textMuted.opacity(0.6))
            }
            .buttonStyle(.plain)
            .help("Copy asset tag")
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(assetTag, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}

// MARK: - CopyableText
// Minimal inline copy button for any text value in a table cell.

struct CopyableText: View {
    let text: String
    var font: Font = AppTheme.captionFont
    var color: Color = AppTheme.textSecondary
    
    @State private var isHovered = false
    @State private var showCopied = false
    
    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(font)
                .foregroundColor(color)
                .textSelection(.enabled)
            
            if isHovered && text != "—" && text != "Never" && !text.isEmpty {
                Button(action: copyToClipboard) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(showCopied ? AppTheme.statusAvailable : AppTheme.textMuted.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Copy")
                .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopied = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopied = false
            }
        }
    }
}
