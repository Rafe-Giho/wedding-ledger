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
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "시스템 설정"
        case .light: "라이트"
        case .dark: "다크"
        }
    }
}

let appName = "WeddingLedger"
let appTitle = "축의대 장부"
let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
let defaultGroup = "미분류"
let defaultQuickAmounts = [30_000, 50_000, 100_000, 150_000, 200_000, 300_000, 500_000, 1_000_000]
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
