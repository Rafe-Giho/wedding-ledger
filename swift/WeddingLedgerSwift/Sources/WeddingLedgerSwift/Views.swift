import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum SectionKey: String, CaseIterable, Identifiable {
    case entry
    case search
    case summary
    case settings

    var id: String { rawValue }

    var label: String {
        switch self {
        case .entry: "입력"
        case .search: "검색"
        case .summary: "정산"
        case .settings: "설정"
        }
    }

    var symbol: String {
        switch self {
        case .entry: "pencil"
        case .search: "magnifyingglass"
        case .summary: "list.bullet.rectangle"
        case .settings: "gearshape"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @State private var section: SectionKey = .entry

    var body: some View {
        ZStack {
            ShellView(section: $section)
                .disabled(!state.isUnlocked)
                .blur(radius: state.isUnlocked ? 0 : 10)
            if !state.isUnlocked {
                AuthView()
            }
        }
        .alert("알림", isPresented: Binding(get: { !state.message.isEmpty }, set: { if !$0 { state.message = "" } })) {
            Button("확인") { state.message = "" }
        } message: {
            Text(state.message)
        }
        .sheet(item: Binding(
            get: { state.recoveryKeyToShow.map(RecoveryKeySheet.init(key:)) },
            set: { if $0 == nil { state.recoveryKeyToShow = nil } }
        )) { sheet in
            RecoveryKeyView(recoveryKey: sheet.key)
        }
    }
}

struct RecoveryKeySheet: Identifiable {
    let id = UUID()
    let key: String
}

struct ShellView: View {
    @EnvironmentObject private var state: AppState
    @Binding var section: SectionKey

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(section: $section)
            VStack(spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.label)
                            .font(.system(size: 30, weight: .bold))
                        Text("빠르게 입력하고 바로 확인할 수 있게 정리했습니다.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(state.mode.label) 모드")
                        .font(.headline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                }
                content
            }
            .padding(30)
            .background(AppColors.background)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .entry:
            EntryDashboardView()
        case .search:
            SearchView()
        case .summary:
            SummaryView()
        case .settings:
            SettingsView()
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @Binding var section: SectionKey

    var body: some View {
        VStack(spacing: 0) {
            Text("⌘")
                .font(.system(size: 32))
                .foregroundStyle(AppColors.gold)
                .padding(.top, 52)
            Text(appTitle)
                .font(.custom("AppleMyungjo", size: 31))
                .padding(.top, 10)
                .padding(.bottom, 54)
            VStack(spacing: 18) {
                ForEach(SectionKey.allCases) { item in
                    Button {
                        section = item
                    } label: {
                        HStack(spacing: 18) {
                            Image(systemName: item.symbol)
                                .frame(width: 42, height: 42)
                                .background(section == item ? AppColors.gold : .clear, in: Circle())
                                .foregroundStyle(section == item ? .white : .secondary)
                            Text(item.label)
                                .font(.system(size: 21, weight: .medium))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .frame(height: 68)
                        .background(section == item ? AppColors.sidebarActive : .clear, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            FloralLineArt()
                .stroke(AppColors.gold.opacity(0.34), lineWidth: 1.2)
                .frame(width: 190, height: 260)
            Button("잠금") {
                state.isUnlocked = false
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 24)
        }
        .frame(width: 266)
        .background(AppColors.sidebar)
    }
}

struct EntryDashboardView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            EntryFormView()
                .frame(width: 496)
            VStack(spacing: 18) {
                RecentEntriesCard()
                SummaryCardsRow()
                ThanksCard()
            }
        }
    }
}

struct EntryFormView: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var nameFocused: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 24) {
                Text("새로운 축의 입력")
                    .font(.system(size: 24, weight: .bold))
                HStack(spacing: 18) {
                    FieldLabel("봉투번호") {
                        TextField("봉투번호", value: $state.draft.envelopeNo, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold))
                    }
                    FieldLabel("입금방식") {
                        Picker("", selection: $state.draft.paymentMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.label).tag(method)
                            }
                        }
                        .labelsHidden()
                    }
                }
                HStack(spacing: 18) {
                    FieldLabel("모임") {
                        SuggestionTextField(text: $state.draft.groupName, suggestions: state.groups)
                    }
                    FieldLabel("관계") {
                        SuggestionTextField(text: $state.draft.relationship, suggestions: state.relationships)
                    }
                }
                FieldLabel("이름") {
                    TextField("이름을 입력하세요", text: $state.draft.name)
                        .textFieldStyle(.plain)
                        .focused($nameFocused)
                }
                HStack(spacing: 18) {
                    FieldLabel("금액") {
                        HStack {
                            Text("₩").foregroundStyle(.secondary)
                            TextField("금액을 입력하세요", text: $state.draft.amountText)
                                .textFieldStyle(.plain)
                                .onChange(of: state.draft.amountText) { _, value in
                                    let amount = parseAmount(value)
                                    state.draft.amountText = amount > 0 ? formatNumber(amount) : ""
                                }
                        }
                    }
                    FieldLabel("식권") {
                        HStack {
                            Image(systemName: "fork.knife").foregroundStyle(.secondary)
                            Button("-") { state.draft.mealTicketCount = max(0, state.draft.mealTicketCount - 1) }
                            Text("\(state.draft.mealTicketCount)")
                                .frame(width: 26)
                            Button("+") { state.draft.mealTicketCount += 1 }
                            Text("매")
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("금액 빠른 선택")
                        .font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(defaultQuickAmounts, id: \.self) { amount in
                            PillButton(formatNumber(amount)) {
                                state.draft.amountText = formatNumber(amount)
                            }
                        }
                        PillButton("+1만원", outlined: true) {
                            state.draft.amountText = formatNumber(state.draft.amount + 10_000)
                        }
                    }
                }
                FieldLabel("메모 (선택)") {
                    TextEditor(text: $state.draft.memo)
                        .frame(height: 96)
                        .scrollContentBackground(.hidden)
                }
                Button {
                    state.saveEntry()
                    nameFocused = true
                } label: {
                    Text("저장")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(AppColors.ink, in: RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RecentEntriesCard: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("최근 입력 내역")
                        .font(.system(size: 24, weight: .bold))
                    Spacer()
                    Text("전체 보기 ›")
                        .foregroundStyle(.secondary)
                }
                EntryTable(entries: state.recentEntries, compact: true)
            }
        }
    }
}

