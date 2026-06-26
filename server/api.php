<?php
require_once 'config.php';

$db = getDB();
$method = $_SERVER['REQUEST_METHOD'];
$path = isset($_GET['action']) ? $_GET['action'] : '';

// ============================================================
// ONE-TIME MIGRATION: Add assigned_location_id if missing
// ============================================================
try {
    $cols = $db->query("SHOW COLUMNS FROM devices")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('assigned_location_id', $cols)) {
        $db->exec("ALTER TABLE devices ADD COLUMN assigned_location_id INT DEFAULT NULL");
        // Default assigned_location_id to current location_id for existing devices
        $db->exec("UPDATE devices SET assigned_location_id = location_id WHERE assigned_location_id IS NULL AND location_id IS NOT NULL");
    }
} catch (PDOException $e) {
    // Silently continue - table might not exist yet
}

// ONE-TIME MIGRATION: Add badge_id to users if missing
try {
    $userCols = $db->query("SHOW COLUMNS FROM users")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('badge_id', $userCols)) {
        $db->exec("ALTER TABLE users ADD COLUMN badge_id VARCHAR(100) DEFAULT NULL");
        $db->exec("CREATE UNIQUE INDEX idx_users_badge_id ON users(badge_id)");
    }
} catch (PDOException $e) {
    // Silently continue
}

// ONE-TIME MIGRATION: Create/update activity_log table
try {
    $db->exec("CREATE TABLE IF NOT EXISTS activity_log (
        id INT AUTO_INCREMENT PRIMARY KEY,
        device_id INT DEFAULT NULL,
        asset_tag VARCHAR(100) DEFAULT NULL,
        action VARCHAR(50) NOT NULL,
        from_location_id INT DEFAULT NULL,
        to_location_id INT DEFAULT NULL,
        from_person_id INT DEFAULT NULL,
        to_person_id INT DEFAULT NULL,
        notes TEXT DEFAULT NULL,
        performed_by VARCHAR(200) DEFAULT NULL,
        user_id INT DEFAULT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_activity_device (device_id),
        INDEX idx_activity_created (created_at),
        INDEX idx_activity_action (action)
    )");
    // Add columns that might be missing from older versions
    $alCols = $db->query("SHOW COLUMNS FROM activity_log")->fetchAll(PDO::FETCH_COLUMN);
    if (!in_array('from_location_id', $alCols)) {
        $db->exec("ALTER TABLE activity_log ADD COLUMN from_location_id INT DEFAULT NULL AFTER action");
    }
    if (!in_array('to_location_id', $alCols)) {
        $db->exec("ALTER TABLE activity_log ADD COLUMN to_location_id INT DEFAULT NULL AFTER from_location_id");
    }
    if (!in_array('from_person_id', $alCols)) {
        $db->exec("ALTER TABLE activity_log ADD COLUMN from_person_id INT DEFAULT NULL AFTER to_location_id");
    }
    if (!in_array('to_person_id', $alCols)) {
        $db->exec("ALTER TABLE activity_log ADD COLUMN to_person_id INT DEFAULT NULL AFTER from_person_id");
    }
    if (!in_array('user_id', $alCols)) {
        $db->exec("ALTER TABLE activity_log ADD COLUMN user_id INT DEFAULT NULL AFTER performed_by");
    }
    if (!in_array('device_id', $alCols)) {
        $db->exec("ALTER TABLE activity_log ADD COLUMN device_id INT DEFAULT NULL AFTER id");
    }
    // Backfill device_id from asset_tag for older entries that have asset_tag but no device_id
    $db->exec("UPDATE activity_log al JOIN devices d ON al.asset_tag = d.asset_tag SET al.device_id = d.id WHERE al.device_id IS NULL AND al.asset_tag IS NOT NULL AND al.asset_tag != ''");
} catch (PDOException $e) {
    // Silently continue
}

// Create custom_fields_registry table if it doesn't exist
try {
    $db->exec("CREATE TABLE IF NOT EXISTS custom_fields_registry (
        id INT AUTO_INCREMENT PRIMARY KEY,
        field_key VARCHAR(100) NOT NULL UNIQUE,
        field_label VARCHAR(200) NOT NULL,
        field_type VARCHAR(50) DEFAULT 'text',
        is_required TINYINT(1) DEFAULT 0,
        sort_order INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )");
} catch (PDOException $e) {
    // Silently continue
}

// ============================================================
// AUTH MIDDLEWARE
// ============================================================

// Routes that don't require user auth (just API key)
$publicRoutes = ['auth/login', 'auth/badge-login'];

// Check if this is a public route
$isPublicRoute = in_array($path, $publicRoutes);

if (!$isPublicRoute) {
    // Try token auth first, then fall back to API key
    $currentUser = authenticateRequest($db);
}

// Route requests
switch ($path) {
    // === AUTH ===
    case 'auth/login':
        handleLogin($db);
        break;
    case 'auth/logout':
        handleLogout($db);
        break;
    case 'auth/me':
        handleMe($db, $currentUser);
        break;
    case 'auth/badge-login':
        handleBadgeLogin($db);
        break;
    case 'auth/change-password':
        handleChangePassword($db, $currentUser);
        break;

    // === USERS (Admin only) ===
    case 'users':
        handleUsers($db, $method, $currentUser);
        break;

    // === DEVICES ===
    case 'devices':
        handleDevices($db, $method, $currentUser);
        break;
    case 'devices/search':
        handleDeviceSearch($db);
        break;
    case 'devices/lookup':
        handleDeviceLookup($db);
        break;
    case 'devices/validate':
        handleDeviceValidate($db);
        break;
    case 'devices/bulk-checkout':
        handleBulkCheckout($db, $currentUser);
        break;
    case 'devices/bulk-checkin':
        handleBulkCheckin($db, $currentUser);
        break;
    case 'devices/bulk-move':
        handleBulkMove($db, $currentUser);
        break;
    case 'devices/bulk-update':
        handleBulkUpdate($db, $currentUser);
        break;
    case 'devices/bulk-create':
        handleBulkCreate($db, $currentUser);
        break;
    case 'devices/import':
        handleImport($db, $currentUser);
        break;
    case 'devices/export':
        handleExport($db);
        break;
    case 'devices/scan-verify':
        handleScanVerify($db, $currentUser);
        break;
    case 'devices/custom-fields':
        handleCustomFields($db, $method);
        break;

    // === LOCATIONS ===
    case 'locations':
        handleLocations($db, $method, $currentUser);
        break;

    // === PEOPLE ===
    case 'people':
        handlePeople($db, $method, $currentUser);
        break;

    // === EVENTS ===
    case 'events':
        handleEvents($db, $method, $currentUser);
        break;

    // === ACTIVITY LOG ===
    case 'activity':
        handleActivity($db);
        break;

    // === DEBUG: Activity Log diagnosis ===
    case 'debug/activity-check':
        handleActivityDebug($db);
        break;

    // === STATS ===
    case 'stats':
        handleStats($db);
        break;

    default:
        echo json_encode(['error' => 'Unknown action', 'available_actions' => [
            'auth/login', 'auth/badge-login', 'auth/logout', 'auth/me', 'auth/change-password', 'users',
            'devices', 'devices/search', 'devices/lookup', 'devices/validate',
            'devices/bulk-checkout', 'devices/bulk-checkin', 'devices/bulk-move',
            'devices/bulk-update', 'devices/bulk-create', 'devices/import',
            'devices/export', 'devices/scan-verify', 'devices/custom-fields',
            'locations', 'people', 'events', 'activity', 'stats'
        ]]);
}

// ============================================================
// AUTHENTICATION FUNCTIONS
// ============================================================

function authenticateRequest($db) {
    // Get headers case-insensitively
    $rawHeaders = getallheaders();
    $headers = [];
    foreach ($rawHeaders as $key => $value) {
        $headers[strtolower($key)] = $value;
    }
    
    // Try Bearer token first
    $authHeader = isset($headers['authorization']) ? $headers['authorization'] : '';
    if (strpos($authHeader, 'Bearer ') === 0) {
        $token = substr($authHeader, 7);
        $stmt = $db->prepare("SELECT u.* FROM users u JOIN auth_tokens t ON u.id = t.user_id WHERE t.token = ? AND t.expires_at > NOW()");
        $stmt->execute([$token]);
        $user = $stmt->fetch();
        if ($user) {
            return $user;
        }
    }
    
    // Fall back to API key (for backward compatibility)
    $apiKey = isset($headers['x-api-key']) ? $headers['x-api-key'] : '';
    if ($apiKey === API_KEY) {
        // API key auth - return a system user context
        return ['id' => 0, 'username' => 'api_key', 'role' => 'admin', 'display_name' => 'API Key'];
    }
    
    // No valid auth
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized', 'message' => 'Valid Bearer token or X-API-Key required']);
    exit();
}

