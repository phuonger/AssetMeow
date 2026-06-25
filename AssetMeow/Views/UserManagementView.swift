import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var users: [AppUser] = []
    @State private var isLoading = false
    @State private var showCreateSheet = false
    @State private var showEditSheet = false
    @State private var showChangePasswordSheet = false
    @State private var selectedUser: AppUser?
    @State private var errorMessage = ""
    
    // Create user form
    @State private var newUsername = ""
    @State private var newPassword = ""
    @State private var newDisplayName = ""
    @State private var newBadgeId = ""
    @State private var newRole = "user"
    
    // Change password form
    @State private var currentPassword = ""
    @State private var newPasswordChange = ""
    @State private var confirmPassword = ""
    @State private var passwordMessage = ""
    @State private var passwordSuccess = false
    
    var isAdmin: Bool {
        appState.currentUser?.role == "admin"
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundMedium.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("User Management")
                            .font(AppTheme.titleFont)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(isAdmin ? "Manage app users and roles" : "Your account settings")
                            .font(AppTheme.captionFont)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Change own password button
                    Button(action: { showChangePasswordSheet = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "key.fill")
                            Text("Change My Password")
                        }
                        .secondaryButton()
                    }
                    .buttonStyle(.plain)
                    
                    if isAdmin {
                        Button(action: { showCreateSheet = true }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                Text("Add User")
                            }
                            .primaryButton()
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
                
                if isAdmin {
                    // Users list
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.primaryPurple))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(users, id: \.id) { user in
                                    UserRow(user: user, onEdit: {
                                        selectedUser = user
                                        showEditSheet = true
                                    }, onDelete: {
                                        deleteUser(user)
                                    }, currentUserId: appState.currentUser?.id ?? 0)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                } else {
                    // Non-admin just sees their own info
                    VStack(spacing: 16) {
                        if let user = appState.currentUser {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(AppTheme.primaryPurple.opacity(0.2))
                                        .frame(width: 60, height: 60)
                                    Text(String(user.username.prefix(1)).uppercased())
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(AppTheme.primaryPurpleLight)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.displayName ?? user.username)
                                        .font(AppTheme.headingFont)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("@\(user.username)")
                                        .font(AppTheme.bodyFont)
                                        .foregroundColor(AppTheme.textSecondary)
                                    Text("Role: \(user.role.capitalized)")
                                        .font(AppTheme.captionFont)
                                        .foregroundColor(AppTheme.textMuted)
                                }
                                Spacer()
                            }
                            .glowCardStyle()
                        }
                    }
                    .padding(20)
                    Spacer()
                }
            }
        }
        .onAppear { loadUsers() }
        .sheet(isPresented: $showCreateSheet) {
            createUserSheet
        }
        .sheet(isPresented: $showEditSheet) {
            editUserSheet
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            changePasswordSheet
        }
    }
    
    // MARK: - Create User Sheet
    var createUserSheet: some View {
        VStack(spacing: 20) {
            Text("Create New User")
                .font(AppTheme.headingFont)
                .foregroundColor(AppTheme.textPrimary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Username")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                TextField("username", text: $newUsername)
                    .darkTextField()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Display Name")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                TextField("Display Name", text: $newDisplayName)
                    .darkTextField()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Password (min 6 characters)")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                SecureField("password", text: $newPassword)
                    .darkTextField()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Badge ID (for Station Mode login)")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                HStack(spacing: 8) {
                    TextField("Scan or enter badge ID", text: $newBadgeId)
                        .darkTextField()
                    Image(systemName: "wave.3.right")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.textMuted)
                }
                Text("Leave empty if not using badge login")
                    .font(.system(size: 10))
                    .foregroundColor(AppTheme.textMuted)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Role")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                Picker("Role", selection: $newRole) {
                    Text("User").tag("user")
                    Text("Admin").tag("admin")
                }
                .pickerStyle(.segmented)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.statusMissing)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showCreateSheet = false
                    clearCreateForm()
                }
                .secondaryButton()
                .buttonStyle(.plain)
                
                Button("Create User") {
                    createUser()
                }
                .primaryButton()
                .buttonStyle(.plain)
                .disabled(newUsername.isEmpty || newPassword.count < 6)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(AppTheme.backgroundCard)
    }
    
    // MARK: - Edit User Sheet
    var editUserSheet: some View {
        VStack(spacing: 20) {
            Text("Edit User")
                .font(AppTheme.headingFont)
                .foregroundColor(AppTheme.textPrimary)
            
            if let user = selectedUser {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Username (cannot change)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textMuted)
                    Text(user.username)
                        .font(AppTheme.bodyFont)
                        .foregroundColor(AppTheme.textSecondary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Display Name")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    TextField("Display Name", text: $newDisplayName)
                        .darkTextField()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Badge ID (for Station Mode login)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    HStack(spacing: 8) {
                        TextField("Scan or enter badge ID", text: $newBadgeId)
                            .darkTextField()
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.textMuted)
                    }
                    Text("Leave empty to remove badge login")
                        .font(.system(size: 10))
                        .foregroundColor(AppTheme.textMuted)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("New Password (leave empty to keep current)")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    SecureField("New password", text: $newPassword)
                        .darkTextField()
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Role")
                        .font(AppTheme.captionFont)
                        .foregroundColor(AppTheme.textSecondary)
                    Picker("Role", selection: $newRole) {
                        Text("User").tag("user")
                        Text("Admin").tag("admin")
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showEditSheet = false
                    clearCreateForm()
                }
                .secondaryButton()
                .buttonStyle(.plain)
                
                Button("Save Changes") {
                    updateUser()
                }
                .primaryButton()
                .buttonStyle(.plain)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(AppTheme.backgroundCard)
        .onAppear {
            if let user = selectedUser {
                newDisplayName = user.displayName ?? ""
                newBadgeId = user.badgeId ?? ""
                newRole = user.role
            }
        }
    }
    
    // MARK: - Change Password Sheet
    var changePasswordSheet: some View {
        VStack(spacing: 20) {
            Text("Change Password")
                .font(AppTheme.headingFont)
                .foregroundColor(AppTheme.textPrimary)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Current Password")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                SecureField("Current password", text: $currentPassword)
                    .darkTextField()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("New Password (min 6 characters)")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                SecureField("New password", text: $newPasswordChange)
                    .darkTextField()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm New Password")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textSecondary)
                SecureField("Confirm password", text: $confirmPassword)
                    .darkTextField()
            }
            
            if !passwordMessage.isEmpty {
                Text(passwordMessage)
                    .font(AppTheme.captionFont)
                    .foregroundColor(passwordSuccess ? AppTheme.statusAvailable : AppTheme.statusMissing)
            }
            
            HStack(spacing: 12) {
                Button("Cancel") {
                    showChangePasswordSheet = false
                    clearPasswordForm()
                }
                .secondaryButton()
                .buttonStyle(.plain)
                
                Button("Update Password") {
                    changePassword()
                }
                .primaryButton()
                .buttonStyle(.plain)
                .disabled(currentPassword.isEmpty || newPasswordChange.count < 6 || newPasswordChange != confirmPassword)
            }
        }
        .padding(30)
        .frame(width: 400)
        .background(AppTheme.backgroundCard)
    }
    
    // MARK: - Functions
    
    private func loadUsers() {
        guard isAdmin else { return }
        isLoading = true
        Task {
            do {
                let response = try await APIService.shared.getUsers()
                await MainActor.run {
                    users = response.users
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
    
    private func createUser() {
        Task {
            do {
                let response = try await APIService.shared.createUser(
                    username: newUsername,
                    password: newPassword,
                    role: newRole,
                    badgeId: newBadgeId.isEmpty ? nil : newBadgeId
                )
                await MainActor.run {
                    if response.success == true {
                        showCreateSheet = false
                        clearCreateForm()
                        loadUsers()
                    } else {
                        errorMessage = response.error ?? "Failed to create user"
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func updateUser() {
        guard let user = selectedUser, let userId = user.id else { return }
        Task {
            do {
                var updates: [String: Any] = ["role": newRole]
                if !newDisplayName.isEmpty {
                    updates["display_name"] = newDisplayName
                }
                // Always send badge_id (empty string clears it)
                updates["badge_id"] = newBadgeId.isEmpty ? "" : newBadgeId
                if !newPassword.isEmpty {
                    updates["password"] = newPassword
                }
                let _ = try await APIService.shared.updateUser(id: userId, updates: updates)
                await MainActor.run {
                    showEditSheet = false
                    clearCreateForm()
                    loadUsers()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func deleteUser(_ user: AppUser) {
        guard let userId = user.id else { return }
        Task {
            do {
                let _ = try await APIService.shared.deleteUser(id: userId)
                await MainActor.run {
                    loadUsers()
                }
            } catch {}
        }
    }
    
    private func changePassword() {
        guard newPasswordChange == confirmPassword else {
            passwordMessage = "Passwords don't match"
            passwordSuccess = false
            return
        }
        
        Task {
            let (success, message) = await appState.changePassword(current: currentPassword, new: newPasswordChange)
            await MainActor.run {
                passwordSuccess = success
                passwordMessage = message
                if success {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showChangePasswordSheet = false
                        clearPasswordForm()
                    }
                }
            }
        }
    }
    
    private func clearCreateForm() {
        newUsername = ""
        newPassword = ""
        newDisplayName = ""
        newBadgeId = ""
        newRole = "user"
        errorMessage = ""
    }
    
    private func clearPasswordForm() {
        currentPassword = ""
        newPasswordChange = ""
        confirmPassword = ""
        passwordMessage = ""
        passwordSuccess = false
    }
}

// MARK: - User Row Component

struct UserRow: View {
    let user: AppUser
    let onEdit: () -> Void
    let onDelete: () -> Void
    let currentUserId: Int
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(user.role == "admin" ? AppTheme.primaryPurple.opacity(0.3) : AppTheme.surfaceDefault)
                    .frame(width: 40, height: 40)
                Text(String(user.username.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(user.role == "admin" ? AppTheme.primaryPurpleLight : AppTheme.textSecondary)
            }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(user.displayName ?? user.username)
                        .font(AppTheme.subheadingFont)
                        .foregroundColor(AppTheme.textPrimary)
                    
                    Text(user.role.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(user.role == "admin" ? AppTheme.accentCyan : AppTheme.textMuted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (user.role == "admin" ? AppTheme.accentCyan : AppTheme.textMuted).opacity(0.15)
                        )
                        .cornerRadius(4)
                }
                
                Text("@\(user.username)")
                    .font(AppTheme.captionFont)
                    .foregroundColor(AppTheme.textMuted)
            }
            
            Spacer()
            
            // Status
            if user.isActive {
                Circle()
                    .fill(AppTheme.statusAvailable)
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(AppTheme.statusMissing)
                    .frame(width: 8, height: 8)
            }
            
            // Actions
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            
            if user.id != currentUserId {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(AppTheme.statusMissing.opacity(0.7))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(AppTheme.backgroundCard)
        .cornerRadius(AppTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.surfaceBorder.opacity(0.3), lineWidth: 1)
        )
    }
}