struct SummaryCardsRow: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 18) {
            StatCard(title: "총 축의금", value: formatWon(state.summary.totalAmount), footnote: "건수 \(state.summary.activeCount)건", symbol: "wonsign")
            StatCard(title: "총 식권", value: "\(state.summary.totalTickets)매", footnote: "사용 \(state.summary.totalTickets)매 ㅣ 남은 0매", symbol: "fork.knife")
            StatCard(
                title: "평균 축의금",
                value: formatWon(state.summary.activeCount == 0 ? 0 : state.summary.totalAmount / state.summary.activeCount),
                footnote: "(축의금 기준)",
                symbol: "creditcard"
            )
        }
    }
}

struct ThanksCard: View {
    var body: some View {
        Card {
            HStack {
                Text("따뜻한 마음에 감사드립니다.")
                    .font(.custom("AppleMyungjo", size: 22))
                    .foregroundStyle(AppColors.gold)
                Spacer()
                Text("⌘").font(.title).foregroundStyle(AppColors.gold)
            }
        }
    }
}

struct SearchView: View {
    @EnvironmentObject private var state: AppState
    @State private var filters = EntryFilters()

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 18) {
                Text("검색")
                    .font(.system(size: 24, weight: .bold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                    TextField("이름", text: $filters.name)
                    TextField("모임", text: $filters.groupName)
                    TextField("최소 금액", text: $filters.minAmount)
                        .onChange(of: filters.minAmount) { _, value in filters.minAmount = formatFilterAmount(value) }
                    TextField("최대 금액", text: $filters.maxAmount)
                        .onChange(of: filters.maxAmount) { _, value in filters.maxAmount = formatFilterAmount(value) }
                    TextField("식권수", text: $filters.ticketCount)
                        .onChange(of: filters.ticketCount) { _, value in filters.ticketCount = value.filter(\.isNumber) }
                    Picker("입금방식", selection: Binding(get: { filters.paymentMethod }, set: { filters.paymentMethod = $0 })) {
                        Text("전체").tag(PaymentMethod?.none)
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.label).tag(Optional(method))
                        }
                    }
                    Picker("상태", selection: Binding(get: { filters.status }, set: { filters.status = $0 })) {
                        Text("전체").tag(EntryStatus?.none)
                        ForEach(EntryStatus.allCases) { status in
                            Text(status.label).tag(Optional(status))
                        }
                    }
                    Button("검색") { state.search(filters: filters) }
                }
                EntryTable(entries: state.searchResults, compact: false)
            }
        }
    }

    private func formatFilterAmount(_ value: String) -> String {
        let amount = parseAmount(value)
        return amount > 0 ? formatNumber(amount) : ""
    }
}

