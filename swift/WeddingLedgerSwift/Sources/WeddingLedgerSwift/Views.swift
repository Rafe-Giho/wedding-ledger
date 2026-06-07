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

enum ResponsiveLayout {
    case expanded
    case medium
    case compact

    init(width: CGFloat) {
        if width < 920 {
            self = .compact
        } else if width < 1240 {
            self = .medium
        } else {
            self = .expanded
        }
    }

    var showsSidebar: Bool { self != .compact }
    var stacksEntry: Bool { self != .expanded }
    var stacksPairs: Bool { self == .compact }
    var sidebarWidth: CGFloat { self == .medium ? 220 : 266 }
    var contentPadding: CGFloat { self == .compact ? 18 : 30 }
    var entryFormWidth: CGFloat { self == .medium ? 460 : 496 }
    var cardPadding: CGFloat { self == .compact ? 22 : 30 }
    var recentEntriesHeight: CGFloat { self == .compact ? 220 : 260 }
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
    @Binding var section: SectionKey

    var body: some View {
        GeometryReader { proxy in
            let layout = ResponsiveLayout(width: proxy.size.width)
            ZStack(alignment: .topLeading) {
                WindowBackground()
                if layout.showsSidebar {
                    HStack(spacing: 0) {
                        SidebarView(section: $section, width: layout.sidebarWidth)
                        WorkspaceView(section: $section, layout: layout)
                    }
                } else {
                    VStack(spacing: 0) {
                        CompactHeaderView(section: $section)
                        WorkspaceContent(section: $section, layout: layout)
                    }
                }
            }
        }
        .background(AppColors.background)
    }
}

struct WindowBackground: View {
    var body: some View {
        ZStack {
            AppColors.window
            RadialGradient(
                colors: [Color.white.opacity(0.22), .clear],
                center: .init(x: 0.30, y: 0.18),
                startRadius: 0,
                endRadius: 430
            )
        }
        .ignoresSafeArea()
    }
}

struct WorkspaceView: View {
    @Binding var section: SectionKey
    let layout: ResponsiveLayout

    var body: some View {
        VStack(spacing: 20) {
            TopBarView(compact: false)
            WorkspaceContent(section: $section, layout: layout)
        }
        .padding(.top, 26)
        .padding(.horizontal, layout.contentPadding)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct WorkspaceContent: View {
    @Binding var section: SectionKey
    let layout: ResponsiveLayout

    var body: some View {
        ScrollView {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(.bottom, layout.contentPadding)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .entry:
            EntryDashboardView(section: $section, layout: layout)
        case .search:
            SearchView(layout: layout)
        case .summary:
            SummaryView(layout: layout)
        case .settings:
            SettingsView(layout: layout)
        }
    }
}

struct TopBarView: View {
    @EnvironmentObject private var state: AppState
    let compact: Bool

    var body: some View {
        HStack(spacing: 18) {
            Spacer()
            ModePill(title: "\(state.mode.label) 모드")
            ThemePreferenceControl(compact: compact)
        }
        .frame(minHeight: 36)
    }
}

struct CompactHeaderView: View {
    @Binding var section: SectionKey

    var body: some View {
        VStack(spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                BrandLockup(horizontal: true)
                Spacer()
            }
            TopBarView(compact: true)
            TopNavigationView(section: $section)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 16)
        .background(AppColors.sidebar)
        .overlay(Rectangle().fill(AppColors.lineSoft).frame(height: 1), alignment: .bottom)
    }
}

struct BrandLockup: View {
    let horizontal: Bool

