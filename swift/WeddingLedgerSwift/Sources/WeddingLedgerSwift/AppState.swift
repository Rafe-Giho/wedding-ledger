import Foundation
import AppKit
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var isConfigured = false
    @Published var isUnlocked = false
    @Published var mode: LedgerMode = .test
    @Published var themePreference: ThemePreference = .dark
    @Published var appearanceRevision = 0
    @Published var draft = EntryDraft(envelopeNo: 1)
    @Published var recentEntries: [LedgerEntry] = []
    @Published var searchResults: [LedgerEntry] = []
    @Published var searchFilters = EntryFilters()
    @Published var summary: LedgerSummary = .empty
    @Published var closingChecks: Set<ClosingCheckKey> = []
    @Published var operationSettings: OperationSettings = .empty
    @Published var duplicateMatches: [LedgerEntry] = []
    @Published var groups: [String] = [defaultGroup]
    @Published var relationships: [String] = []
    @Published var targets: [String] = []
    @Published var message = ""
    @Published var lastExportURL: URL?
    @Published var recoveryKeyToShow: String?

    let store: LedgerStore

    init(store: LedgerStore) {
        self.store = store
        refresh()
    }

    func refresh() {
        do {
            isConfigured = store.isConfigured()
            mode = store.mode()
            themePreference = store.themePreference()
            applyAppearance(themePreference)
            operationSettings = store.operationSettings()
            draft.envelopeNo = try store.nextEnvelopeNo(mode: mode)
            draft.transferNo = try store.nextTransferNo(mode: mode)
            groups = try store.recentGroups()
            relationships = try store.recentRelationships()
            targets = try store.recentTargets()
            recentEntries = try store.lastEntries(mode: mode, limit: 8)
            summary = try store.summary(mode: mode)
            searchResults = try store.findEntries(filters: searchFilters, mode: mode)
            duplicateMatches = try store.activeEntriesNamed(mode: mode, name: draft.name)
        } catch {
            message = error.localizedDescription
        }
    }

    func setup(password: String, confirmation: String) {
        guard password == confirmation else {
            message = "비밀번호 확인이 일치하지 않습니다."
            return
        }
        do {
            recoveryKeyToShow = try store.setupAuth(password: password)
            isConfigured = true
            isUnlocked = true
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func login(password: String) {
        if store.verifyPassword(password) {
            isUnlocked = true
            refresh()
        } else {
            message = "비밀번호가 일치하지 않습니다."
        }
    }

    func saveEntry(forceDuplicate: Bool = false) {
        do {
            let matches = try store.activeEntriesNamed(mode: mode, name: draft.name)
            if !matches.isEmpty, !forceDuplicate {
                duplicateMatches = matches
                message = "같은 이름의 정상 기록이 있습니다. 저장 방식을 선택해 주세요."
                return
            }
            _ = try store.createEntry(draft, mode: mode)
            draft = EntryDraft(envelopeNo: try store.nextEnvelopeNo(mode: mode), transferNo: try store.nextTransferNo(mode: mode))
            duplicateMatches = []
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func search(filters: EntryFilters) {
        do {
            searchFilters = filters
            searchResults = try store.findEntries(filters: filters, mode: mode)
        } catch {
            message = error.localizedDescription
        }
    }

    func resetSearch() {
        search(filters: EntryFilters())
    }

    func filterDuplicateName(_ name: String) {
        var filters = EntryFilters()
        filters.name = name
        filters.exactName = true
        filters.status = .active
        search(filters: filters)
    }

    func updateDuplicateMatches() {
        do {
            duplicateMatches = try store.activeEntriesNamed(mode: mode, name: draft.name)
        } catch {
            message = error.localizedDescription
        }
    }

    func cancelDuplicateReview() {
        draft.name = ""
        duplicateMatches = []
    }

    func setDraftPaymentMethod(_ method: PaymentMethod) {
        draft.paymentMethod = method
        do {
            if method == .transfer {
                if draft.transferNo <= 0 {
                    draft.transferNo = try store.nextTransferNo(mode: mode)
                }
                if draft.createdAtText.isEmpty {
                    draft.createdAtText = nowString()
                }
            } else {
                if draft.envelopeNo <= 0 {
                    draft.envelopeNo = try store.nextEnvelopeNo(mode: mode)
                }
                draft.transferNo = 0
                draft.createdAtText = ""
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func switchMode(_ newMode: LedgerMode) {
        do {
            try store.setMode(newMode)
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func setTheme(_ preference: ThemePreference) {
        let previous = themePreference
        themePreference = preference
        applyAppearance(preference)
        appearanceRevision += 1
        do {
            try store.setThemePreference(preference)
        } catch {
            themePreference = previous
            applyAppearance(previous)
            appearanceRevision += 1
            message = error.localizedDescription
        }
    }

    private func applyAppearance(_ preference: ThemePreference) {
        switch preference {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func toggleClosingCheck(_ key: ClosingCheckKey) {
        if closingChecks.contains(key) {
            closingChecks.remove(key)
        } else {
            closingChecks.insert(key)
        }
    }

    func saveOperationSettings(_ settings: OperationSettings) {
        do {
            try store.setOperationSettings(settings)
            operationSettings = store.operationSettings()
            message = "운영 설정을 저장했습니다."
        } catch {
            message = error.localizedDescription
        }
    }

    func clearTestData() {
        do {
            let count = try store.clearTestData()
            message = "테스트 기록 \(count)건을 삭제했습니다."
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func clearRecordsAndLookups() {
        do {
            try store.clearRecordsAndLookups()
            message = "기록과 모임/관계 목록을 삭제했습니다."
            searchResults = []
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func resetAllData() {
        do {
            try store.resetAllData()
            isUnlocked = false
            recoveryKeyToShow = nil
            searchResults = []
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func createBackup() {
        do {
            let backup = try store.createBackup(label: "manual")
            message = "백업 완료: \(backup.path)"
        } catch {
            message = error.localizedDescription
        }
    }

    func exportExcel(to url: URL) {
        do {
            let backup = try store.createBackup(label: "before_export")
            let output = try store.exportXLSX(to: url, mode: mode)
            lastExportURL = output
            message = "엑셀 추출 완료: \(output.path)\n백업: \(backup.path)"
        } catch {
            lastExportURL = nil
            message = error.localizedDescription
        }
    }

    func openLastExportLocation() {
        guard let lastExportURL else {
            message = "먼저 엑셀 추출을 완료해 주세요."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([lastExportURL])
    }

    func restoreBackup(from url: URL) {
        do {
            let before = try store.restoreFromBackup(url)
            message = "복원 완료. 복원 전 백업: \(before.path)"
            searchResults = []
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func resetPassword(recoveryKey: String, newPassword: String, confirmation: String) {
        guard newPassword == confirmation else {
            message = "새 비밀번호 확인이 일치하지 않습니다."
            return
        }
        do {
            if try store.resetPassword(recoveryKey: recoveryKey, newPassword: newPassword) {
                isUnlocked = true
                refresh()
                message = "비밀번호를 재설정했습니다."
            } else {
                message = "복구키가 올바르지 않습니다."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func voidEntry(_ entry: LedgerEntry) {
        do {
            try store.voidEntry(id: entry.id, reason: "Swift 앱에서 취소")
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func restoreEntry(_ entry: LedgerEntry) {
        do {
            try store.restoreEntry(id: entry.id, reason: "Swift 앱에서 복구")
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: LedgerEntry) {
        do {
            try store.deleteEntry(id: entry.id, reason: "Swift 앱에서 삭제")
            message = "\(entry.sequenceLabel) \(entry.name) 기록을 삭제했습니다."
            refresh()
        } catch {
            message = error.localizedDescription
        }
    }
}

extension ThemePreference {
    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }
}