struct SummaryView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 22) {
                Text("정산")
                    .font(.system(size: 24, weight: .bold))
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    SummaryTile("정상 기록", "\(state.summary.activeCount)건")
                    SummaryTile("취소 기록", "\(state.summary.voidCount)건")
                    SummaryTile("총 축의금", formatWon(state.summary.totalAmount))
                    SummaryTile("총 식권", "\(state.summary.totalTickets)매")
                    SummaryTile("현금 합계", formatWon(state.summary.paymentTotals[.cash] ?? 0))
                    SummaryTile("계좌 합계", formatWon(state.summary.paymentTotals[.transfer] ?? 0))
                    SummaryTile("누락 봉투", state.summary.envelopeGaps.isEmpty ? "없음" : state.summary.envelopeGaps.map(String.init).joined(separator: ", "))
                    SummaryTile("동명이인", state.summary.duplicateNames.isEmpty ? "없음" : state.summary.duplicateNames.map(\.name).joined(separator: ", "))
                }
                Text("모임별 합계")
                    .font(.headline)
                Table(state.summary.groupTotals) {
                    TableColumn("모임", value: \.groupName)
                    TableColumn("건수") { Text("\($0.count)") }
                    TableColumn("총액") { Text(formatWon($0.totalAmount)).foregroundStyle(AppColors.gold) }
                    TableColumn("식권") { Text("\($0.totalTickets)") }
                }
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmAll = false
    @State private var confirmRecords = false
    @State private var confirmTest = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 20) {
                Text("설정")
                    .font(.system(size: 24, weight: .bold))
                Form {
                    Picker("화면 테마", selection: Binding(get: { state.themePreference }, set: { state.setTheme($0) })) {
                        ForEach(ThemePreference.allCases) { preference in
                            Text(preference.label).tag(preference)
                        }
                    }
                    Picker("현재 모드", selection: Binding(get: { state.mode }, set: { state.switchMode($0) })) {
                        ForEach(LedgerMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    Text("데이터 위치: \(state.store.appDirectory.path)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("엑셀 추출") { exportExcel() }
                    Button("수동 백업 생성") { state.createBackup() }
                    Button("백업 복원") { restoreBackup() }
                    Button("테스트 데이터 초기화", role: .destructive) { confirmTest = true }
                    Button("기록/목록 초기화", role: .destructive) { confirmRecords = true }
                    Button("전체 초기화", role: .destructive) { confirmAll = true }
                }
            }
        }
        .confirmationDialog("테스트 모드 기록만 삭제합니다. 백업은 생성하지 않습니다.", isPresented: $confirmTest) {
            Button("삭제", role: .destructive) { state.clearTestData() }
        }
        .confirmationDialog("모든 기록과 모임/관계 목록을 삭제합니다. 비밀번호와 설정은 유지됩니다.", isPresented: $confirmRecords) {
            Button("삭제", role: .destructive) { state.clearRecordsAndLookups() }
        }
        .confirmationDialog("기록, 비밀번호, 복구키, 설정을 모두 삭제합니다.", isPresented: $confirmAll) {
            Button("전체 초기화", role: .destructive) { state.resetAllData() }
        }
    }

    private func exportExcel() {
        let panel = NSSavePanel()
        panel.title = "엑셀 파일 저장"
        panel.nameFieldStringValue = "wedding_ledger_export.xls"
        panel.allowedContentTypes = [UTType(filenameExtension: "xls") ?? .data]
        if panel.runModal() == .OK, let url = panel.url {
            state.exportExcel(to: url)
        }
    }

    private func restoreBackup() {
        let panel = NSOpenPanel()
        panel.title = "복원할 백업 선택"
        panel.directoryURL = state.store.backupDirectory
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite3") ?? .data]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            state.restoreBackup(from: url)
        }
    }
}