    var body: some View {
        if horizontal {
            HStack(spacing: 12) {
                Text("⌘")
                    .font(.system(size: 28))
                    .foregroundStyle(AppColors.gold)
                Text(appTitle)
                    .font(.custom("AppleMyungjo", size: 27))
                    .foregroundStyle(AppColors.text)
            }
        } else {
            VStack(spacing: 8) {
                Text("⌘")
                    .font(.system(size: 32))
                    .foregroundStyle(AppColors.gold)
                Text(appTitle)
                    .font(.custom("AppleMyungjo", size: 31))
                    .foregroundStyle(AppColors.text)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

struct SidebarView: View {
    @EnvironmentObject private var state: AppState
    @Binding var section: SectionKey
    let width: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            BrandLockup(horizontal: false)
                .padding(.top, 58)
                .padding(.bottom, 42)
            VStack(spacing: 14) {
                ForEach(SectionKey.allCases) { item in
                    NavigationButton(item: item, isActive: section == item) {
                        section = item
                    }
                }
            }
            .padding(.horizontal, width == 220 ? 18 : 28)
            Spacer()
            FloralLineArt()
                .stroke(AppColors.gold.opacity(0.34), lineWidth: 1.2)
                .frame(width: width == 220 ? 170 : 220, height: 300)
                .padding(.bottom, 18)
            Button("잠금") {
                state.isUnlocked = false
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.text)
            .padding(.horizontal, 20)
            .frame(width: 148, height: 44)
            .background(AppColors.field, in: Capsule())
            .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
            .padding(.bottom, 24)
        }
        .frame(width: width)
        .background(AppColors.sidebar)
        .overlay(Rectangle().fill(AppColors.lineSoft).frame(width: 1), alignment: .trailing)
    }
}

struct TopNavigationView: View {
    @Binding var section: SectionKey

    var body: some View {
        HStack(spacing: 10) {
            ForEach(SectionKey.allCases) { item in
                Button {
                    section = item
                } label: {
                    Label(item.label, systemImage: item.symbol)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(section == item ? AppColors.sidebarActive : Color.clear, in: Capsule())
                        .foregroundStyle(section == item ? AppColors.text : AppColors.muted)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct NavigationButton: View {
    let item: SectionKey
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: item.symbol)
                    .frame(width: 42, height: 42)
                    .background(isActive ? AppColors.gold : Color.clear, in: Circle())
                    .overlay(Circle().stroke(isActive ? AppColors.gold : AppColors.muted.opacity(0.65), lineWidth: 1))
                    .foregroundStyle(isActive ? .white : AppColors.muted)
                Text(item.label)
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(AppColors.text)
                Spacer()
            }
            .padding(.horizontal, 20)
            .frame(height: 68)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isActive ? AppColors.sidebarActive : Color.clear, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ThemePreferenceControl: View {
    @EnvironmentObject private var state: AppState
    let compact: Bool

    var body: some View {
        Picker("화면 테마", selection: Binding(get: { state.themePreference }, set: { state.setTheme($0) })) {
            ForEach(ThemePreference.allCases) { preference in
                Text(compact ? preference.shortLabel : preference.label).tag(preference)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: compact ? 228 : 304)
    }
}

struct EntryDashboardView: View {
    @Binding var section: SectionKey
    let layout: ResponsiveLayout

    var body: some View {
        if layout.stacksEntry {
            VStack(spacing: 18) {
                EntryFormView(compact: layout.stacksPairs)
                RecentEntriesCard(listHeight: layout.recentEntriesHeight) { section = .search }
                SummaryCardsRow()
                ThanksCard()
            }
        } else {
            HStack(alignment: .top, spacing: 18) {
                EntryFormView(compact: false)
                    .frame(minWidth: layout.entryFormWidth, maxWidth: 640)
                VStack(spacing: 18) {
                    RecentEntriesCard(listHeight: layout.recentEntriesHeight) { section = .search }
                    SummaryCardsRow()
                    ThanksCard()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct EntryFormView: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var nameFocused: Bool
    let compact: Bool

    var body: some View {
        Card(padding: compact ? 18 : 20) {
            VStack(alignment: .leading, spacing: 12) {
                Text("새로운 축의 입력")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppColors.text)
                AdaptivePair(stacked: compact) {
                    FieldLabel("봉투번호") {
                        TextField("봉투번호", value: $state.draft.envelopeNo, format: .number)
                            .textFieldStyle(.plain)
                            .font(.system(size: 18, weight: .semibold))
                    }
                } second: {
                    FieldLabel("입금방식") {
                        Picker("", selection: $state.draft.paymentMethod) {
                            ForEach(PaymentMethod.allCases) { method in
                                Text(method.label).tag(method)
                            }
                        }
                        .labelsHidden()
                    }
                }
                AdaptivePair(stacked: compact) {
                    FieldLabel("모임") {
                        SuggestionTextField(text: $state.draft.groupName, suggestions: state.groups)
                    }
                } second: {
                    FieldLabel("관계") {
                        SuggestionTextField(text: $state.draft.relationship, suggestions: state.relationships)
                    }
                }
                FieldLabel("이름") {
                    TextField("이름을 입력하세요", text: $state.draft.name)
                        .textFieldStyle(.plain)
                        .focused($nameFocused)
                }
                AdaptivePair(stacked: compact) {
                    FieldLabel("금액") {
                        HStack {
                            Text("₩").foregroundStyle(AppColors.muted)
                            TextField("금액을 입력하세요", text: $state.draft.amountText)
                                .textFieldStyle(.plain)
                                .onChange(of: state.draft.amountText) { _, value in
                                    let amount = parseAmount(value)
                                    state.draft.amountText = amount > 0 ? formatNumber(amount) : ""
                                }
                        }
                    }
                } second: {
                    FieldLabel("식권") {
                        HStack(spacing: 10) {
                            Image(systemName: "fork.knife").foregroundStyle(AppColors.muted)
                            Button("-") { state.draft.mealTicketCount = max(0, state.draft.mealTicketCount - 1) }
                            Text("\(state.draft.mealTicketCount)")
                                .frame(width: 30)
                            Button("+") { state.draft.mealTicketCount += 1 }
                            Text("매")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("금액 빠른 선택")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(defaultQuickAmounts, id: \.self) { amount in
                                PillButton(formatNumber(amount)) {
                                    state.draft.amountText = formatNumber(amount)
                                }
                            }
                            PillButton("+1만원", outlined: true) {
                                state.draft.amountText = formatNumber(state.draft.amount + 10_000)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                    .scrollIndicators(.hidden)
                }
                FieldLabel("메모 (선택)") {
                    TextEditor(text: $state.draft.memo)
                        .frame(height: 52)
                        .scrollContentBackground(.hidden)
                }
                Button {
                    state.saveEntry()
                    nameFocused = true
                } label: {
                    Text("저장")
                        .font(.system(size: 20, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppColors.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .foregroundStyle(AppColors.window)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RecentEntriesCard: View {
    @EnvironmentObject private var state: AppState
    let listHeight: CGFloat
    let showAll: () -> Void

    var body: some View {
        Card(padding: 22) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("최근 입력 내역")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Button("전체 보기 ›", action: showAll)
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.text)
                }
                ScrollView {
                    EntryTable(entries: state.recentEntries, compact: true)
                }
                .frame(height: listHeight)
                .scrollIndicators(.visible)
            }
        }
    }
}

struct SummaryCardsRow: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 18)], spacing: 18) {
            StatCard(title: "총 축의금", value: formatWon(state.summary.totalAmount), footnote: "건수 \(state.summary.activeCount)건", symbol: "wonsign")
            StatCard(title: "총 식권", value: "\(state.summary.totalTickets)매", footnote: "사용 \(state.summary.totalTickets)매 ㅣ 남은 0매", symbol: "fork.knife")
            StatCard(
                title: "평균 축의금",
                value: formatWon(state.summary.activeCount == 0 ? 0 : state.summary.totalAmount / state.summary.activeCount),
                footnote: "(축의금 기준)",
                symbol: "creditcard"
            )
        }
        .frame(maxWidth: .infinity)
    }
}

struct ThanksCard: View {
    var body: some View {
        Card(padding: 24) {
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
    let layout: ResponsiveLayout

    var body: some View {
        Card(padding: layout.cardPadding) {
            VStack(alignment: .leading, spacing: 22) {
                Text("검색")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: layout == .compact ? 150 : 180), spacing: 12)], spacing: 12) {
                    SoftTextField("이름", text: $filters.name)
                    SoftTextField("모임", text: $filters.groupName)
                    SoftTextField("최소 금액", text: $filters.minAmount)
                        .onChange(of: filters.minAmount) { _, value in filters.minAmount = formatFilterAmount(value) }
                    SoftTextField("최대 금액", text: $filters.maxAmount)
                        .onChange(of: filters.maxAmount) { _, value in filters.maxAmount = formatFilterAmount(value) }
                    SoftTextField("식권수", text: $filters.ticketCount)
                        .onChange(of: filters.ticketCount) { _, value in filters.ticketCount = value.filter(\.isNumber) }
                    Picker("입금방식", selection: Binding(get: { filters.paymentMethod }, set: { filters.paymentMethod = $0 })) {
                        Text("방식 전체").tag(PaymentMethod?.none)
                        ForEach(PaymentMethod.allCases) { method in
                            Text(method.label).tag(Optional(method))
                        }
                    }
                    Picker("상태", selection: Binding(get: { filters.status }, set: { filters.status = $0 })) {
                        Text("상태 전체").tag(EntryStatus?.none)
                        ForEach(EntryStatus.allCases) { status in
                            Text(status.label).tag(Optional(status))
                        }
                    }
                    Button("검색") { state.search(filters: filters) }
                        .buttonStyle(.plain)
                        .frame(height: 48)
                        .frame(maxWidth: .infinity)
                        .background(AppColors.goldSoft, in: Capsule())
                        .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
                        .foregroundStyle(AppColors.text)
                }
                EntryTable(entries: state.searchResults, compact: layout == .compact)
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
    let layout: ResponsiveLayout

    var body: some View {
        Card(padding: layout.cardPadding) {
            VStack(alignment: .leading, spacing: 22) {
                Text("정산")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 16)], spacing: 16) {
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
                    .foregroundStyle(AppColors.text)
                Table(state.summary.groupTotals) {
                    TableColumn("모임", value: \.groupName)
                    TableColumn("건수") { Text("\($0.count)") }
                    TableColumn("총액") { Text(formatWon($0.totalAmount)).foregroundStyle(AppColors.gold) }
                    TableColumn("식권") { Text("\($0.totalTickets)") }
                }
                .frame(minHeight: 260)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmAll = false
    @State private var confirmRecords = false
    @State private var confirmTest = false
    let layout: ResponsiveLayout

    var body: some View {
        Card(padding: layout.cardPadding) {
            VStack(alignment: .leading, spacing: 22) {
                Text("설정")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.text)
                SettingsRow(title: "화면 테마") {
                    ThemePreferenceControl(compact: layout == .compact)
                }
                SettingsRow(title: "현재 모드") {
                    Picker("현재 모드", selection: Binding(get: { state.mode }, set: { state.switchMode($0) })) {
                        ForEach(LedgerMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("데이터 위치")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text(state.store.appDirectory.path)
                        .font(.footnote)
                        .foregroundStyle(AppColors.muted)
                        .textSelection(.enabled)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 164), spacing: 12)], spacing: 12) {
                    SettingsActionButton("엑셀 추출") { exportExcel() }
                    SettingsActionButton("수동 백업 생성") { state.createBackup() }
                    SettingsActionButton("백업 복원") { restoreBackup() }
                    SettingsActionButton("테스트 데이터 초기화", destructive: true) { confirmTest = true }
                    SettingsActionButton("기록/목록 초기화", destructive: true) { confirmRecords = true }
                    SettingsActionButton("전체 초기화", destructive: true) { confirmAll = true }
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
                .foregroundStyle(AppColors.text)
            Text(state.isConfigured ? "비밀번호를 입력해 앱을 엽니다." : "처음 사용할 비밀번호를 설정하세요.")
                .foregroundStyle(AppColors.muted)
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
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(34)
        .frame(width: 420)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppColors.line, lineWidth: 1))
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
    @Environment(\.dismiss) private var dismiss
    @State private var didCopy = false
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
            Text(didCopy ? "복구키가 클립보드에 복사되었습니다." : "이 창을 닫아도 앱은 계속 사용할 수 있습니다.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack {
                Button("복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(recoveryKey, forType: .string)
                    didCopy = true
                }
                .buttonStyle(.borderedProminent)
                Spacer()
                Button("확인") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
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
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 140)
        } else if compact {
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    EntryCompactRow(entry: entry)
                    if entry.id != entries.last?.id {
                        Divider().background(AppColors.lineSoft)
                    }
                }
            }
            .background(AppColors.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.lineSoft, lineWidth: 1))
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

struct EntryCompactRow: View {
    let entry: LedgerEntry

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("#\(entry.envelopeNo)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
                .frame(width: 48, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.name)
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Text([entry.groupName, entry.relationship].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(formatWon(entry.amount))
                    .font(.headline)
                    .foregroundStyle(AppColors.gold)
                Text("식권 \(entry.mealTicketCount)매")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(16)
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

struct AdaptivePair<First: View, Second: View>: View {
    let stacked: Bool
    let first: First
    let second: Second

    init(stacked: Bool, @ViewBuilder first: () -> First, @ViewBuilder second: () -> Second) {
        self.stacked = stacked
        self.first = first()
        self.second = second()
    }

    var body: some View {
        if stacked {
            VStack(spacing: 12) {
                first
                second
            }
        } else {
            HStack(spacing: 16) {
                first
                second
            }
        }
    }
}

struct SoftTextField: View {
    let placeholder: String
    @Binding var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(AppColors.field, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.line, lineWidth: 1))
    }
}

struct SettingsRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 18) {
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            Spacer()
            content
        }
        .padding(.vertical, 18)
        .overlay(Rectangle().fill(AppColors.lineSoft).frame(height: 1), alignment: .bottom)
    }
}

struct SettingsActionButton: View {
    let title: String
    let destructive: Bool
    let action: () -> Void

    init(_ title: String, destructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.destructive = destructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .foregroundStyle(destructive ? AppColors.danger : AppColors.text)
                .background(destructive ? AppColors.danger.opacity(0.12) : AppColors.goldSoft, in: Capsule())
                .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private extension ThemePreference {
    var shortLabel: String {
        switch self {
        case .system: "시스템"
        case .light: "라이트"
        case .dark: "다크"
        }
    }
}
