import Foundation
import Darwin

enum LedgerError: Error, LocalizedError {
    case invalid(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalid(let message): message
        case .notFound: "기록을 찾을 수 없습니다."
        }
    }
}

final class LedgerStore {
    let appDirectory: URL
    let dbURL: URL
    let backupDirectory: URL
    private var db: SQLiteDatabase

    init(appDirectory: URL? = nil) throws {
        let override = ProcessInfo.processInfo.environment["WEDDING_LEDGER_HOME"]
        if let override, !override.isEmpty {
            self.appDirectory = URL(fileURLWithPath: override).standardizedFileURL
        } else if let appDirectory {
            self.appDirectory = appDirectory
        } else {
            self.appDirectory = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/\(appName)", isDirectory: true)
        }
        self.dbURL = self.appDirectory.appendingPathComponent("wedding_ledger.sqlite3")
        self.backupDirectory = self.appDirectory.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: self.appDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: self.backupDirectory, withIntermediateDirectories: true)
        chmod(self.appDirectory.path, 0o700)
        self.db = try SQLiteDatabase(path: dbURL)
        try initialize()
        chmod(dbURL.path, 0o600)
    }

    func initialize() throws {
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """
        )
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS entries (
                id TEXT PRIMARY KEY,
                mode TEXT NOT NULL CHECK (mode IN ('test', 'live')),
                envelope_no INTEGER NOT NULL DEFAULT 0,
                transfer_no INTEGER NOT NULL DEFAULT 0,
                name TEXT NOT NULL,
                group_name TEXT NOT NULL DEFAULT '미분류',
                relationship TEXT DEFAULT '',
                target_person TEXT DEFAULT '',
                amount INTEGER NOT NULL CHECK (amount >= 0),
                meal_ticket_count INTEGER NOT NULL DEFAULT 0 CHECK (meal_ticket_count >= 0),
                child_meal_ticket_count INTEGER NOT NULL DEFAULT 0 CHECK (child_meal_ticket_count >= 0),
                payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'transfer', 'other')),
                memo TEXT DEFAULT '',
                status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'void')),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        try ensureEntryColumn(name: "target_person", alterSQL: "ALTER TABLE entries ADD COLUMN target_person TEXT DEFAULT ''")
        try ensureEntryColumn(name: "transfer_no", alterSQL: "ALTER TABLE entries ADD COLUMN transfer_no INTEGER NOT NULL DEFAULT 0")
        try ensureEntryColumn(name: "child_meal_ticket_count", alterSQL: "ALTER TABLE entries ADD COLUMN child_meal_ticket_count INTEGER NOT NULL DEFAULT 0 CHECK (child_meal_ticket_count >= 0)")
        try backfillTransferNumbers()
        try migrateEntryTableSchemaIfNeeded()
        try db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_entries_envelope_unique ON entries(mode, envelope_no) WHERE payment_method != 'transfer' AND envelope_no > 0")
        try db.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_entries_transfer_unique ON entries(mode, transfer_no) WHERE payment_method = 'transfer' AND transfer_no > 0")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_name ON entries(name)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_group_name ON entries(group_name)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_target_person ON entries(target_person)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_transfer_no ON entries(transfer_no)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_amount ON entries(amount)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_status ON entries(status)")
        try db.execute("CREATE INDEX IF NOT EXISTS idx_entries_mode ON entries(mode)")
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS lookup_items (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL CHECK (kind IN ('group', 'relationship')),
                value TEXT NOT NULL,
                usage_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                UNIQUE(kind, value)
            );
            """
        )
        try db.execute("CREATE INDEX IF NOT EXISTS idx_lookup_items_kind ON lookup_items(kind)")
        try db.execute(
            """
            CREATE TABLE IF NOT EXISTS audit_logs (
                id TEXT PRIMARY KEY,
                entry_id TEXT,
                action TEXT NOT NULL,
                before_json TEXT,
                after_json TEXT,
                reason TEXT DEFAULT '',
                created_at TEXT NOT NULL,
                FOREIGN KEY(entry_id) REFERENCES entries(id)
            );
            """
        )
        if getSetting("schema_version") == nil { try setSetting("schema_version", "1") }
        if getSetting("current_mode") == nil { try setSetting("current_mode", LedgerMode.test.rawValue) }
        try seedLookupItemsFromEntries()
    }

    func getSetting(_ key: String) -> String? {
        guard let row = try? db.query("SELECT value FROM settings WHERE key = ?", [.text(key)]).first else {
            return nil
        }
        return row["value"]?.string
    }

    func setSetting(_ key: String, _ value: String) throws {
        try db.execute(
            """
            INSERT INTO settings(key, value)
            VALUES(?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value
            """,
            [.text(key), .text(value)]
        )
    }

    func isConfigured() -> Bool {
        getSetting("password_hash") != nil
    }

    func setupAuth(password: String) throws -> String {
        if isConfigured() { throw LedgerError.invalid("이미 비밀번호가 설정되어 있습니다.") }
        let normalized = normalizeKeyboardSecret(password)
        if normalized.count < 4 { throw LedgerError.invalid("비밀번호는 4자 이상이어야 합니다.") }
        let passwordSalt = try generateSalt()
        let recoverySalt = try generateSalt()
        let recoveryKey = try generateRecoveryKey()
        try setSetting("password_salt", passwordSalt)
        try setSetting("password_hash", try hashSecret(normalized, salt: passwordSalt))
        try setSetting("password_iterations", String(pbkdf2Iterations))
        try setSetting("recovery_salt", recoverySalt)
        try setSetting("recovery_hash", try hashSecret(normalizeRecoveryKey(recoveryKey), salt: recoverySalt))
        try setSetting("recovery_iterations", String(pbkdf2Iterations))
        try setSetting("configured_at", nowString())
        return recoveryKey
    }

    func verifyPassword(_ password: String) -> Bool {
        guard let salt = getSetting("password_salt"), let expected = getSetting("password_hash") else {
            return false
        }
        let iterations = Int(getSetting("password_iterations") ?? "") ?? pbkdf2Iterations
        let normalized = normalizeKeyboardSecret(password)
        return verifySecret(normalized, salt: salt, expectedHash: expected, iterations: iterations)
            || verifySecret(password, salt: salt, expectedHash: expected, iterations: iterations)
    }

    func resetPassword(recoveryKey: String, newPassword: String) throws -> Bool {
        guard let salt = getSetting("recovery_salt"), let expected = getSetting("recovery_hash") else {
            return false
        }
        let iterations = Int(getSetting("recovery_iterations") ?? "") ?? pbkdf2Iterations
        guard verifySecret(normalizeRecoveryKey(recoveryKey), salt: salt, expectedHash: expected, iterations: iterations) else {
            return false
        }
        let normalized = normalizeKeyboardSecret(newPassword)
        if normalized.count < 4 { throw LedgerError.invalid("새 비밀번호는 4자 이상이어야 합니다.") }
        let passwordSalt = try generateSalt()
        try setSetting("password_salt", passwordSalt)
        try setSetting("password_hash", try hashSecret(normalized, salt: passwordSalt))
        try setSetting("password_iterations", String(pbkdf2Iterations))
        try setSetting("password_reset_at", nowString())
        return true
    }

    func mode() -> LedgerMode {
        LedgerMode(rawValue: getSetting("current_mode") ?? "") ?? .test
    }

    func setMode(_ mode: LedgerMode) throws {
        try setSetting("current_mode", mode.rawValue)
    }

    func themePreference() -> ThemePreference {
        ThemePreference(rawValue: getSetting("theme_preference") ?? "") ?? .dark
    }

    func setThemePreference(_ preference: ThemePreference) throws {
        try setSetting("theme_preference", preference.rawValue)
    }

    func operationSettings() -> OperationSettings {
        OperationSettings(
            eventTitle: getSetting("event_title") ?? "",
            totalMealTickets: Int(getSetting("total_meal_tickets") ?? "") ?? 0,
            totalChildMealTickets: Int(getSetting("total_child_meal_tickets") ?? "") ?? 0,
            expectedEnvelopeCount: Int(getSetting("expected_envelope_count") ?? "") ?? 0,
            operationNote: getSetting("operation_note") ?? ""
        )
    }

    func setOperationSettings(_ settings: OperationSettings) throws {
        try setSetting("event_title", settings.eventTitle.trimmingCharacters(in: .whitespacesAndNewlines))
        try setSetting("total_meal_tickets", String(max(0, settings.totalMealTickets)))
        try setSetting("total_child_meal_tickets", String(max(0, settings.totalChildMealTickets)))
        try setSetting("expected_envelope_count", String(max(0, settings.expectedEnvelopeCount)))
        try setSetting("operation_note", settings.operationNote.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func nextEnvelopeNo(mode: LedgerMode? = nil) throws -> Int {
        let mode = mode ?? self.mode()
        let rows = try db.query(
            "SELECT COALESCE(MAX(envelope_no), 0) + 1 AS next_no FROM entries WHERE mode = ? AND payment_method != ? AND envelope_no > 0",
            [.text(mode.rawValue), .text(PaymentMethod.transfer.rawValue)]
        )
        return rows.first?["next_no"]?.int ?? 1
    }

    func nextTransferNo(mode: LedgerMode? = nil) throws -> Int {
        let mode = mode ?? self.mode()
        let rows = try db.query(
            "SELECT COALESCE(MAX(transfer_no), 0) + 1 AS next_no FROM entries WHERE mode = ? AND payment_method = ? AND transfer_no > 0",
            [.text(mode.rawValue), .text(PaymentMethod.transfer.rawValue)]
        )
        return rows.first?["next_no"]?.int ?? 1
    }

    func nameExists(mode: LedgerMode, name: String, excluding id: String? = nil) throws -> Bool {
        var sql = "SELECT 1 AS exists_row FROM entries WHERE mode = ? AND name = ? AND status = ?"
        var values: [SQLiteValue] = [.text(mode.rawValue), .text(name.trimmingCharacters(in: .whitespacesAndNewlines)), .text(EntryStatus.active.rawValue)]
        if let id {
            sql += " AND id != ?"
            values.append(.text(id))
        }
        return !(try db.query(sql, values)).isEmpty
    }

    func activeEntriesNamed(mode: LedgerMode, name: String) throws -> [LedgerEntry] {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return [] }
        return try db.query(
            """
            SELECT * FROM entries
            WHERE mode = ? AND name = ? AND status = ?
            ORDER BY envelope_no ASC, created_at ASC
            """,
            [.text(mode.rawValue), .text(cleanName), .text(EntryStatus.active.rawValue)]
        ).map(entryFromRow)
    }

    func createEntry(_ draft: EntryDraft, mode: LedgerMode) throws -> LedgerEntry {
        let clean = try validateDraft(draft, mode: mode)
        let id = UUID().uuidString
        let createdAt = try createdAtString(for: clean)
        do {
            try db.execute(
                """
                INSERT INTO entries (
                    id, mode, envelope_no, transfer_no, name, group_name, relationship, target_person, amount,
                    meal_ticket_count, child_meal_ticket_count, payment_method, memo, status, created_at, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    .text(id), .text(mode.rawValue), .integer(clean.envelopeNo), .integer(clean.transferNo), .text(clean.name),
                    .text(clean.groupName), .text(clean.relationship), .text(clean.targetPerson), .integer(clean.amount),
                    .integer(clean.mealTicketCount), .integer(clean.childMealTicketCount), .text(clean.paymentMethod.rawValue), .text(clean.memo),
                    .text(EntryStatus.active.rawValue), .text(createdAt), .text(createdAt)
                ]
            )
        } catch {
            throw LedgerError.invalid(clean.paymentMethod == .transfer ? "계좌차번이 이미 사용되었습니다." : "봉투번호가 이미 사용되었습니다.")
        }
        let entry = try getEntry(id: id)!
        try rememberLookupValues(groupName: entry.groupName, relationship: entry.relationship)
        try insertAudit(entryID: id, action: "create", before: nil, after: entry, reason: "")
        return entry
    }

    func findEntries(filters: EntryFilters = EntryFilters(), mode: LedgerMode? = nil) throws -> [LedgerEntry] {
        var clauses: [String] = []
        var values: [SQLiteValue] = []
        if let mode {
            clauses.append("mode = ?")
            values.append(.text(mode.rawValue))
        }
        if !filters.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append(filters.exactName ? "name = ?" : "name LIKE ?")
            values.append(.text(filters.exactName ? filters.name.trimmingCharacters(in: .whitespacesAndNewlines) : "%\(filters.name)%"))
        }
        if !filters.groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append("group_name LIKE ?")
            values.append(.text("%\(filters.groupName)%"))
        }
        if !filters.relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append("relationship LIKE ?")
            values.append(.text("%\(filters.relationship)%"))
        }
        if !filters.targetPerson.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append("target_person LIKE ?")
            values.append(.text("%\(filters.targetPerson)%"))
        }
        if let paymentMethod = filters.paymentMethod {
            clauses.append("payment_method = ?")
            values.append(.text(paymentMethod.rawValue))
        }
        if let status = filters.status {
            clauses.append("status = ?")
            values.append(.text(status.rawValue))
        }
        if !filters.minAmount.isEmpty {
            clauses.append("amount >= ?")
            values.append(.integer(parseAmount(filters.minAmount)))
        }
        if !filters.maxAmount.isEmpty {
            clauses.append("amount <= ?")
            values.append(.integer(parseAmount(filters.maxAmount)))
        }
        if let ticket = Int(filters.ticketCount), !filters.ticketCount.isEmpty {
            clauses.append("meal_ticket_count = ?")
            values.append(.integer(ticket))
        }
        if let childTicket = Int(filters.childTicketCount), !filters.childTicketCount.isEmpty {
            clauses.append("child_meal_ticket_count = ?")
            values.append(.integer(childTicket))
        }
        let whereClause = clauses.isEmpty ? "" : "WHERE \(clauses.joined(separator: " AND "))"
        return try db.query(
            """
            SELECT * FROM entries \(whereClause)
            ORDER BY mode DESC,
                CASE WHEN payment_method = 'transfer' THEN transfer_no ELSE envelope_no END ASC,
                created_at ASC
            """,
            values
        ).map(entryFromRow)
    }

    func lastEntries(mode: LedgerMode, limit: Int = 10) throws -> [LedgerEntry] {
        try db.query(
            "SELECT * FROM entries WHERE mode = ? ORDER BY created_at DESC, envelope_no DESC LIMIT ?",
            [.text(mode.rawValue), .integer(limit)]
        ).map(entryFromRow)
    }

    func summary(mode: LedgerMode? = nil) throws -> LedgerSummary {
        let mode = mode ?? self.mode()
        let rows = try findEntries(mode: mode)
        let active = rows.filter { $0.status == .active }
        let void = rows.filter { $0.status == .void }
        var paymentTotals: [PaymentMethod: Int] = [.cash: 0, .transfer: 0, .other: 0]
        for row in active {
            paymentTotals[row.paymentMethod, default: 0] += row.amount
        }
        let groupRows = try db.query(
            """
            SELECT group_name, COUNT(*) AS count, SUM(amount) AS total_amount, SUM(meal_ticket_count) AS total_tickets, SUM(child_meal_ticket_count) AS total_child_tickets
            FROM entries
            WHERE mode = ? AND status = ?
            GROUP BY group_name
            ORDER BY total_amount DESC, group_name ASC
            """,
            [.text(mode.rawValue), .text(EntryStatus.active.rawValue)]
        )
        let duplicateRows = try db.query(
            """
            SELECT name, COUNT(*) AS count
            FROM entries
            WHERE mode = ? AND status = ?
            GROUP BY name
            HAVING COUNT(*) > 1
            ORDER BY count DESC, name ASC
            """,
            [.text(mode.rawValue), .text(EntryStatus.active.rawValue)]
        )
        let envelopeNumbers = Set(rows.filter { $0.paymentMethod != .transfer && $0.envelopeNo > 0 }.map(\.envelopeNo))
        let gaps: [Int]
        if let minNo = envelopeNumbers.min(), let maxNo = envelopeNumbers.max() {
            gaps = (minNo...maxNo).filter { !envelopeNumbers.contains($0) }
        } else {
            gaps = []
        }
        return LedgerSummary(
            mode: mode,
            activeCount: active.count,
            voidCount: void.count,
            totalAmount: active.reduce(0) { $0 + $1.amount },
            totalTickets: active.reduce(0) { $0 + $1.mealTicketCount },
            totalChildTickets: active.reduce(0) { $0 + $1.childMealTicketCount },
            paymentTotals: paymentTotals,
            groupTotals: groupRows.map {
                GroupTotal(
                    groupName: $0["group_name"]?.string ?? defaultGroup,
                    count: $0["count"]?.int ?? 0,
                    totalAmount: $0["total_amount"]?.int ?? 0,
                    totalTickets: $0["total_tickets"]?.int ?? 0,
                    totalChildTickets: $0["total_child_tickets"]?.int ?? 0
                )
            },
            duplicateNames: duplicateRows.map { DuplicateName(name: $0["name"]?.string ?? "", count: $0["count"]?.int ?? 0) },
            envelopeGaps: gaps
        )
    }

    func recentGroups(limit: Int = 50) throws -> [String] {
        try lookupValues(kind: "group", limit: limit)
    }

    func recentRelationships(limit: Int = 50) throws -> [String] {
        try lookupValues(kind: "relationship", limit: limit)
    }

    func recentTargets(limit: Int = 50) throws -> [String] {
        try entryColumnValues(column: "target_person", limit: limit)
    }

    func voidEntry(id: String, reason: String) throws {
        guard let before = try getEntry(id: id) else { throw LedgerError.notFound }
        try db.execute("UPDATE entries SET status = ?, updated_at = ? WHERE id = ?", [.text(EntryStatus.void.rawValue), .text(nowString()), .text(id)])
        try insertAudit(entryID: id, action: "void", before: before, after: try getEntry(id: id), reason: reason)
    }

    func restoreEntry(id: String, reason: String) throws {
        guard let before = try getEntry(id: id) else { throw LedgerError.notFound }
        try db.execute("UPDATE entries SET status = ?, updated_at = ? WHERE id = ?", [.text(EntryStatus.active.rawValue), .text(nowString()), .text(id)])
        try insertAudit(entryID: id, action: "restore", before: before, after: try getEntry(id: id), reason: reason)
    }

    func deleteEntry(id: String, reason: String) throws {
        guard let before = try getEntry(id: id) else { throw LedgerError.notFound }
        try insertAudit(entryID: id, action: "delete", before: before, after: nil, reason: reason)
        try db.execute("UPDATE audit_logs SET entry_id = NULL WHERE entry_id = ?", [.text(id)])
        try db.execute("DELETE FROM entries WHERE id = ?", [.text(id)])
    }

    @discardableResult
    func createBackup(label: String = "auto") throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss_SSSSSS"
        let safeLabel = label.filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let target = backupDirectory.appendingPathComponent("wedding_ledger_\(safeLabel.isEmpty ? "auto" : safeLabel)_\(formatter.string(from: Date())).sqlite3")
        try db.execute("PRAGMA wal_checkpoint(FULL)")
        try FileManager.default.copyItem(at: dbURL, to: target)
        chmod(target.path, 0o600)
        return target
    }

    func auditRows() throws -> [[String: String]] {
        try db.query(
            """
            SELECT audit_logs.*, entries.envelope_no, entries.transfer_no, entries.name
            FROM audit_logs
            LEFT JOIN entries ON entries.id = audit_logs.entry_id
            ORDER BY audit_logs.created_at ASC
            """
        ).map { row in
            var output: [String: String] = [:]
            for (key, value) in row {
                output[key] = value.string
            }
            if output["envelope_no", default: ""].isEmpty {
                output["envelope_no"] = auditJSONValue(row, key: "envelope_no")
            }
            if output["transfer_no", default: ""].isEmpty {
                output["transfer_no"] = auditJSONValue(row, key: "transfer_no")
            }
            if output["name", default: ""].isEmpty {
                output["name"] = auditJSONValue(row, key: "name")
            }
            return output
        }
    }

    @discardableResult
    func exportXLSX(to url: URL, mode: LedgerMode? = nil) throws -> URL {
        let exportMode = mode ?? self.mode()
        let entries = try findEntries(mode: exportMode)
        let summary = try summary(mode: exportMode)
        let output = try exportXLSXFile(
            to: url,
            entries: entries,
            summary: summary,
            auditRows: auditRows(),
            mode: exportMode,
            settings: operationSettings()
        )
        chmod(output.path, 0o600)
        return output
    }

    @discardableResult
    func restoreFromBackup(_ backupURL: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: backupURL.path) else {
            throw LedgerError.invalid("백업 파일을 찾을 수 없습니다.")
        }
        let beforeRestore = try createBackup(label: "before_restore")
        let temporaryRestore = appDirectory.appendingPathComponent("wedding_ledger_restore_tmp.sqlite3")
        if FileManager.default.fileExists(atPath: temporaryRestore.path) {
            try FileManager.default.removeItem(at: temporaryRestore)
        }
        try FileManager.default.copyItem(at: backupURL, to: temporaryRestore)
        db.close()
        try removeWALFiles()
        if FileManager.default.fileExists(atPath: dbURL.path) {
            try FileManager.default.removeItem(at: dbURL)
        }
        try FileManager.default.moveItem(at: temporaryRestore, to: dbURL)
        db = try SQLiteDatabase(path: dbURL)
        try initialize()
        chmod(dbURL.path, 0o600)
        return beforeRestore
    }

    func clearTestData() throws -> Int {
        let ids = try db.query("SELECT id FROM entries WHERE mode = ?", [.text(LedgerMode.test.rawValue)]).compactMap { $0["id"]?.string }
        if !ids.isEmpty {
            let placeholders = Array(repeating: "?", count: ids.count).joined(separator: ",")
            try db.execute("DELETE FROM audit_logs WHERE entry_id IN (\(placeholders))", ids.map { .text($0) })
        }
        try db.execute("DELETE FROM entries WHERE mode = ?", [.text(LedgerMode.test.rawValue)])
        try db.execute("DELETE FROM lookup_items")
        try seedLookupItemsFromEntries()
        return ids.count
    }

    func clearRecordsAndLookups() throws {
        try db.execute("DELETE FROM audit_logs")
        try db.execute("DELETE FROM entries")
        try db.execute("DELETE FROM lookup_items")
        try seedLookupItemsFromEntries()
    }

    func resetAllData() throws {
        try db.execute("DELETE FROM audit_logs")
        try db.execute("DELETE FROM entries")
        try db.execute("DELETE FROM lookup_items")
        try db.execute("DELETE FROM settings")
        try initialize()
    }

    private func removeWALFiles() throws {
        for suffix in ["-wal", "-shm"] {
            let url = URL(fileURLWithPath: dbURL.path + suffix)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    private func validateDraft(_ draft: EntryDraft, mode: LedgerMode) throws -> EntryDraft {
        var clean = draft
        clean.name = clean.name.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.groupName = clean.groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.relationship = clean.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.targetPerson = clean.targetPerson.trimmingCharacters(in: .whitespacesAndNewlines)
        clean.memo = clean.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.paymentMethod == .transfer {
            if clean.transferNo <= 0 { clean.transferNo = try nextTransferNo(mode: mode) }
            clean.envelopeNo = 0
        } else {
            if clean.envelopeNo <= 0 { clean.envelopeNo = try nextEnvelopeNo(mode: mode) }
            clean.transferNo = 0
        }
        if clean.name.isEmpty { throw LedgerError.invalid("이름은 필수 입력입니다.") }
        if clean.amount < 0 { throw LedgerError.invalid("금액은 0원 이상이어야 합니다.") }
        if clean.mealTicketCount < 0 { throw LedgerError.invalid("식권 수는 0 이상이어야 합니다.") }
        if clean.childMealTicketCount < 0 { throw LedgerError.invalid("소인 식권 수는 0 이상이어야 합니다.") }
        if clean.groupName.isEmpty { clean.groupName = defaultGroup }
        return clean
    }

    private func createdAtString(for draft: EntryDraft) throws -> String {
        let cleanTimestamp = draft.createdAtText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard draft.paymentMethod == .transfer, !cleanTimestamp.isEmpty else {
            return nowString()
        }
        guard let normalized = normalizedLedgerTimestamp(cleanTimestamp) else {
            throw LedgerError.invalid("입금시간은 YYYY-MM-DD HH:mm:ss 또는 HH:mm:ss 형식으로 입력해 주세요.")
        }
        return normalized
    }

    private func getEntry(id: String) throws -> LedgerEntry? {
        try db.query("SELECT * FROM entries WHERE id = ?", [.text(id)]).first.map(entryFromRow)
    }

    private func entryFromRow(_ row: [String: SQLiteValue]) -> LedgerEntry {
        LedgerEntry(
            id: row["id"]?.string ?? "",
            mode: LedgerMode(rawValue: row["mode"]?.string ?? "") ?? .test,
            envelopeNo: row["envelope_no"]?.int ?? 0,
            name: row["name"]?.string ?? "",
            groupName: row["group_name"]?.string ?? defaultGroup,
            relationship: row["relationship"]?.string ?? "",
            targetPerson: row["target_person"]?.string ?? "",
            amount: row["amount"]?.int ?? 0,
            mealTicketCount: row["meal_ticket_count"]?.int ?? 0,
            childMealTicketCount: row["child_meal_ticket_count"]?.int ?? 0,
            transferNo: row["transfer_no"]?.int ?? 0,
            paymentMethod: PaymentMethod(rawValue: row["payment_method"]?.string ?? "") ?? .cash,
            memo: row["memo"]?.string ?? "",
            status: EntryStatus(rawValue: row["status"]?.string ?? "") ?? .active,
            createdAt: row["created_at"]?.string ?? "",
            updatedAt: row["updated_at"]?.string ?? ""
        )
    }

    private func seedLookupItemsFromEntries() throws {
        try addLookupValue(kind: "group", value: defaultGroup, increment: false)
        let rows = try db.query(
            """
            SELECT 'group' AS kind, group_name AS value FROM entries WHERE group_name != ''
            UNION
            SELECT 'relationship' AS kind, relationship AS value FROM entries WHERE relationship != ''
            """
        )
        for row in rows {
            try addLookupValue(kind: row["kind"]?.string ?? "", value: row["value"]?.string ?? "", increment: false)
        }
    }

    private func ensureEntryColumn(name: String, alterSQL: String) throws {
        let columns = try db.query("PRAGMA table_info(entries)")
        guard !columns.contains(where: { $0["name"]?.string == name }) else { return }
        try db.execute(alterSQL)
    }

    private func migrateEntryTableSchemaIfNeeded() throws {
        let sql = try db.query("SELECT sql FROM sqlite_master WHERE type = 'table' AND name = 'entries'")
            .first?["sql"]?.string ?? ""
        let needsRebuild = sql.contains("amount > 0") || sql.contains("UNIQUE(mode, envelope_no)")
        guard needsRebuild else { return }

        try db.execute("DROP INDEX IF EXISTS idx_entries_envelope_unique")
        try db.execute("DROP INDEX IF EXISTS idx_entries_transfer_unique")
        try db.execute("ALTER TABLE entries RENAME TO entries_legacy")
        try db.execute(
            """
            CREATE TABLE entries (
                id TEXT PRIMARY KEY,
                mode TEXT NOT NULL CHECK (mode IN ('test', 'live')),
                envelope_no INTEGER NOT NULL DEFAULT 0,
                transfer_no INTEGER NOT NULL DEFAULT 0,
                name TEXT NOT NULL,
                group_name TEXT NOT NULL DEFAULT '미분류',
                relationship TEXT DEFAULT '',
                target_person TEXT DEFAULT '',
                amount INTEGER NOT NULL CHECK (amount >= 0),
                meal_ticket_count INTEGER NOT NULL DEFAULT 0 CHECK (meal_ticket_count >= 0),
                child_meal_ticket_count INTEGER NOT NULL DEFAULT 0 CHECK (child_meal_ticket_count >= 0),
                payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'transfer', 'other')),
                memo TEXT DEFAULT '',
                status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'void')),
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            );
            """
        )
        try db.execute(
            """
            INSERT INTO entries (
                id, mode, envelope_no, transfer_no, name, group_name, relationship, target_person,
                amount, meal_ticket_count, child_meal_ticket_count, payment_method, memo, status,
                created_at, updated_at
            )
            SELECT
                id, mode,
                CASE WHEN payment_method = 'transfer' THEN 0 ELSE envelope_no END,
                CASE WHEN payment_method = 'transfer' THEN transfer_no ELSE 0 END,
                name, group_name, relationship, target_person, amount, meal_ticket_count,
                child_meal_ticket_count, payment_method, memo, status, created_at, updated_at
            FROM entries_legacy;
            """
        )
        try db.execute("DROP TABLE entries_legacy")
    }

    private func backfillTransferNumbers() throws {
        for mode in LedgerMode.allCases {
            let rows = try db.query(
                """
                SELECT id
                FROM entries
                WHERE mode = ? AND payment_method = ? AND transfer_no <= 0
                ORDER BY created_at ASC, envelope_no ASC
                """,
                [.text(mode.rawValue), .text(PaymentMethod.transfer.rawValue)]
            )
            var next = try nextTransferNo(mode: mode)
            for row in rows {
                guard let id = row["id"]?.string else { continue }
                try db.execute("UPDATE entries SET transfer_no = ? WHERE id = ?", [.integer(next), .text(id)])
                next += 1
            }
        }
    }

    private func addLookupValue(kind: String, value: String, increment: Bool = true) throws {
        guard ["group", "relationship"].contains(kind) else { return }
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        let usageIncrement = increment ? 1 : 0
        try db.execute(
            """
            INSERT INTO lookup_items(id, kind, value, usage_count, created_at, updated_at)
            VALUES(?, ?, ?, ?, ?, ?)
            ON CONFLICT(kind, value) DO UPDATE SET
                usage_count = lookup_items.usage_count + ?,
                updated_at = excluded.updated_at
            """,
            [.text(UUID().uuidString), .text(kind), .text(clean), .integer(usageIncrement), .text(nowString()), .text(nowString()), .integer(usageIncrement)]
        )
    }

    private func rememberLookupValues(groupName: String, relationship: String) throws {
        try addLookupValue(kind: "group", value: groupName)
        try addLookupValue(kind: "relationship", value: relationship)
    }

    private func lookupValues(kind: String, limit: Int) throws -> [String] {
        let column = kind == "group" ? "group_name" : "relationship"
        let rows = try db.query(
            """
            SELECT value FROM lookup_items
            WHERE kind = ?
            ORDER BY usage_count DESC, updated_at DESC, value ASC
            LIMIT ?
            """,
            [.text(kind), .integer(limit)]
        )
        let entryRows = try db.query(
            """
            SELECT \(column) AS value
            FROM entries
            WHERE TRIM(\(column)) != ''
            GROUP BY \(column)
            ORDER BY COUNT(*) DESC, MAX(updated_at) DESC, value ASC
            LIMIT ?
            """,
            [.integer(limit)]
        )
        var values: [String] = []
        for row in rows + entryRows {
            let value = row["value"]?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !value.isEmpty && !values.contains(value) {
                values.append(value)
            }
            if values.count >= limit { break }
        }
        if kind == "group" && !values.contains(defaultGroup) {
            values.insert(defaultGroup, at: 0)
        }
        return values
    }

    private func entryColumnValues(column: String, limit: Int) throws -> [String] {
        guard ["group_name", "relationship", "target_person"].contains(column) else { return [] }
        return try db.query(
            """
            SELECT \(column) AS value
            FROM entries
            WHERE TRIM(\(column)) != ''
            GROUP BY \(column)
            ORDER BY COUNT(*) DESC, MAX(updated_at) DESC, value ASC
            LIMIT ?
            """,
            [.integer(limit)]
        ).compactMap {
            let value = $0["value"]?.string.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        }
    }

    private func insertAudit(entryID: String?, action: String, before: LedgerEntry?, after: LedgerEntry?, reason: String) throws {
        let beforeJSON = try before.map(jsonForEntry)
        let afterJSON = try after.map(jsonForEntry)
        try db.execute(
            """
            INSERT INTO audit_logs(id, entry_id, action, before_json, after_json, reason, created_at)
            VALUES(?, ?, ?, ?, ?, ?, ?)
            """,
            [.text(UUID().uuidString), entryID.map(SQLiteValue.text) ?? .null, .text(action), beforeJSON.map(SQLiteValue.text) ?? .null, afterJSON.map(SQLiteValue.text) ?? .null, .text(reason), .text(nowString())]
        )
    }

    private func auditJSONValue(_ row: [String: SQLiteValue], key: String) -> String {
        for column in ["before_json", "after_json"] {
            let json = row[column]?.string ?? ""
            guard
                let data = json.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let value = object[key]
            else {
                continue
            }
            return String(describing: value)
        }
        return ""
    }

    private func jsonForEntry(_ entry: LedgerEntry) throws -> String {
        let payload: [String: Any] = [
            "id": entry.id,
            "mode": entry.mode.rawValue,
            "envelope_no": entry.envelopeNo,
            "name": entry.name,
            "group_name": entry.groupName,
            "relationship": entry.relationship,
            "target_person": entry.targetPerson,
            "amount": entry.amount,
            "meal_ticket_count": entry.mealTicketCount,
            "child_meal_ticket_count": entry.childMealTicketCount,
            "transfer_no": entry.transferNo,
            "payment_method": entry.paymentMethod.rawValue,
            "memo": entry.memo,
            "status": entry.status.rawValue,
            "created_at": entry.createdAt,
            "updated_at": entry.updatedAt
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
