import CSQLite
import Foundation

enum SQLiteError: Error, LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message), .prepareFailed(let message), .stepFailed(let message), .bindFailed(let message):
            message
        }
    }
}

final class SQLiteDatabase {
    private var db: OpaquePointer?

    init(path: URL) throws {
        if sqlite3_open(path.path, &db) != SQLITE_OK {
            throw SQLiteError.openFailed(lastError)
        }
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
    }

    deinit {
        close()
    }

    var lastError: String {
        if let db {
            String(cString: sqlite3_errmsg(db))
        } else {
            "SQLite 연결이 없습니다."
        }
    }

    func execute(_ sql: String, _ values: [SQLiteValue] = []) throws {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.stepFailed(lastError)
        }
    }

    func query(_ sql: String, _ values: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        let statement = try prepare(sql, values)
        defer { sqlite3_finalize(statement) }
        var rows: [[String: SQLiteValue]] = []
        while true {
            let result = sqlite3_step(statement)
            if result == SQLITE_DONE {
                break
            }
            guard result == SQLITE_ROW else {
                throw SQLiteError.stepFailed(lastError)
            }
            var row: [String: SQLiteValue] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, index))
                row[name] = SQLiteValue(statement: statement, index: index)
            }
            rows.append(row)
        }
        return rows
    }

    func scalar(_ sql: String, _ values: [SQLiteValue] = []) throws -> SQLiteValue? {
        try query(sql, values).first?.values.first
    }

    func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    private func prepare(_ sql: String, _ values: [SQLiteValue]) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteError.prepareFailed(lastError)
        }
        for (index, value) in values.enumerated() {
            try bind(value, to: statement, index: Int32(index + 1))
        }
        return statement
    }

    private func bind(_ value: SQLiteValue, to statement: OpaquePointer?, index: Int32) throws {
        let result: Int32
        switch value {
        case .integer(let integer):
            result = sqlite3_bind_int64(statement, index, sqlite3_int64(integer))
        case .text(let text):
            result = sqlite3_bind_text(statement, index, text, -1, SQLITE_TRANSIENT)
        case .null:
            result = sqlite3_bind_null(statement, index)
        }
        guard result == SQLITE_OK else {
            throw SQLiteError.bindFailed(lastError)
        }
    }
}

enum SQLiteValue: Equatable {
    case integer(Int)
    case text(String)
    case null

    init(statement: OpaquePointer?, index: Int32) {
        switch sqlite3_column_type(statement, index) {
        case SQLITE_INTEGER:
            self = .integer(Int(sqlite3_column_int64(statement, index)))
        case SQLITE_TEXT:
            self = .text(String(cString: sqlite3_column_text(statement, index)))
        default:
            self = .null
        }
    }

    var string: String {
        switch self {
        case .integer(let value): String(value)
        case .text(let value): value
        case .null: ""
        }
    }

    var int: Int {
        switch self {
        case .integer(let value): value
        case .text(let value): Int(value) ?? 0
        case .null: 0
        }
    }
}

let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
