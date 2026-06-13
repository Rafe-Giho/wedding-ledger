import Foundation

enum LedgerMode: String, CaseIterable, Identifiable {
    case test
    case live

    var id: String { rawValue }

    var label: String {
        switch self {
        case .test: "테스트"
        case .live: "운영"
        }
    }
}

enum EntryStatus: String, CaseIterable, Identifiable {
    case active
    case void

    var id: String { rawValue }

    var label: String {
        switch self {
        case .active: "정상"
        case .void: "취소"
        }
    }
}

enum PaymentMethod: String, CaseIterable, Identifiable {
    case cash
    case transfer
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .cash: "현금"
        case .transfer: "계좌"
        case .other: "기타"
        }
    }
}

enum ThemePreference: String, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .light: "라이트"
        case .dark: "다크"
        }
    }
}

let appName = "WeddingLedger"
let appTitle = "축의대 장부"
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
let defaultGroup = "미분류"
let defaultQuickAmounts = [0, 30_000, 50_000, 100_000, 150_000, 200_000, 300_000, 500_000, 1_000_000]
let pbkdf2Iterations = 310_000

func formatWon(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "ko_KR")
    return "\(formatter.string(from: NSNumber(value: value)) ?? "0")원"
}

func formatNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.locale = Locale(identifier: "ko_KR")
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}

func parseAmount(_ value: String) -> Int {
    Int(value.filter(\.isNumber)) ?? 0
}

func nowString() -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: Date())
}

func normalizedLedgerTimestamp(_ value: String) -> String? {
    guard let date = parseLedgerTimestamp(value) else { return nil }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter.string(from: date)
}

func ledgerClockText(_ value: String) -> String {
    guard let date = parseLedgerTimestamp(value) else { return value }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

func ledgerDateText(_ value: String) -> String {
    guard let date = parseLedgerTimestamp(value) else { return "" }
    if Calendar.current.isDateInToday(date) { return "오늘" }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "MM-dd"
    return formatter.string(from: date)
}

private func parseLedgerTimestamp(_ value: String) -> Date? {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.timeZone = .current

    for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
        formatter.dateFormat = format
        if let date = formatter.date(from: trimmed) { return date }
    }

    for format in ["HH:mm:ss", "HH:mm"] {
        formatter.dateFormat = format
        if let time = formatter.date(from: trimmed) {
            let timeParts = Calendar.current.dateComponents([.hour, .minute, .second], from: time)
            let today = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            return Calendar.current.date(from: DateComponents(
                year: today.year,
                month: today.month,
                day: today.day,
                hour: timeParts.hour,
                minute: timeParts.minute,
                second: timeParts.second ?? 0
            ))
        }
    }

    return nil
}