struct AuthView: View {
    @EnvironmentObject private var state: AppState
    @State private var password = ""
    @State private var confirmation = ""
    @State private var showRecovery = false

    var body: some View {
        VStack(spacing: 18) {
            Text(state.isConfigured ? "잠금 해제" : "축의대 장부 시작하기")
                .font(.system(size: 26, weight: .bold))
            Text(state.isConfigured ? "비밀번호를 입력해 앱을 엽니다." : "처음 사용할 비밀번호를 설정하세요.")
                .foregroundStyle(.secondary)
            SecureField("비밀번호", text: $password)
                .textFieldStyle(.roundedBorder)
            if !state.isConfigured {
                SecureField("비밀번호 확인", text: $confirmation)
                    .textFieldStyle(.roundedBorder)
            }
            Button(state.isConfigured ? "로그인" : "비밀번호 설정") {
                if state.isConfigured {
                    state.login(password: password)
                } else {
                    state.setup(password: password, confirmation: confirmation)
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return)
            if state.isConfigured {
                Button("비밀번호를 잊으셨나요?") { showRecovery = true }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(34)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(radius: 24)
        .sheet(isPresented: $showRecovery) {
            PasswordResetView()
        }
    }
}

struct PasswordResetView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var recoveryKey = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("비밀번호 복구")
                .font(.title2.bold())
            Text("처음 설정할 때 받은 복구키로 새 비밀번호를 설정합니다.")
                .foregroundStyle(.secondary)
            TextField("복구키", text: $recoveryKey)
                .textFieldStyle(.roundedBorder)
            SecureField("새 비밀번호", text: $newPassword)
                .textFieldStyle(.roundedBorder)
            SecureField("새 비밀번호 확인", text: $confirmation)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("취소") { dismiss() }
                Button("재설정") {
                    state.resetPassword(recoveryKey: recoveryKey, newPassword: newPassword, confirmation: confirmation)
                    if state.isUnlocked { dismiss() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 480)
    }
}

struct RecoveryKeyView: View {
    let recoveryKey: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("복구키 보관")
                .font(.title2.bold())
            Text("비밀번호를 잊었을 때 필요합니다. 안전한 곳에 따로 보관하세요.")
                .foregroundStyle(.secondary)
            Text(recoveryKey)
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .padding()
                .frame(maxWidth: .infinity)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            Text("이 창을 닫아도 앱은 계속 사용할 수 있습니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .frame(width: 520)
    }
}

struct EntryTable: View {
    let entries: [LedgerEntry]
    let compact: Bool

    var body: some View {
        if entries.isEmpty {
            Text("아직 입력된 기록이 없습니다.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 140)
        } else {
            if compact {
                Table(entries) {
                    TableColumn("봉투") { Text("\($0.envelopeNo)") }
                    TableColumn("이름", value: \.name)
                    TableColumn("모임", value: \.groupName)
                    TableColumn("금액") { Text(formatWon($0.amount)).foregroundStyle(AppColors.gold) }
                    TableColumn("식권") { Text("\($0.mealTicketCount)") }
                }
                .frame(minHeight: 300)
            } else {
                Table(entries) {
                    TableColumn("봉투") { Text("\($0.envelopeNo)") }
                    TableColumn("이름", value: \.name)
                    TableColumn("모임", value: \.groupName)
                    TableColumn("관계", value: \.relationship)
                    TableColumn("금액") { Text(formatWon($0.amount)).foregroundStyle(AppColors.gold) }
                    TableColumn("식권") { Text("\($0.mealTicketCount)") }
                    TableColumn("방식") { Text($0.paymentMethod.label) }
                    TableColumn("상태") { Text($0.status.label) }
                    TableColumn("관리") { entry in
                        EntryStatusButton(entry: entry)
                    }
                }
                .frame(minHeight: 520)
            }
        }
    }
}

struct EntryStatusButton: View {
    @EnvironmentObject private var state: AppState
    let entry: LedgerEntry

    var body: some View {
        Button(entry.status == .active ? "취소" : "복구") {
            if entry.status == .active {
                state.voidEntry(entry)
            } else {
                state.restoreEntry(entry)
            }
        }
        .buttonStyle(.borderless)
    }
}
