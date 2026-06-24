import SwiftUI

struct FieldManagerView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var fields: [CustomFieldEntry] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    // New field form
    @State private var newFieldName = ""
    @State private var newFieldLabel = ""
    @State private var newFieldType = "text"
    @State private var newFieldRequired = false
    @State private var showAddForm = false
    
    // Delete confirmation
    @State private var fieldToDelete: CustomFieldEntry?
    @State private var showDeleteConfirm = false
    @State private var removeDataOnDelete = false
    
    // Status
    @State private var statusMessage = ""
    @State private var showStatus = false
    
    let fieldTypes = ["text", "number", "date", "select", "url", "email"]
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Field Manager")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Add or remove custom tracking fields for your assets (e.g., IMEI, EID, Serial)")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    Spacer()
                    
                    Button(action: { showAddForm.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Field")
                        }
                        .primaryButton()
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
                
                // Add Field Form
                if showAddForm {
                    addFieldForm
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
                
                Rectangle()
                    .fill(AppTheme.surfaceBorder)
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                
                // Fields List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                    Text("Loading fields...")
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                } else if fields.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.primaryPurple.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: "rectangle.grid.1x2")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.primaryPurple)
                        }
                        Text("No Custom Fields")
                            .font(AppTheme.headingFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text("Add custom fields to track additional device information like IMEI, EID, etc.")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                } else {
                    // Table header
                    HStack(spacing: 0) {
                        Text("Field Name")
                            .frame(width: 150, alignment: .leading)
                        Text("Label")
                            .frame(width: 150, alignment: .leading)
                        Text("Type")
                            .frame(width: 80, alignment: .leading)
                        Text("Required")
                            .frame(width: 80, alignment: .leading)
                        Text("Source")
                            .frame(width: 100, alignment: .leading)
                        Text("Created")
                            .frame(width: 130, alignment: .leading)
                        Spacer()
                        Text("Actions")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppTheme.textMuted)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(AppTheme.backgroundDark)
                    
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(fields, id: \.fieldName) { field in
                                fieldRow(field)
                            }
                        }
                    }
                }
            }
        }
        .onAppear { loadFields() }
        .alert("Delete Field", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { fieldToDelete = nil }
            Button("Delete Field Only", role: .destructive) {
                if let field = fieldToDelete {
                    deleteField(field, removeData: false)
                }
            }
            Button("Delete Field + Data", role: .destructive) {
                if let field = fieldToDelete {
                    deleteField(field, removeData: true)
                }
            }
        } message: {
            Text("Delete \"\(fieldToDelete?.fieldLabel ?? fieldToDelete?.fieldName ?? "")\"?\n\n• \"Delete Field Only\" removes the field definition but keeps existing data on devices.\n• \"Delete Field + Data\" removes the field AND clears its values from all devices.")
        }
        .alert("Field Manager", isPresented: $showStatus) {
            Button("OK") { }
        } message: {
            Text(statusMessage)
        }
    }
    
    // MARK: - Add Field Form
    var addFieldForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add New Custom Field")
                .font(AppTheme.subheadingFont)
                .foregroundColor(AppTheme.textPrimary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Field Name (internal key)")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    TextField("e.g. imei, eid, serial_number", text: $newFieldName)
                        .darkTextField()
                        .frame(width: 180)
                        .onChange(of: newFieldName) { val in
                            // Auto-sanitize: lowercase, underscores
                            let sanitized = val.lowercased()
                                .replacingOccurrences(of: " ", with: "_")
                                .filter { $0.isLetter || $0.isNumber || $0 == "_" }
                            if sanitized != val {
                                newFieldName = sanitized
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Display Label")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    TextField("e.g. IMEI, EID, Serial Number", text: $newFieldLabel)
                        .darkTextField()
                        .frame(width: 180)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    Picker("", selection: $newFieldType) {
                        ForEach(fieldTypes, id: \.self) { t in
                            Text(t.capitalized).tag(t)
                        }
                    }
                    .frame(width: 100)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Required")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    Toggle("", isOn: $newFieldRequired)
                        .toggleStyle(.checkbox)
                }
                
                Spacer()
                
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Button(action: addField) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("Add")
                            }
                            .font(AppTheme.captionFont)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.primaryPurple)
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                        .disabled(newFieldName.isEmpty || newFieldLabel.isEmpty)
                        
                        Button(action: {
                            showAddForm = false
                            resetForm()
                        }) {
                            Text("Cancel")
                                .font(AppTheme.captionFont)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            // Preview
            if !newFieldName.isEmpty {
                HStack(spacing: 4) {
                    Text("Key:")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                    Text(newFieldName)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppTheme.accentCyan)
                }
            }
        }
        .glowCardStyle()
    }
    
    // MARK: - Field Row
    func fieldRow(_ field: CustomFieldEntry) -> some View {
        HStack(spacing: 0) {
            Text(field.fieldName)
                .font(AppTheme.monoFont)
                .foregroundColor(AppTheme.accentCyan)
                .frame(width: 150, alignment: .leading)
            Text(field.fieldLabel ?? field.fieldName)
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 150, alignment: .leading)
            Text(field.fieldType ?? "text")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 80, alignment: .leading)
            Text(field.isRequired == 1 ? "Yes" : "No")
                .font(AppTheme.captionFont)
                .foregroundColor(field.isRequired == 1 ? AppTheme.accentOrange : AppTheme.textMuted)
                .frame(width: 80, alignment: .leading)
            Text(field.source ?? "manual")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 100, alignment: .leading)
            Text(field.createdAt ?? "—")
                .font(AppTheme.captionFont)
                .foregroundColor(AppTheme.textMuted)
                .frame(width: 130, alignment: .leading)
            Spacer()
            Button(action: {
                fieldToDelete = field
                showDeleteConfirm = true
            }) {
                Image(systemName: "trash")
                    .foregroundColor(AppTheme.statusMissing)
            }
            .buttonStyle(.plain)
            .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(AppTheme.surfaceDefault.opacity(0.5))
    }
    
    // MARK: - Actions
    func loadFields() {
        isLoading = true
        Task {
            do {
                let response = try await APIService.shared.getCustomFields()
                fields = response.customFields
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
    
    func addField() {
        Task {
            do {
                let _ = try await APIService.shared.addCustomField(
                    fieldName: newFieldName,
                    fieldType: newFieldType,
                    fieldLabel: newFieldLabel,
                    isRequired: newFieldRequired,
                    fieldOrder: fields.count + 1
                )
                statusMessage = "Field \"\(newFieldLabel)\" added successfully!"
                showStatus = true
                ToastManager.shared.success("Field Saved", detail: "\"\(newFieldLabel)\" written to database.")
                resetForm()
                showAddForm = false
                loadFields()
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                showStatus = true
                ToastManager.shared.error("Failed to Create Field", detail: error.localizedDescription)
            }
        }
    }
    
    func deleteField(_ field: CustomFieldEntry, removeData: Bool) {
        Task {
            do {
                let _ = try await APIService.shared.deleteCustomField(
                    fieldName: field.fieldName,
                    removeData: removeData
                )
                statusMessage = "Field \"\(field.fieldLabel ?? field.fieldName)\" deleted."
                showStatus = true
                ToastManager.shared.success("Field Deleted", detail: "\"\(field.fieldLabel ?? field.fieldName)\" removed from database.")
                fieldToDelete = nil
                loadFields()
            } catch {
                statusMessage = "Error: \(error.localizedDescription)"
                showStatus = true
                ToastManager.shared.error("Failed to Delete Field", detail: error.localizedDescription)
            }
        }
    }
    
    func resetForm() {
        newFieldName = ""
        newFieldLabel = ""
        newFieldType = "text"
        newFieldRequired = false
    }
}