function handleLogin($db) {
    // Login does not require API key - username/password is the authentication
    $data = json_decode(file_get_contents('php://input'), true);
    $username = $data['username'] ?? '';
    $password = $data['password'] ?? '';
    
    if (empty($username) || empty($password)) {
        http_response_code(400);
        echo json_encode(['error' => 'Username and password required']);
        return;
    }
    
    // Query without is_active filter first, then check it separately
    $stmt = $db->prepare("SELECT * FROM users WHERE username = ?");
    $stmt->execute([$username]);
    $user = $stmt->fetch();
    
    if (!$user || !password_verify($password, $user['password_hash'])) {
        http_response_code(401);
        echo json_encode(['error' => 'Invalid username or password']);
        return;
    }
    
    // Check if user is deactivated (only if is_active column exists and is explicitly 0)
    if (isset($user['is_active']) && (int)$user['is_active'] === 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Account is deactivated. Contact your administrator.']);
        return;
    }
    
    // Generate token (valid for 30 days)
    $token = bin2hex(random_bytes(32));
    $expiresAt = date('Y-m-d H:i:s', strtotime('+30 days'));
    
    $db->prepare("INSERT INTO auth_tokens (user_id, token, expires_at) VALUES (?, ?, ?)")
       ->execute([$user['id'], $token, $expiresAt]);
    
    // Update last login
    $db->prepare("UPDATE users SET last_login = NOW() WHERE id = ?")->execute([$user['id']]);
    
    // Clean up expired tokens
    $db->exec("DELETE FROM auth_tokens WHERE expires_at < NOW()");
    
    echo json_encode([
        'success' => true,
        'token' => $token,
        'user' => [
            'id' => (int)$user['id'],
            'username' => $user['username'],
            'display_name' => $user['display_name'],
            'role' => $user['role'],
            'is_active' => isset($user['is_active']) ? (bool)$user['is_active'] : true,
            'badge_id' => $user['badge_id'] ?? null,
            'last_login' => $user['last_login'],
            'created_at' => $user['created_at']
        ]
    ]);
}

function handleBadgeLogin($db) {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        http_response_code(405);
        echo json_encode(['error' => 'POST required']);
        return;
    }
    
    $data = json_decode(file_get_contents('php://input'), true);
    $badgeId = trim($data['badge_id'] ?? '');
    
    if (empty($badgeId)) {
        http_response_code(400);
        echo json_encode(['error' => 'Badge ID required']);
        return;
    }
    
    // Look up user by badge_id
    $stmt = $db->prepare("SELECT * FROM users WHERE badge_id = ?");
    $stmt->execute([$badgeId]);
    $user = $stmt->fetch();
    
    if (!$user) {
        http_response_code(401);
        echo json_encode(['error' => 'Badge not recognized. Please contact your administrator.']);
        return;
    }
    
    // Check if user is deactivated
    if (isset($user['is_active']) && (int)$user['is_active'] === 0) {
        http_response_code(403);
        echo json_encode(['error' => 'Account is deactivated. Contact your administrator.']);
        return;
    }
    
    // Generate token (valid for 1 day for kiosk sessions)
    $token = bin2hex(random_bytes(32));
    $expiresAt = date('Y-m-d H:i:s', strtotime('+1 day'));
    
    $db->prepare("INSERT INTO auth_tokens (user_id, token, expires_at) VALUES (?, ?, ?)")
       ->execute([$user['id'], $token, $expiresAt]);
    
    // Update last login
    $db->prepare("UPDATE users SET last_login = NOW() WHERE id = ?")->execute([$user['id']]);
    
    // Clean up expired tokens
    $db->exec("DELETE FROM auth_tokens WHERE expires_at < NOW()");
    
    echo json_encode([
        'success' => true,
        'token' => $token,
        'user' => [
            'id' => (int)$user['id'],
            'username' => $user['username'],
            'display_name' => $user['display_name'],
            'role' => $user['role'],
            'is_active' => isset($user['is_active']) ? (bool)$user['is_active'] : true,
            'badge_id' => $user['badge_id'] ?? null,
            'last_login' => $user['last_login'],
            'created_at' => $user['created_at']
        ]
    ]);
}

function handleLogout($db) {
    $rawHeaders = getallheaders();
    $headers = [];
    foreach ($rawHeaders as $key => $value) {
        $headers[strtolower($key)] = $value;
    }
    $authHeader = isset($headers['authorization']) ? $headers['authorization'] : '';
    if (strpos($authHeader, 'Bearer ') === 0) {
        $token = substr($authHeader, 7);
        $db->prepare("DELETE FROM auth_tokens WHERE token = ?")->execute([$token]);
    }
    echo json_encode(['success' => true]);
}

function handleMe($db, $currentUser) {
    echo json_encode([
        'user' => [
            'id' => (int)$currentUser['id'],
            'username' => $currentUser['username'],
            'display_name' => $currentUser['display_name'],
            'role' => $currentUser['role'],
            'badge_id' => $currentUser['badge_id'] ?? null,
            'last_login' => $currentUser['last_login'] ?? null
        ]
    ]);
}

function handleChangePassword($db, $currentUser) {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        echo json_encode(['error' => 'POST required']);
        return;
    }
    
    $data = json_decode(file_get_contents('php://input'), true);
    $currentPassword = $data['current_password'] ?? '';
    $newPassword = $data['new_password'] ?? '';
    $userId = $data['user_id'] ?? $currentUser['id'];
    
    if (empty($newPassword) || strlen($newPassword) < 6) {
        echo json_encode(['error' => 'New password must be at least 6 characters']);
        return;
    }
    
    // If changing own password, verify current password
    if ((int)$userId === (int)$currentUser['id']) {
        if (empty($currentPassword)) {
            echo json_encode(['error' => 'Current password required']);
            return;
        }
        $stmt = $db->prepare("SELECT password_hash FROM users WHERE id = ?");
        $stmt->execute([$currentUser['id']]);
        $user = $stmt->fetch();
        if (!password_verify($currentPassword, $user['password_hash'])) {
            echo json_encode(['error' => 'Current password is incorrect']);
            return;
        }
    } else {
        // Only admins can change other users' passwords
        if ($currentUser['role'] !== 'admin') {
            http_response_code(403);
            echo json_encode(['error' => 'Only admins can change other users passwords']);
            return;
        }
    }
    
    $newHash = password_hash($newPassword, PASSWORD_BCRYPT);
    $db->prepare("UPDATE users SET password_hash = ? WHERE id = ?")->execute([$newHash, $userId]);
    
    echo json_encode(['success' => true, 'message' => 'Password updated']);
}

// ============================================================
// USER MANAGEMENT (Admin only)
// ============================================================

function handleUsers($db, $method, $currentUser) {
    if ($currentUser['role'] !== 'admin') {
        http_response_code(403);
        echo json_encode(['error' => 'Admin access required']);
        return;
    }
    
    switch ($method) {
        case 'GET':
            $stmt = $db->query("SELECT id, username, display_name, role, is_active, badge_id, last_login, created_at FROM users ORDER BY username");
            echo json_encode(['users' => $stmt->fetchAll()], JSON_NUMERIC_CHECK);
            break;
            
        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            $username = trim($data['username'] ?? '');
            $password = $data['password'] ?? '';
            $displayName = $data['display_name'] ?? $username;
            $role = $data['role'] ?? 'user';
            
            if (empty($username) || empty($password)) {
                echo json_encode(['error' => 'Username and password required']);
                return;
            }
            if (strlen($password) < 6) {
                echo json_encode(['error' => 'Password must be at least 6 characters']);
                return;
            }
            if (!in_array($role, ['admin', 'user'])) {
                $role = 'user';
            }
            
            $checkStmt = $db->prepare("SELECT id FROM users WHERE username = ?");
            $checkStmt->execute([$username]);
            if ($checkStmt->fetch()) {
                echo json_encode(['error' => 'Username already exists']);
                return;
            }
            
            $badgeId = isset($data['badge_id']) && !empty(trim($data['badge_id'])) ? trim($data['badge_id']) : null;
            
            // Check badge_id uniqueness if provided
            if ($badgeId) {
                $badgeCheck = $db->prepare("SELECT id FROM users WHERE badge_id = ?");
                $badgeCheck->execute([$badgeId]);
                if ($badgeCheck->fetch()) {
                    echo json_encode(['error' => 'Badge ID already assigned to another user']);
                    return;
                }
            }
            
            $hash = password_hash($password, PASSWORD_BCRYPT);
            $stmt = $db->prepare("INSERT INTO users (username, password_hash, display_name, role, badge_id) VALUES (?, ?, ?, ?, ?)");
            $stmt->execute([$username, $hash, $displayName, $role, $badgeId]);
            
            logActivity($db, null, null, 'User Created', null, null, null, null, "Created user: $username (role: $role)", $currentUser);
            
            echo json_encode(['success' => true, 'id' => (int)$db->lastInsertId(), 'username' => $username]);
            break;
            
        case 'PUT':
            $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
            if (!$id) {
                echo json_encode(['error' => 'User ID required']);
                return;
            }
            $data = json_decode(file_get_contents('php://input'), true);
            
            $fields = [];
            $params = [];
            
            if (isset($data['display_name'])) {
                $fields[] = "display_name = ?";
                $params[] = $data['display_name'];
            }
            if (isset($data['role']) && in_array($data['role'], ['admin', 'user'])) {
                $fields[] = "role = ?";
                $params[] = $data['role'];
            }
            if (isset($data['is_active'])) {
                $fields[] = "is_active = ?";
                $params[] = (int)$data['is_active'];
            }
            if (array_key_exists('badge_id', $data)) {
                $badgeId = !empty(trim($data['badge_id'] ?? '')) ? trim($data['badge_id']) : null;
                // Check uniqueness if setting a badge_id
                if ($badgeId) {
                    $badgeCheck = $db->prepare("SELECT id FROM users WHERE badge_id = ? AND id != ?");
                    $badgeCheck->execute([$badgeId, $id]);
                    if ($badgeCheck->fetch()) {
                        echo json_encode(['error' => 'Badge ID already assigned to another user']);
                        return;
                    }
                }
                $fields[] = "badge_id = ?";
                $params[] = $badgeId;
            }
            if (!empty($data['password']) && strlen($data['password']) >= 6) {
                $fields[] = "password_hash = ?";
                $params[] = password_hash($data['password'], PASSWORD_BCRYPT);
            }
            
            if (empty($fields)) {
                echo json_encode(['error' => 'No fields to update']);
                return;
            }
            
            $params[] = $id;
            $db->prepare("UPDATE users SET " . implode(', ', $fields) . " WHERE id = ?")->execute($params);
            
            logActivity($db, null, null, 'User Updated', null, null, null, null, "Updated user ID: $id", $currentUser);
            
            echo json_encode(['success' => true]);
            break;
            
        case 'DELETE':
            $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
            if (!$id) {
                echo json_encode(['error' => 'User ID required']);
                return;
            }
            if ((int)$id === (int)$currentUser['id']) {
                echo json_encode(['error' => 'Cannot delete your own account']);
                return;
            }
            $db->prepare("DELETE FROM users WHERE id = ?")->execute([$id]);
            
            logActivity($db, null, null, 'User Deleted', null, null, null, null, "Deleted user ID: $id", $currentUser);
            
            echo json_encode(['success' => true]);
            break;
    }
}

// ============================================================
// ACTIVITY LOGGING HELPER
// ============================================================

function logActivity($db, $deviceId, $assetTag, $action, $fromLocationId, $toLocationId, $fromPersonId, $toPersonId, $notes, $currentUser = null) {
    $userId = ($currentUser && isset($currentUser['id'])) ? (int)$currentUser['id'] : null;
    $performedBy = ($currentUser && isset($currentUser['username'])) ? $currentUser['username'] : null;
    
    if ($currentUser && !empty($currentUser['display_name'])) {
        $performedBy = $currentUser['display_name'];
    }
    
    $stmt = $db->prepare("INSERT INTO activity_log (device_id, asset_tag, action, from_location_id, to_location_id, from_person_id, to_person_id, notes, performed_by, user_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");
    $stmt->execute([$deviceId, $assetTag, $action, $fromLocationId, $toLocationId, $fromPersonId, $toPersonId, $notes, $performedBy, $userId]);
}

// ============================================================
// DEVICE HANDLERS
// ============================================================

function handleDevices($db, $method, $currentUser) {
    switch ($method) {
        case 'GET':
            $event_id = isset($_GET['event_id']) ? (int)$_GET['event_id'] : null;
            $status = isset($_GET['status']) ? $_GET['status'] : null;
            $category = isset($_GET['category']) ? $_GET['category'] : null;
            $model = isset($_GET['model']) ? $_GET['model'] : null;
            $sku = isset($_GET['sku']) ? $_GET['sku'] : null;
            $location_id = isset($_GET['location_id']) ? (int)$_GET['location_id'] : null;
            $assigned_location_id = isset($_GET['assigned_location_id']) ? (int)$_GET['assigned_location_id'] : null;
            $unassigned = isset($_GET['unassigned']) && $_GET['unassigned'] == '1';
            $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 1000;
            $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;

            $sql = "SELECT d.*, l.name as location_name, al.name as assigned_location_name, p.name as assigned_to_name, e.name as event_name 
                    FROM devices d 
                    LEFT JOIN locations l ON d.location_id = l.id 
                    LEFT JOIN locations al ON d.assigned_location_id = al.id
                    LEFT JOIN people p ON d.assigned_to_id = p.id 
                    LEFT JOIN events e ON d.event_id = e.id 
                    WHERE 1=1";
            $params = [];

            if ($event_id) { $sql .= " AND d.event_id = ?"; $params[] = $event_id; }
            if ($status) { $sql .= " AND d.status = ?"; $params[] = $status; }
            if ($category) { $sql .= " AND d.category = ?"; $params[] = $category; }
            if ($model) { $sql .= " AND d.model = ?"; $params[] = $model; }
            if ($sku) { $sql .= " AND d.sku = ?"; $params[] = $sku; }
            if ($location_id) { $sql .= " AND d.location_id = ?"; $params[] = $location_id; }
            if ($assigned_location_id) { $sql .= " AND d.assigned_location_id = ?"; $params[] = $assigned_location_id; }
            if ($unassigned) { $sql .= " AND d.assigned_location_id IS NULL"; }

            $sql .= " ORDER BY d.updated_at DESC LIMIT " . (int)$limit . " OFFSET " . (int)$offset;

            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            $devices = $stmt->fetchAll();

            foreach ($devices as &$dev) {
                if (!empty($dev['custom_data'])) {
                    $dev['custom_data'] = json_decode($dev['custom_data'], true);
                } else {
                    $dev['custom_data'] = null;
                }
            }
            unset($dev);

            // Get total count
            $countSql = "SELECT COUNT(*) as total FROM devices d WHERE 1=1";
            $countParams = [];
            if ($event_id) { $countSql .= " AND d.event_id = ?"; $countParams[] = $event_id; }
            if ($status) { $countSql .= " AND d.status = ?"; $countParams[] = $status; }
            if ($category) { $countSql .= " AND d.category = ?"; $countParams[] = $category; }
            if ($model) { $countSql .= " AND d.model = ?"; $countParams[] = $model; }
            if ($sku) { $countSql .= " AND d.sku = ?"; $countParams[] = $sku; }
            if ($location_id) { $countSql .= " AND d.location_id = ?"; $countParams[] = $location_id; }
            if ($assigned_location_id) { $countSql .= " AND d.assigned_location_id = ?"; $countParams[] = $assigned_location_id; }
            if ($unassigned) { $countSql .= " AND d.assigned_location_id IS NULL"; }
            $countStmt = $db->prepare($countSql);
            $countStmt->execute($countParams);
            $total = (int)$countStmt->fetch()['total'];

            echo json_encode(['devices' => $devices, 'total' => $total], JSON_NUMERIC_CHECK);
            break;

        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            if (empty($data['asset_tag'])) {
                echo json_encode(['error' => 'asset_tag is required']);
                return;
            }
            
            $customData = null;
            if (!empty($data['custom_data']) && is_array($data['custom_data'])) {
                $customData = json_encode($data['custom_data']);
            }
            
            // Default assigned_location_id to location_id if not provided
            $assignedLocationId = $data['assigned_location_id'] ?? $data['location_id'] ?? null;
            
            $stmt = $db->prepare("INSERT INTO devices (asset_tag, category, model, sku, status, location_id, assigned_location_id, assigned_to_id, event_id, account, live_or_dummy, notes, custom_data, last_scanned) 
                                  VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
                                  ON DUPLICATE KEY UPDATE 
                                  category = COALESCE(VALUES(category), category),
                                  model = COALESCE(VALUES(model), model),
                                  sku = COALESCE(VALUES(sku), sku),
                                  status = COALESCE(VALUES(status), status),
                                  location_id = COALESCE(VALUES(location_id), location_id),
                                  assigned_location_id = COALESCE(VALUES(assigned_location_id), assigned_location_id),
                                  assigned_to_id = COALESCE(VALUES(assigned_to_id), assigned_to_id),
                                  event_id = COALESCE(VALUES(event_id), event_id),
                                  account = COALESCE(VALUES(account), account),
                                  live_or_dummy = COALESCE(VALUES(live_or_dummy), live_or_dummy),
                                  notes = COALESCE(VALUES(notes), notes),
                                  custom_data = COALESCE(VALUES(custom_data), custom_data),
                                  last_scanned = NOW()");
            $stmt->execute([
                $data['asset_tag'],
                $data['category'] ?? null,
                $data['model'] ?? null,
                $data['sku'] ?? null,
                $data['status'] ?? 'Available',
                $data['location_id'] ?? null,
                $assignedLocationId,
                $data['assigned_to_id'] ?? null,
                $data['event_id'] ?? null,
                $data['account'] ?? null,
                $data['live_or_dummy'] ?? 'N/A',
                $data['notes'] ?? null,
                $customData
            ]);
            
            $deviceId = (int)$db->lastInsertId();
            logActivity($db, $deviceId, $data['asset_tag'], 'Device Created', null, $data['location_id'] ?? null, null, null, null, $currentUser);
            
            echo json_encode(['success' => true, 'id' => $deviceId]);
            break;

        case 'PUT':
            $data = json_decode(file_get_contents('php://input'), true);
            $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
            if (!$id) {
                echo json_encode(['error' => 'Device ID required']);
                return;
            }
            $fields = [];
            $params = [];
            $allowed = ['asset_tag','category','model','sku','status','location_id','assigned_location_id','assigned_to_id','event_id','account','live_or_dummy','notes'];
            foreach ($allowed as $field) {
                if (isset($data[$field])) {
                    $fields[] = "$field = ?";
                    $params[] = $data[$field];
                }
            }
            
            // Handle custom_data update
            if (isset($data['custom_data'])) {
                if (is_array($data['custom_data'])) {
                    $existingStmt = $db->prepare("SELECT custom_data FROM devices WHERE id = ?");
                    $existingStmt->execute([$id]);
                    $existing = $existingStmt->fetch();
                    $existingCustom = [];
                    if ($existing && !empty($existing['custom_data'])) {
                        $existingCustom = json_decode($existing['custom_data'], true) ?? [];
                    }
                    $merged = array_merge($existingCustom, $data['custom_data']);
                    $fields[] = "custom_data = ?";
                    $params[] = json_encode($merged);
                } else {
                    $fields[] = "custom_data = ?";
                    $params[] = $data['custom_data'];
                }
            }
            
            if (empty($fields)) {
                echo json_encode(['error' => 'No fields to update']);
                return;
            }
            $params[] = $id;
            $stmt = $db->prepare("UPDATE devices SET " . implode(', ', $fields) . " WHERE id = ?");
            $stmt->execute($params);
            
            $tagStmt = $db->prepare("SELECT asset_tag FROM devices WHERE id = ?");
            $tagStmt->execute([$id]);
            $tagRow = $tagStmt->fetch();
            logActivity($db, $id, $tagRow ? $tagRow['asset_tag'] : null, 'Device Updated', null, null, null, null, 'Fields: ' . implode(', ', array_keys($data)), $currentUser);
            
            echo json_encode(['success' => true, 'updated' => (int)$stmt->rowCount()]);
            break;

        case 'DELETE':
            $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
            if (!$id) {
                echo json_encode(['error' => 'Device ID required']);
                return;
            }
            $tagStmt = $db->prepare("SELECT asset_tag FROM devices WHERE id = ?");
            $tagStmt->execute([$id]);
            $tagRow = $tagStmt->fetch();
            
            $stmt = $db->prepare("DELETE FROM devices WHERE id = ?");
            $stmt->execute([$id]);
            
            logActivity($db, $id, $tagRow ? $tagRow['asset_tag'] : null, 'Device Deleted', null, null, null, null, null, $currentUser);
            
            echo json_encode(['success' => true]);
            break;
    }
}

function handleDeviceSearch($db) {
    $query = isset($_GET['q']) ? $_GET['q'] : '';
    $tags = isset($_GET['tags']) ? $_GET['tags'] : '';

    if ($tags) {
        $tagList = array_map('trim', explode(',', $tags));
        $placeholders = str_repeat('?,', count($tagList) - 1) . '?';
        $stmt = $db->prepare("SELECT d.*, l.name as location_name, al.name as assigned_location_name, p.name as assigned_to_name, e.name as event_name 
                              FROM devices d 
                              LEFT JOIN locations l ON d.location_id = l.id 
                              LEFT JOIN locations al ON d.assigned_location_id = al.id
                              LEFT JOIN people p ON d.assigned_to_id = p.id 
                              LEFT JOIN events e ON d.event_id = e.id 
                              WHERE d.asset_tag IN ($placeholders)
                              ORDER BY d.asset_tag");
        $stmt->execute($tagList);
    } else {
        $searchTerm = "%$query%";
        $stmt = $db->prepare("SELECT d.*, l.name as location_name, al.name as assigned_location_name, p.name as assigned_to_name, e.name as event_name 
                              FROM devices d 
                              LEFT JOIN locations l ON d.location_id = l.id 
                              LEFT JOIN locations al ON d.assigned_location_id = al.id
                              LEFT JOIN people p ON d.assigned_to_id = p.id 
                              LEFT JOIN events e ON d.event_id = e.id 
                              WHERE d.asset_tag LIKE ? OR d.model LIKE ? OR d.sku LIKE ? OR d.category LIKE ? OR d.notes LIKE ?
                              ORDER BY d.updated_at DESC LIMIT 100");
        $stmt->execute([$searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm]);
    }
    $devices = $stmt->fetchAll();
    
    foreach ($devices as &$dev) {
        if (!empty($dev['custom_data'])) {
            $dev['custom_data'] = json_decode($dev['custom_data'], true);
        } else {
            $dev['custom_data'] = null;
        }
    }
    unset($dev);
    
    echo json_encode(['devices' => $devices, 'count' => count($devices)], JSON_NUMERIC_CHECK);
}

function handleDeviceLookup($db) {
    $asset_tag = isset($_GET['asset_tag']) ? $_GET['asset_tag'] : '';
    if (!$asset_tag) {
        echo json_encode(['error' => 'asset_tag required']);
        return;
    }
    $stmt = $db->prepare("SELECT d.*, l.name as location_name, al.name as assigned_location_name, p.name as assigned_to_name, e.name as event_name 
                          FROM devices d 
                          LEFT JOIN locations l ON d.location_id = l.id 
                          LEFT JOIN locations al ON d.assigned_location_id = al.id
                          LEFT JOIN people p ON d.assigned_to_id = p.id 
                          LEFT JOIN events e ON d.event_id = e.id 
                          WHERE d.asset_tag = ?");
    $stmt->execute([$asset_tag]);
    $device = $stmt->fetch();

    if ($device) {
        if (!empty($device['custom_data'])) {
            $device['custom_data'] = json_decode($device['custom_data'], true);
        } else {
            $device['custom_data'] = null;
        }
        
        $actStmt = $db->prepare("SELECT al.*, 
                                  fl.name as from_location, tl.name as to_location,
                                  fp.name as from_person, tp.name as to_person
                                  FROM activity_log al
                                  LEFT JOIN locations fl ON al.from_location_id = fl.id
                                  LEFT JOIN locations tl ON al.to_location_id = tl.id
                                  LEFT JOIN people fp ON al.from_person_id = fp.id
                                  LEFT JOIN people tp ON al.to_person_id = tp.id
                                  WHERE al.device_id = ?
                                  ORDER BY al.created_at DESC LIMIT 10");
        $actStmt->execute([$device['id']]);
        $device['recent_activity'] = $actStmt->fetchAll();

        $db->prepare("UPDATE devices SET last_scanned = NOW() WHERE id = ?")->execute([$device['id']]);

        echo json_encode(['device' => $device, 'found' => true], JSON_NUMERIC_CHECK);
    } else {
        echo json_encode(['device' => null, 'found' => false]);
    }
}

function handleDeviceValidate($db) {
    $data = json_decode(file_get_contents('php://input'), true);
    $asset_tags = $data['asset_tags'] ?? [];

    if (empty($asset_tags)) {
        echo json_encode(['error' => 'No asset tags provided']);
        return;
    }

    $placeholders = str_repeat('?,', count($asset_tags) - 1) . '?';
    $stmt = $db->prepare("SELECT d.asset_tag, d.id, d.category, d.model, d.sku, d.status, l.name as location_name, al.name as assigned_location_name, p.name as assigned_to_name
                          FROM devices d
                          LEFT JOIN locations l ON d.location_id = l.id
                          LEFT JOIN locations al ON d.assigned_location_id = al.id
                          LEFT JOIN people p ON d.assigned_to_id = p.id
                          WHERE d.asset_tag IN ($placeholders)");
    $stmt->execute($asset_tags);
    $existingDevices = $stmt->fetchAll();
    $existingTags = array_column($existingDevices, 'asset_tag');

    $found = [];
    $not_found = [];
    foreach ($asset_tags as $tag) {
        $tag = trim($tag);
        if (in_array($tag, $existingTags)) {
            foreach ($existingDevices as $dev) {
                if ($dev['asset_tag'] === $tag) {
                    // Force asset_tag to string to prevent JSON_NUMERIC_CHECK from converting numeric tags
                    $dev['asset_tag'] = (string)$dev['asset_tag'];
                    $found[] = $dev;
                    break;
                }
            }
        } else {
            $not_found[] = (string)$tag;  // Force string to prevent JSON_NUMERIC_CHECK conversion
        }
    }

    // Use JSON_UNESCAPED_UNICODE instead of JSON_NUMERIC_CHECK to preserve string types
    echo json_encode([
        'success' => true,
        'found' => $found,
        'not_found' => $not_found,
        'found_count' => count($found),
        'not_found_count' => count($not_found)
    ]);
}

function handleBulkCheckout($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $asset_tags = $data['asset_tags'] ?? [];
    $location_id = $data['location_id'] ?? null;
    $person_id = $data['person_id'] ?? null;
    $notes = $data['notes'] ?? '';
    $event_id = $data['event_id'] ?? null;
    $per_device_notes = $data['per_device_notes'] ?? [];  // {"asset_tag": "note"}

    if (empty($asset_tags)) {
        echo json_encode(['error' => 'No asset tags provided']);
        return;
    }

    $results = ['checked_out' => 0, 'not_found' => [], 'errors' => []];

    $db->beginTransaction();
    try {
        foreach ($asset_tags as $tag) {
            $tag = trim($tag);
            if (empty($tag)) continue;

            $stmt = $db->prepare("SELECT id, location_id, assigned_to_id FROM devices WHERE asset_tag = ?");
            $stmt->execute([$tag]);
            $device = $stmt->fetch();

            if ($device) {
                $oldLocationId = $device['location_id'];
                $oldPersonId = $device['assigned_to_id'];

                // Checkout: update location_id (current location) only, leave assigned_location_id unchanged
                $updateStmt = $db->prepare("UPDATE devices SET status = 'Checked Out', location_id = ?, assigned_to_id = ?, event_id = COALESCE(?, event_id), last_scanned = NOW() WHERE id = ?");
                $updateStmt->execute([$location_id, $person_id, $event_id, $device['id']]);

                // Combine session note + per-device note
                $deviceNote = $per_device_notes[$tag] ?? '';
                $combinedNote = trim($notes . ($deviceNote ? "\n[Device note: $deviceNote]" : ''));

                logActivity($db, $device['id'], $tag, 'Check Out', $oldLocationId, $location_id, $oldPersonId, $person_id, $combinedNote, $currentUser);

                $results['checked_out']++;
            } else {
                $results['not_found'][] = $tag;
            }
        }
        $db->commit();
        echo json_encode(['success' => true, 'results' => $results], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handleBulkCheckin($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $asset_tags = $data['asset_tags'] ?? [];
    $location_id = $data['location_id'] ?? null;
    $assigned_location_id = $data['assigned_location_id'] ?? $location_id;
    $notes = $data['notes'] ?? '';
    $per_device_notes = $data['per_device_notes'] ?? [];  // {"asset_tag": "note"}

    if (empty($asset_tags)) {
        echo json_encode(['error' => 'No asset tags provided']);
        return;
    }

    $results = ['checked_in' => 0, 'not_found' => []];

    $db->beginTransaction();
    try {
        foreach ($asset_tags as $tag) {
            $tag = trim($tag);
            if (empty($tag)) continue;

            $stmt = $db->prepare("SELECT id, location_id, assigned_to_id FROM devices WHERE asset_tag = ?");
            $stmt->execute([$tag]);
            $device = $stmt->fetch();

            if ($device) {
                $oldLocationId = $device['location_id'];
                $oldPersonId = $device['assigned_to_id'];

                // Check-in: update both location_id (current) and assigned_location_id
                $updateStmt = $db->prepare("UPDATE devices SET status = 'Available', location_id = ?, assigned_location_id = ?, assigned_to_id = NULL, last_scanned = NOW() WHERE id = ?");
                $updateStmt->execute([$location_id, $assigned_location_id, $device['id']]);

                // Combine session note + per-device note
                $deviceNote = $per_device_notes[$tag] ?? '';
                $combinedNote = trim($notes . ($deviceNote ? "\n[Device note: $deviceNote]" : ''));

                logActivity($db, $device['id'], $tag, 'Check In', $oldLocationId, $location_id, $oldPersonId, null, $combinedNote, $currentUser);

                $results['checked_in']++;
            } else {
                $results['not_found'][] = $tag;
            }
        }
        $db->commit();
        echo json_encode(['success' => true, 'results' => $results], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handleBulkMove($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $asset_tags = $data['asset_tags'] ?? [];
    $device_ids = $data['device_ids'] ?? [];
    $to_location_id = $data['to_location_id'] ?? null;
    $to_assigned_location_id = $data['to_assigned_location_id'] ?? null;
    $to_event_id = $data['to_event_id'] ?? null;
    $to_person_id = $data['to_person_id'] ?? null;
    $notes = $data['notes'] ?? '';

    $results = ['moved' => 0, 'not_found' => []];

    $db->beginTransaction();
    try {
        $devices = [];
        if (!empty($asset_tags)) {
            $placeholders = str_repeat('?,', count($asset_tags) - 1) . '?';
            $stmt = $db->prepare("SELECT id, asset_tag, location_id, assigned_to_id FROM devices WHERE asset_tag IN ($placeholders)");
            $stmt->execute($asset_tags);
            $devices = $stmt->fetchAll();
            $foundTags = array_column($devices, 'asset_tag');
            $results['not_found'] = array_values(array_diff($asset_tags, $foundTags));
        } elseif (!empty($device_ids)) {
            $placeholders = str_repeat('?,', count($device_ids) - 1) . '?';
            $stmt = $db->prepare("SELECT id, asset_tag, location_id, assigned_to_id FROM devices WHERE id IN ($placeholders)");
            $stmt->execute($device_ids);
            $devices = $stmt->fetchAll();
        }

        foreach ($devices as $device) {
            $updateFields = [];
            $updateParams = [];
            if ($to_location_id !== null) {
                $updateFields[] = "location_id = ?";
                $updateParams[] = $to_location_id;
            }
            if ($to_assigned_location_id !== null) {
                $updateFields[] = "assigned_location_id = ?";
                $updateParams[] = $to_assigned_location_id;
            }
            if ($to_event_id !== null) {
                $updateFields[] = "event_id = ?";
                $updateParams[] = $to_event_id;
            }
            if ($to_person_id !== null) {
                $updateFields[] = "assigned_to_id = ?";
                $updateParams[] = $to_person_id;
                $updateFields[] = "status = 'Checked Out'";
            }
            if (!empty($updateFields)) {
                $updateParams[] = $device['id'];
                $db->prepare("UPDATE devices SET " . implode(', ', $updateFields) . " WHERE id = ?")->execute($updateParams);

                logActivity($db, $device['id'], $device['asset_tag'], 'Move', $device['location_id'], $to_location_id, $device['assigned_to_id'], $to_person_id, $notes, $currentUser);

                $results['moved']++;
            }
        }
        $db->commit();
        echo json_encode(['success' => true, 'results' => $results], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handleBulkUpdate($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $asset_tags = $data['asset_tags'] ?? [];
    $device_ids = $data['device_ids'] ?? [];
    $updates = $data['updates'] ?? [];

    if (empty($updates)) {
        echo json_encode(['error' => 'No updates provided']);
        return;
    }

    $allowed = ['category','model','sku','status','location_id','assigned_location_id','assigned_to_id','event_id','account','live_or_dummy','notes'];
    $fields = [];
    $params = [];
    foreach ($allowed as $field) {
        if (isset($updates[$field])) {
            $fields[] = "$field = ?";
            $params[] = $updates[$field];
        }
    }

    if (empty($fields)) {
        echo json_encode(['error' => 'No valid fields to update']);
        return;
    }

    $db->beginTransaction();
    try {
        if (!empty($asset_tags)) {
            $placeholders = str_repeat('?,', count($asset_tags) - 1) . '?';
            $sql = "UPDATE devices SET " . implode(', ', $fields) . " WHERE asset_tag IN ($placeholders)";
            $allParams = array_merge($params, $asset_tags);
        } elseif (!empty($device_ids)) {
            $placeholders = str_repeat('?,', count($device_ids) - 1) . '?';
            $sql = "UPDATE devices SET " . implode(', ', $fields) . " WHERE id IN ($placeholders)";
            $allParams = array_merge($params, $device_ids);
        } else {
            echo json_encode(['error' => 'No asset_tags or device_ids provided']);
            return;
        }

        $stmt = $db->prepare($sql);
        $stmt->execute($allParams);
        $db->commit();
        
        logActivity($db, null, null, 'Bulk Update', null, null, null, null, 'Updated ' . $stmt->rowCount() . ' devices. Fields: ' . implode(', ', array_keys($updates)), $currentUser);
        
        echo json_encode(['success' => true, 'updated' => (int)$stmt->rowCount()]);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handleBulkCreate($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $devices = $data['devices'] ?? [];
    $event_id = $data['event_id'] ?? null;

    if (empty($devices)) {
        echo json_encode(['error' => 'No devices to create']);
        return;
    }

    $results = ['created' => 0, 'errors' => []];

    $db->beginTransaction();
    try {
        $stmt = $db->prepare("INSERT INTO devices (asset_tag, category, model, sku, status, event_id, last_scanned) 
                              VALUES (?, ?, ?, ?, 'Available', ?, NOW())
                              ON DUPLICATE KEY UPDATE
                              category = COALESCE(VALUES(category), category),
                              model = COALESCE(VALUES(model), model),
                              sku = COALESCE(VALUES(sku), sku),
                              event_id = COALESCE(VALUES(event_id), event_id),
                              last_scanned = NOW()");

        foreach ($devices as $d) {
            if (empty($d['asset_tag'])) {
                $results['errors'][] = 'Empty asset tag skipped';
                continue;
            }
            $stmt->execute([
                $d['asset_tag'],
                $d['category'] ?? null,
                $d['model'] ?? null,
                $d['sku'] ?? null,
                $event_id
            ]);
            $results['created']++;
        }
        $db->commit();
        
        logActivity($db, null, null, 'Bulk Create', null, null, null, null, 'Created ' . $results['created'] . ' devices', $currentUser);
        
        echo json_encode(['success' => true, 'results' => $results], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

// ============================================================
// IMPORT - With custom fields + selective field overwrite
// ============================================================

function handleImport($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $devices = $data['devices'] ?? [];
    $event_id = $data['event_id'] ?? null;
    $fields_to_update = $data['fields_to_update'] ?? null;
    $custom_field_names = $data['custom_field_names'] ?? [];

    if (empty($devices)) {
        echo json_encode(['error' => 'No devices to import']);
        return;
    }

    $results = ['imported' => 0, 'updated' => 0, 'skipped' => 0, 'errors' => []];

    $db->beginTransaction();
    try {
        foreach ($devices as $d) {
            if (empty($d['asset_tag'])) {
                $results['errors'][] = 'Empty asset tag skipped';
                continue;
            }

            $assetTag = trim($d['asset_tag']);

            // Resolve location name to ID
            $locationId = null;
            if (!empty($d['location'])) {
                $locName = strtoupper(trim($d['location']));
                $locStmt = $db->prepare("SELECT id FROM locations WHERE UPPER(name) = ?");
                $locStmt->execute([$locName]);
                $loc = $locStmt->fetch();
                if ($loc) {
                    $locationId = (int)$loc['id'];
                } else {
                    $db->prepare("INSERT INTO locations (name, event_id) VALUES (?, ?)")->execute([$locName, $event_id]);
                    $locationId = (int)$db->lastInsertId();
                }
            }

            // Resolve assigned_location name to ID
            $assignedLocationId = null;
            if (!empty($d['assigned_location'])) {
                $aLocName = strtoupper(trim($d['assigned_location']));
                $aLocStmt = $db->prepare("SELECT id FROM locations WHERE UPPER(name) = ?");
                $aLocStmt->execute([$aLocName]);
                $aLoc = $aLocStmt->fetch();
                if ($aLoc) {
                    $assignedLocationId = (int)$aLoc['id'];
                } else {
                    $db->prepare("INSERT INTO locations (name, event_id) VALUES (?, ?)")->execute([$aLocName, $event_id]);
                    $assignedLocationId = (int)$db->lastInsertId();
                }
            }

            // Resolve assigned_to name to ID
            $assignedToId = null;
            if (!empty($d['assigned_to'])) {
                $personName = strtoupper(trim($d['assigned_to']));
                $pStmt = $db->prepare("SELECT id FROM people WHERE UPPER(name) = ?");
                $pStmt->execute([$personName]);
                $person = $pStmt->fetch();
                if ($person) {
                    $assignedToId = (int)$person['id'];
                } else {
                    $db->prepare("INSERT INTO people (name, event_id) VALUES (?, ?)")->execute([$personName, $event_id]);
                    $assignedToId = (int)$db->lastInsertId();
                }
            }

            // Build custom_data
            $customData = [];
            if (!empty($custom_field_names)) {
                foreach ($custom_field_names as $cfName) {
                    if (isset($d[$cfName]) && $d[$cfName] !== '') {
                        $customData[$cfName] = $d[$cfName];
                    }
                }
            }

            // Check if device exists
            $existStmt = $db->prepare("SELECT id, custom_data FROM devices WHERE asset_tag = ?");
            $existStmt->execute([$assetTag]);
            $existing = $existStmt->fetch();

            if ($existing) {
                $updateFields = [];
                $updateParams = [];

                $shouldUpdate = function($fieldName) use ($fields_to_update) {
                    if ($fields_to_update === null) return true;
                    return in_array($fieldName, $fields_to_update);
                };

                if ($shouldUpdate('category') && isset($d['category'])) {
                    $updateFields[] = "category = ?";
                    $updateParams[] = $d['category'];
                }
                if ($shouldUpdate('model') && isset($d['model'])) {
                    $updateFields[] = "model = ?";
                    $updateParams[] = $d['model'];
                }
                if ($shouldUpdate('sku') && isset($d['sku'])) {
                    $updateFields[] = "sku = ?";
                    $updateParams[] = $d['sku'];
                }
                if ($shouldUpdate('status') && isset($d['status'])) {
                    $updateFields[] = "status = ?";
                    $updateParams[] = $d['status'];
                }
                if ($shouldUpdate('location') && $locationId !== null) {
                    $updateFields[] = "location_id = ?";
                    $updateParams[] = $locationId;
                }
                if ($shouldUpdate('assigned_location') && $assignedLocationId !== null) {
                    $updateFields[] = "assigned_location_id = ?";
                    $updateParams[] = $assignedLocationId;
                }
                if ($shouldUpdate('assigned_to') && $assignedToId !== null) {
                    $updateFields[] = "assigned_to_id = ?";
                    $updateParams[] = $assignedToId;
                }
                if ($shouldUpdate('account') && isset($d['account'])) {
                    $updateFields[] = "account = ?";
                    $updateParams[] = $d['account'];
                }
                if ($shouldUpdate('live_or_dummy') && isset($d['live_or_dummy'])) {
                    $updateFields[] = "live_or_dummy = ?";
                    $updateParams[] = $d['live_or_dummy'];
                }
                if ($shouldUpdate('notes') && isset($d['notes'])) {
                    $updateFields[] = "notes = ?";
                    $updateParams[] = $d['notes'];
                }
                if ($shouldUpdate('event') && $event_id) {
                    $updateFields[] = "event_id = ?";
                    $updateParams[] = $event_id;
                }

                if (!empty($customData) && $shouldUpdate('custom_fields')) {
                    $existingCustom = [];
                    if (!empty($existing['custom_data'])) {
                        $existingCustom = json_decode($existing['custom_data'], true) ?? [];
                    }
                    $mergedCustom = array_merge($existingCustom, $customData);
                    $updateFields[] = "custom_data = ?";
                    $updateParams[] = json_encode($mergedCustom);
                }

                $updateFields[] = "last_scanned = NOW()";

                if (count($updateFields) > 1) {
                    $updateParams[] = $existing['id'];
                    $updateSql = "UPDATE devices SET " . implode(', ', $updateFields) . " WHERE id = ?";
                    $db->prepare($updateSql)->execute($updateParams);
                    $results['updated']++;
                } else {
                    $results['skipped']++;
                }
            } else {
                $customDataJson = !empty($customData) ? json_encode($customData) : null;
                
                $insertStmt = $db->prepare("INSERT INTO devices (asset_tag, category, model, sku, status, location_id, assigned_location_id, assigned_to_id, event_id, account, live_or_dummy, notes, custom_data, last_scanned) 
                                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())");
                $insertStmt->execute([
                    $assetTag,
                    $d['category'] ?? null,
                    $d['model'] ?? null,
                    $d['sku'] ?? null,
                    $d['status'] ?? 'Available',
                    $locationId,
                    $assignedLocationId ?? $locationId,
                    $assignedToId,
                    $event_id,
                    $d['account'] ?? null,
                    $d['live_or_dummy'] ?? 'N/A',
                    $d['notes'] ?? null,
                    $customDataJson
                ]);
                $results['imported']++;
            }
        }
        $db->commit();
        
        logActivity($db, null, null, 'Import', null, null, null, null, 
            'Imported: ' . $results['imported'] . ' new, ' . $results['updated'] . ' updated, ' . $results['skipped'] . ' skipped', $currentUser);
        
        echo json_encode(['success' => true, 'results' => $results], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

// ============================================================
// EXPORT - Includes custom fields + assigned location
// ============================================================

function handleExport($db) {
    $event_id = isset($_GET['event_id']) ? (int)$_GET['event_id'] : null;
    $format = isset($_GET['format']) ? $_GET['format'] : 'csv';
    $status = isset($_GET['status']) ? $_GET['status'] : null;
    $category = isset($_GET['category']) ? $_GET['category'] : null;
    $location_id = isset($_GET['location_id']) ? (int)$_GET['location_id'] : null;

    $sql = "SELECT d.asset_tag, d.category, d.model, d.sku, d.status, 
                   l.name as current_location, al.name as assigned_location,
                   p.name as assigned_to, e.name as event,
                   d.account, d.live_or_dummy, d.notes, d.custom_data,
                   d.last_scanned, d.created_at, d.updated_at
            FROM devices d 
            LEFT JOIN locations l ON d.location_id = l.id 
            LEFT JOIN locations al ON d.assigned_location_id = al.id
            LEFT JOIN people p ON d.assigned_to_id = p.id 
            LEFT JOIN events e ON d.event_id = e.id";
    $params = [];
    $conditions = [];
    if ($event_id) {
        $conditions[] = "d.event_id = ?";
        $params[] = $event_id;
    }
    if ($status) {
        $conditions[] = "d.status = ?";
        $params[] = $status;
    }
    if ($category) {
        $conditions[] = "d.category LIKE ?";
        $params[] = "%" . $category . "%";
    }
    if ($location_id) {
        $conditions[] = "(d.location_id = ? OR d.assigned_location_id = ?)";
        $params[] = $location_id;
        $params[] = $location_id;
    }
    if (!empty($conditions)) {
        $sql .= " WHERE " . implode(" AND ", $conditions);
    }
    $sql .= " ORDER BY d.category, d.model, d.asset_tag";

    $stmt = $db->prepare($sql);
    $stmt->execute($params);
    $devices = $stmt->fetchAll();

    // Collect all custom field names
    $allCustomFieldNames = [];
    foreach ($devices as &$row) {
        if (!empty($row['custom_data'])) {
            $customObj = json_decode($row['custom_data'], true);
            if (is_array($customObj)) {
                foreach (array_keys($customObj) as $key) {
                    if (!in_array($key, $allCustomFieldNames)) {
                        $allCustomFieldNames[] = $key;
                    }
                }
            }
            $row['_custom_parsed'] = $customObj;
        } else {
            $row['_custom_parsed'] = [];
        }
    }
    unset($row);
    sort($allCustomFieldNames);

    if ($format === 'csv') {
        header('Content-Type: text/csv');
        header('Content-Disposition: attachment; filename="inventory_export_' . date('Y-m-d_His') . '.csv"');

        $output = fopen('php://output', 'w');
        
        $header = ['Asset Tag', 'Category', 'Model', 'SKU', 'Status', 'Current Location', 'Assigned Location', 'Assigned To', 'Event', 'Account', 'Live/Dummy', 'Notes'];
        foreach ($allCustomFieldNames as $cfName) {
            $header[] = $cfName;
        }
        $header[] = 'Last Scanned';
        $header[] = 'Created';
        $header[] = 'Updated';
        fputcsv($output, $header);
        
        foreach ($devices as $row) {
            $csvRow = [
                $row['asset_tag'], $row['category'], $row['model'], $row['sku'],
                $row['status'], $row['current_location'], $row['assigned_location'],
                $row['assigned_to'], $row['event'],
                $row['account'], $row['live_or_dummy'], $row['notes']
            ];
            foreach ($allCustomFieldNames as $cfName) {
                $csvRow[] = isset($row['_custom_parsed'][$cfName]) ? $row['_custom_parsed'][$cfName] : '';
            }
            $csvRow[] = $row['last_scanned'];
            $csvRow[] = $row['created_at'];
            $csvRow[] = $row['updated_at'];
            fputcsv($output, $csvRow);
        }
        fclose($output);
    } else {
        foreach ($devices as &$row) {
            $row['custom_data'] = $row['_custom_parsed'];
            unset($row['_custom_parsed']);
        }
        unset($row);
        echo json_encode(['devices' => $devices, 'count' => count($devices), 'custom_field_names' => $allCustomFieldNames], JSON_NUMERIC_CHECK);
    }
}

function handleScanVerify($db, $currentUser) {
    $data = json_decode(file_get_contents('php://input'), true);
    $asset_tags = $data['asset_tags'] ?? [];
    $event_id = $data['event_id'] ?? null;
    $location_id = $data['location_id'] ?? null;

    $results = ['verified' => 0, 'new_devices' => 0, 'tags_verified' => [], 'tags_new' => []];

    $db->beginTransaction();
    try {
        foreach ($asset_tags as $tag) {
            $tag = trim($tag);
            if (empty($tag)) continue;

            $stmt = $db->prepare("SELECT id FROM devices WHERE asset_tag = ?");
            $stmt->execute([$tag]);
            $device = $stmt->fetch();

            if ($device) {
                $db->prepare("UPDATE devices SET last_scanned = NOW(), location_id = COALESCE(?, location_id) WHERE id = ?")
                   ->execute([$location_id, $device['id']]);
                $results['verified']++;
                $results['tags_verified'][] = $tag;

                logActivity($db, $device['id'], $tag, 'Scan', null, $location_id, null, null, 'Verified on-site', $currentUser);
            } else {
                $results['new_devices']++;
                $results['tags_new'][] = $tag;
            }
        }
        $db->commit();
        echo json_encode(['success' => true, 'results' => $results], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        $db->rollBack();
        echo json_encode(['error' => $e->getMessage()]);
    }
}

// ============================================================
// CUSTOM FIELDS - Registry-based management
// ============================================================

function handleCustomFields($db, $method) {
    switch ($method) {
        case 'GET':
            // Return both registry fields and discovered fields from data
            $registryFields = [];
            try {
                $stmt = $db->query("SELECT * FROM custom_fields_registry ORDER BY sort_order, field_label");
                $registryFields = $stmt->fetchAll();
            } catch (PDOException $e) {
                // Table might not exist yet
            }
            
            // Also discover fields from existing data
            $stmt2 = $db->query("SELECT custom_data FROM devices WHERE custom_data IS NOT NULL AND custom_data != ''");
            $rows = $stmt2->fetchAll();
            $discoveredFields = [];
            foreach ($rows as $row) {
                $data = json_decode($row['custom_data'], true);
                if (is_array($data)) {
                    foreach (array_keys($data) as $key) {
                        if (!in_array($key, $discoveredFields)) {
                            $discoveredFields[] = $key;
                        }
                    }
                }
            }
            sort($discoveredFields);
            
            echo json_encode([
                'custom_fields' => $discoveredFields,
                'registry' => $registryFields,
                'count' => count($discoveredFields)
            ]);
            break;
            
        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            $fieldKey = isset($data['field_key']) ? trim($data['field_key']) : '';
            $fieldLabel = isset($data['field_label']) ? trim($data['field_label']) : '';
            $fieldType = isset($data['field_type']) ? $data['field_type'] : 'text';
            $isRequired = isset($data['is_required']) ? (int)$data['is_required'] : 0;
            
            if (empty($fieldKey) || empty($fieldLabel)) {
                echo json_encode(['error' => 'field_key and field_label are required']);
                return;
            }
            
            // Sanitize field_key to be a valid key
            $fieldKey = preg_replace('/[^a-z0-9_]/', '_', strtolower($fieldKey));
            
            try {
                $stmt = $db->prepare("INSERT INTO custom_fields_registry (field_key, field_label, field_type, is_required) VALUES (?, ?, ?, ?)
                                      ON DUPLICATE KEY UPDATE field_label = VALUES(field_label), field_type = VALUES(field_type), is_required = VALUES(is_required)");
                $stmt->execute([$fieldKey, $fieldLabel, $fieldType, $isRequired]);
                echo json_encode(['success' => true, 'field_key' => $fieldKey, 'id' => (int)$db->lastInsertId()]);
            } catch (PDOException $e) {
                echo json_encode(['error' => $e->getMessage()]);
            }
            break;
            
        case 'DELETE':
            $fieldKey = isset($_GET['field_key']) ? $_GET['field_key'] : '';
            $removeData = isset($_GET['remove_data']) ? $_GET['remove_data'] : '0';
            
            if (empty($fieldKey)) {
                echo json_encode(['error' => 'field_key is required']);
                return;
            }
            
            // Remove from registry
            $db->prepare("DELETE FROM custom_fields_registry WHERE field_key = ?")->execute([$fieldKey]);
            
            // Optionally remove from all device custom_data
            if ($removeData === '1') {
                $stmt = $db->query("SELECT id, custom_data FROM devices WHERE custom_data IS NOT NULL AND custom_data != ''");
                $rows = $stmt->fetchAll();
                foreach ($rows as $row) {
                    $customData = json_decode($row['custom_data'], true);
                    if (is_array($customData) && isset($customData[$fieldKey])) {
                        unset($customData[$fieldKey]);
                        $newJson = !empty($customData) ? json_encode($customData) : null;
                        $db->prepare("UPDATE devices SET custom_data = ? WHERE id = ?")->execute([$newJson, $row['id']]);
                    }
                }
            }
            
            echo json_encode(['success' => true]);
            break;
            
        default:
            echo json_encode(['error' => 'Method not supported']);
    }
}

// ============================================================
// LOCATION HANDLERS
// ============================================================

function handleLocations($db, $method, $currentUser) {
    switch ($method) {
        case 'GET':
            $event_id = isset($_GET['event_id']) ? (int)$_GET['event_id'] : null;
            $sql = "SELECT l.*, 
                    COUNT(DISTINCT d1.id) as device_count,
                    COUNT(DISTINCT d2.id) as assigned_device_count
                    FROM locations l 
                    LEFT JOIN devices d1 ON d1.location_id = l.id
                    LEFT JOIN devices d2 ON d2.assigned_location_id = l.id";
            $params = [];
            if ($event_id) {
                $sql .= " WHERE l.event_id = ? OR l.event_id IS NULL";
                $params[] = $event_id;
            }
            $sql .= " GROUP BY l.id ORDER BY l.name";
            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            echo json_encode(['locations' => $stmt->fetchAll()], JSON_NUMERIC_CHECK);
            break;

        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            if (empty($data['name'])) {
                echo json_encode(['error' => 'Name is required']);
                return;
            }
            $name = strtoupper(trim($data['name']));
            $checkStmt = $db->prepare("SELECT id, name FROM locations WHERE UPPER(name) = ?");
            $checkStmt->execute([$name]);
            $existing = $checkStmt->fetch();
            if ($existing) {
                echo json_encode(['success' => true, 'id' => (int)$existing['id'], 'name' => $existing['name'], 'existing' => true]);
                return;
            }
            $stmt = $db->prepare("INSERT INTO locations (name, event_id) VALUES (?, ?)");
            $stmt->execute([$name, $data['event_id'] ?? null]);
            $locId = (int)$db->lastInsertId();
            
            logActivity($db, null, null, 'Location Created', null, $locId, null, null, "Created location: $name", $currentUser);
            
            echo json_encode(['success' => true, 'id' => $locId, 'name' => $name]);
            break;

        case 'DELETE':
            $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
            $db->prepare("DELETE FROM locations WHERE id = ?")->execute([$id]);
            logActivity($db, null, null, 'Location Deleted', null, null, null, null, "Deleted location ID: $id", $currentUser);
            echo json_encode(['success' => true]);
            break;
    }
}

// ============================================================
// PEOPLE HANDLERS
// ============================================================

function handlePeople($db, $method, $currentUser) {
    switch ($method) {
        case 'GET':
            $event_id = isset($_GET['event_id']) ? (int)$_GET['event_id'] : null;
            $sql = "SELECT p.*, COUNT(d.id) as device_count FROM people p LEFT JOIN devices d ON d.assigned_to_id = p.id";
            $params = [];
            if ($event_id) {
                $sql .= " WHERE p.event_id = ? OR p.event_id IS NULL";
                $params[] = $event_id;
            }
            $sql .= " GROUP BY p.id ORDER BY p.name";
            $stmt = $db->prepare($sql);
            $stmt->execute($params);
            echo json_encode(['people' => $stmt->fetchAll()], JSON_NUMERIC_CHECK);
            break;

        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            if (empty($data['name'])) {
                echo json_encode(['error' => 'Name is required']);
                return;
            }
            $name = strtoupper(trim($data['name']));
            $role = isset($data['role']) ? strtoupper(trim($data['role'])) : null;
            $checkStmt = $db->prepare("SELECT id, name FROM people WHERE UPPER(name) = ?");
            $checkStmt->execute([$name]);
            $existing = $checkStmt->fetch();
            if ($existing) {
                echo json_encode(['success' => true, 'id' => (int)$existing['id'], 'name' => $existing['name'], 'existing' => true]);
                return;
            }
            $stmt = $db->prepare("INSERT INTO people (name, role, email, event_id) VALUES (?, ?, ?, ?)");
            $stmt->execute([$name, $role, $data['email'] ?? null, $data['event_id'] ?? null]);
            
            logActivity($db, null, null, 'Person Created', null, null, null, null, "Created person: $name", $currentUser);
            
            echo json_encode(['success' => true, 'id' => (int)$db->lastInsertId(), 'name' => $name]);
            break;

        case 'DELETE':
            $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
            $db->prepare("DELETE FROM people WHERE id = ?")->execute([$id]);
            logActivity($db, null, null, 'Person Deleted', null, null, null, null, "Deleted person ID: $id", $currentUser);
            echo json_encode(['success' => true]);
            break;
    }
}

// ============================================================
// EVENT HANDLERS
// ============================================================

function handleEvents($db, $method, $currentUser) {
    switch ($method) {
        case 'GET':
            $stmt = $db->query("SELECT e.*, COUNT(d.id) as device_count FROM events e LEFT JOIN devices d ON d.event_id = e.id GROUP BY e.id ORDER BY e.created_at DESC");
            echo json_encode(['events' => $stmt->fetchAll()], JSON_NUMERIC_CHECK);
            break;

        case 'POST':
            $data = json_decode(file_get_contents('php://input'), true);
            if (empty($data['name'])) {
                echo json_encode(['error' => 'Name is required']);
                return;
            }
            $name = strtoupper(trim($data['name']));
            $checkStmt = $db->prepare("SELECT id, name FROM events WHERE UPPER(name) = ?");
            $checkStmt->execute([$name]);
            $existing = $checkStmt->fetch();
            if ($existing) {
                echo json_encode(['success' => true, 'id' => (int)$existing['id'], 'name' => $existing['name'], 'existing' => true]);
                return;
            }
            $stmt = $db->prepare("INSERT INTO events (name, start_date, end_date) VALUES (?, ?, ?)");
            $stmt->execute([$name, $data['start_date'] ?? null, $data['end_date'] ?? null]);
            
            logActivity($db, null, null, 'Event Created', null, null, null, null, "Created event: $name", $currentUser);
            
            echo json_encode(['success' => true, 'id' => (int)$db->lastInsertId(), 'name' => $name]);
            break;
    }
}

// ============================================================
// ACTIVITY LOG
// ============================================================

function handleActivity($db) {
    try {
        $device_id = isset($_GET['device_id']) ? (int)$_GET['device_id'] : null;
        $action = isset($_GET['action_type']) ? $_GET['action_type'] : null;
        $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 200;
        $date_from = isset($_GET['date_from']) ? $_GET['date_from'] : null;
        $date_to = isset($_GET['date_to']) ? $_GET['date_to'] : null;
        $user_filter = isset($_GET['user']) ? $_GET['user'] : null;

        // Dynamically check which columns exist in devices table
        $deviceCols = [];
        try {
            $colStmt = $db->query("SHOW COLUMNS FROM devices");
            $deviceCols = $colStmt->fetchAll(PDO::FETCH_COLUMN);
        } catch (Exception $e) {}
        $hasMake = in_array('make', $deviceCols);
        $hasSku = in_array('sku', $deviceCols);

        $makeSelect = $hasMake ? "COALESCE(d.make, d2.make) as make," : "NULL as make,";
        $skuSelect = $hasSku ? "COALESCE(d.sku, d2.sku) as sku," : "NULL as sku,";

        $sql = "SELECT al.id, al.device_id, al.action, al.asset_tag, al.notes, al.performed_by, al.created_at,
                       al.from_location_id, al.to_location_id, al.from_person_id, al.to_person_id, al.user_id,
                       COALESCE(d.model, d2.model) as model,
                       COALESCE(d.category, d2.category) as category,
                       $makeSelect
                       $skuSelect
                       COALESCE(dl.name, dl2.name) as current_location,
                       COALESCE(dp.name, dp2.name) as current_person,
                       fl.name as from_location, tl.name as to_location,
                       fp.name as from_person, tp.name as to_person
                FROM activity_log al
                LEFT JOIN devices d ON al.device_id = d.id
                LEFT JOIN devices d2 ON (al.device_id IS NULL AND al.asset_tag IS NOT NULL AND al.asset_tag = d2.asset_tag)
                LEFT JOIN locations dl ON d.location_id = dl.id
                LEFT JOIN locations dl2 ON d2.location_id = dl2.id
                LEFT JOIN people dp ON d.assigned_to_id = dp.id
                LEFT JOIN people dp2 ON d2.assigned_to_id = dp2.id
                LEFT JOIN locations fl ON al.from_location_id = fl.id
                LEFT JOIN locations tl ON al.to_location_id = tl.id
                LEFT JOIN people fp ON al.from_person_id = fp.id
                LEFT JOIN people tp ON al.to_person_id = tp.id";
        $params = [];
        $conditions = [];
        if ($device_id) {
            $conditions[] = "al.device_id = ?";
            $params[] = $device_id;
        }
        if ($action) {
            $conditions[] = "al.action = ?";
            $params[] = $action;
        }
        if ($date_from) {
            $conditions[] = "al.created_at >= ?";
            $params[] = $date_from . ' 00:00:00';
        }
        if ($date_to) {
            $conditions[] = "al.created_at <= ?";
            $params[] = $date_to . ' 23:59:59';
        }
        if ($user_filter) {
            $conditions[] = "(al.performed_by LIKE ? OR al.performed_by = ?)";
            $params[] = '%' . $user_filter . '%';
            $params[] = $user_filter;
        }
        if (!empty($conditions)) {
            $sql .= " WHERE " . implode(" AND ", $conditions);
        }
        $sql .= " ORDER BY al.created_at DESC LIMIT " . (int)$limit;

        $stmt = $db->prepare($sql);
        $stmt->execute($params);
        
        $results = $stmt->fetchAll(PDO::FETCH_ASSOC);
        
        // Ensure asset_tag and sku are always strings
        foreach ($results as &$row) {
            if (isset($row['asset_tag']) && is_numeric($row['asset_tag'])) {
                $row['asset_tag'] = (string)$row['asset_tag'];
            }
            if (isset($row['sku']) && is_numeric($row['sku'])) {
                $row['sku'] = (string)$row['sku'];
            }
            // Remove raw ID columns that might confuse the client
            unset($row['from_location_id']);
            unset($row['to_location_id']);
            unset($row['from_person_id']);
            unset($row['to_person_id']);
            unset($row['user_id']);
        }
        unset($row);
        
        echo json_encode(['activity' => $results, 'count' => count($results)], JSON_NUMERIC_CHECK);
    } catch (Exception $e) {
        // Fallback: try simple query without JOINs
        try {
            $stmt2 = $db->prepare("SELECT * FROM activity_log ORDER BY created_at DESC LIMIT 50");
            $stmt2->execute();
            $results2 = $stmt2->fetchAll(PDO::FETCH_ASSOC);
            echo json_encode(['activity' => $results2, 'count' => count($results2), 'fallback' => true], JSON_NUMERIC_CHECK);
        } catch (Exception $e2) {
            echo json_encode(['activity' => [], 'error' => $e->getMessage() . ' | Fallback: ' . $e2->getMessage(), 'count' => 0]);
        }
    }
}

// ============================================================
// DEBUG: Activity Log Diagnosis
// ============================================================

function handleActivityDebug($db) {
    $results = [];
    
    // 1. Check activity_log table structure
    try {
        $cols = $db->query("SHOW COLUMNS FROM activity_log")->fetchAll(PDO::FETCH_COLUMN);
        $results['activity_log_columns'] = $cols;
    } catch (Exception $e) {
        $results['activity_log_columns_error'] = $e->getMessage();
    }
    
    // 2. Sample 5 recent activity_log rows (raw)
    try {
        $stmt = $db->query("SELECT id, device_id, asset_tag, action FROM activity_log ORDER BY created_at DESC LIMIT 5");
        $results['sample_raw_rows'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $results['sample_raw_rows_error'] = $e->getMessage();
    }
    
    // 3. Check if any activity_log rows have device_id populated
    try {
        $stmt = $db->query("SELECT COUNT(*) as total, SUM(CASE WHEN device_id IS NOT NULL THEN 1 ELSE 0 END) as with_device_id, SUM(CASE WHEN asset_tag IS NOT NULL AND asset_tag != '' THEN 1 ELSE 0 END) as with_asset_tag FROM activity_log");
        $results['counts'] = $stmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $results['counts_error'] = $e->getMessage();
    }
    
    // 4. Check if asset_tags in activity_log match devices table
    try {
        $stmt = $db->query("SELECT al.asset_tag as log_tag, d.asset_tag as device_tag, d.id as device_id, d.model FROM activity_log al LEFT JOIN devices d ON al.asset_tag = d.asset_tag WHERE al.asset_tag IS NOT NULL AND al.asset_tag != '' ORDER BY al.created_at DESC LIMIT 5");
        $results['asset_tag_match_check'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $results['asset_tag_match_error'] = $e->getMessage();
    }
    
    // 5. Check devices table sample
    try {
        $stmt = $db->query("SELECT id, asset_tag, model, category, make, sku FROM devices LIMIT 3");
        $results['sample_devices'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $results['sample_devices_error'] = $e->getMessage();
    }
    
    // 6. Try the full activity query on just 1 row to see what comes back
    try {
        $stmt = $db->query("SELECT al.id, al.device_id, al.asset_tag, COALESCE(d.model, d2.model) as model, COALESCE(d.category, d2.category) as category FROM activity_log al LEFT JOIN devices d ON al.device_id = d.id LEFT JOIN devices d2 ON (al.device_id IS NULL AND al.asset_tag IS NOT NULL AND al.asset_tag = d2.asset_tag) ORDER BY al.created_at DESC LIMIT 3");
        $results['joined_query_test'] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        $results['joined_query_error'] = $e->getMessage();
    }
    
    echo json_encode($results, JSON_PRETTY_PRINT);
}

// ============================================================
// STATS
// ============================================================

function handleStats($db) {
    $event_id = isset($_GET['event_id']) ? (int)$_GET['event_id'] : null;

    $where = $event_id ? "WHERE event_id = $event_id" : "";

    $stats = [];
    $stats['total_devices'] = (int)$db->query("SELECT COUNT(*) as c FROM devices $where")->fetch()['c'];
    $stats['available'] = (int)$db->query("SELECT COUNT(*) as c FROM devices $where" . ($where ? " AND" : " WHERE") . " status = 'Available'")->fetch()['c'];
    $stats['checked_out'] = (int)$db->query("SELECT COUNT(*) as c FROM devices $where" . ($where ? " AND" : " WHERE") . " status = 'Checked Out'")->fetch()['c'];
    $stats['missing'] = (int)$db->query("SELECT COUNT(*) as c FROM devices $where" . ($where ? " AND" : " WHERE") . " status = 'Missing'")->fetch()['c'];

    $stmt = $db->query("SELECT category, COUNT(*) as count FROM devices $where GROUP BY category ORDER BY count DESC");
    $stats['by_category'] = $stmt->fetchAll();

    $stmt = $db->query("SELECT l.name, COUNT(d.id) as count FROM devices d JOIN locations l ON d.location_id = l.id " . ($event_id ? "WHERE d.event_id = $event_id " : "") . "GROUP BY l.name ORDER BY count DESC");
    $stats['by_location'] = $stmt->fetchAll();

    echo json_encode($stats, JSON_NUMERIC_CHECK);
}
?>
