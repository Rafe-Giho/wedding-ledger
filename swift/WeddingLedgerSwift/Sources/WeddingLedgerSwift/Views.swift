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
        } else if width < 1120 {
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
    var summaryTileColumns: [GridItem] {
        switch self {
        case .expanded:
            Array(repeating: GridItem(.flexible(minimum: 78), spacing: 8), count: 8)
        case .medium:
            Array(repeating: GridItem(.flexible(minimum: 120), spacing: 12), count: 4)
        case .compact:
            [GridItem(.adaptive(minimum: 150), spacing: 12)]
        }
    }
    var summaryTileSpacing: CGFloat { self == .expanded ? 8 : 12 }
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

enum GuidePage: String, Identifiable {
    case tips
    case checklist
    case usage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tips: "축의대 운영 TIP"
        case .checklist: "당일 체크리스트"
        case .usage: "프로그램 사용법"
        }
    }

    var symbol: String {
        switch self {
        case .tips: "lightbulb"
        case .checklist: "exclamationmark"
        case .usage: "info"
        }
    }
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

struct VersionBadge: View {
    var body: some View {
        Text("v\(appVersion)")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(AppColors.muted.opacity(0.72))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(AppColors.field.opacity(0.72), in: Capsule())
            .overlay(Capsule().stroke(AppColors.lineSoft.opacity(0.55), lineWidth: 1))
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
        GeometryReader { proxy in
            let contentHeight = max(320, proxy.size.height - layout.contentPadding)
            if section == .search && layout != .compact {
                content(availableHeight: contentHeight)
                    .frame(minHeight: contentHeight, maxHeight: .infinity, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            } else if section == .settings || layout == .compact {
                ScrollView {
                    content(availableHeight: contentHeight)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, layout.contentPadding)
                }
                .scrollIndicators(.visible)
            } else {
                ScrollView {
                    content(availableHeight: contentHeight)
                        .frame(minHeight: contentHeight, alignment: .topLeading)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(.bottom, layout.contentPadding)
                }
                .scrollIndicators(.visible)
            }
        }
    }

    @ViewBuilder
    private func content(availableHeight: CGFloat) -> some View {
        switch section {
        case .entry:
            EntryDashboardView(section: $section, layout: layout, availableHeight: availableHeight)
        case .search:
            SearchView(layout: layout, availableHeight: availableHeight)
        case .summary:
            SummaryView(section: $section, layout: layout, availableHeight: availableHeight)
        case .settings:
            SettingsView(layout: layout)
        }
    }
}

struct TopBarView: View {
    @EnvironmentObject private var state: AppState
    let compact: Bool

    var body: some View {
        HStack {
            Spacer()
            HStack(spacing: compact ? 8 : 10) {
                ModePill(title: "\(state.mode.label) 모드")
                ThemePreferenceControl(compact: compact)
                VersionBadge()
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, 6)
            .background(AppColors.field.opacity(0.34), in: Capsule())
            .overlay(Capsule().stroke(AppColors.lineSoft.opacity(0.48), lineWidth: 1))
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
    @State private var guidePage: GuidePage?
    let width: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let short = proxy.size.height < 760
            let topPadding: CGFloat = short ? 28 : 48
            let brandBottom: CGFloat = short ? 24 : 34
            let navSpacing: CGFloat = short ? 8 : 12
            let floralHeight = short
                ? min(88, max(44, proxy.size.height * 0.10))
                : min(220, max(120, proxy.size.height * 0.22))
            VStack(spacing: 0) {
                BrandLockup(horizontal: false)
                    .padding(.top, topPadding)
                    .padding(.bottom, brandBottom)
                VStack(spacing: navSpacing) {
                    ForEach(SectionKey.allCases) { item in
                        NavigationButton(item: item, isActive: section == item) {
                            section = item
                        }
                    }
                }
                .padding(.horizontal, width == 220 ? 18 : 28)
                Spacer(minLength: 10)
                FloralLineArt()
                    .stroke(AppColors.gold.opacity(0.34), lineWidth: 1.2)
                    .frame(width: width == 220 ? 150 : 188, height: floralHeight)
                    .padding(.bottom, short ? 10 : 14)
                GuideButtonRow { page in
                    guidePage = page
                }
                .padding(.bottom, short ? 8 : 12)
                Button("잠금") {
                    state.isUnlocked = false
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.text)
                .padding(.horizontal, 20)
                .frame(width: 148, height: 44)
                .background(AppColors.field, in: Capsule())
                .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
                .padding(.bottom, short ? 12 : 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: width)
        .background(AppColors.sidebar)
        .overlay(Rectangle().fill(AppColors.lineSoft).frame(width: 1), alignment: .trailing)
        .sheet(item: $guidePage) { page in
            GuideSheet(page: page)
        }
    }
}

struct GuideButtonRow: View {
    let open: (GuidePage) -> Void

    var body: some View {
        HStack(spacing: 10) {
            GuideCircleButton(title: "TIP", systemImage: GuidePage.tips.symbol) { open(.tips) }
            GuideCircleButton(title: "!", systemImage: GuidePage.checklist.symbol) { open(.checklist) }
            GuideCircleButton(title: "i", systemImage: GuidePage.usage.symbol) { open(.usage) }
        }
    }
}

struct GuideCircleButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(AppColors.gold)
            .frame(width: 44, height: 44)
            .background(AppColors.field, in: Circle())
            .overlay(Circle().stroke(AppColors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(title)
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
        AppSegmentedControl(
            selection: Binding(get: { state.themePreference }, set: { state.setTheme($0) }),
            options: ThemePreference.allCases.map { preference in
                (value: preference, title: preference.label)
            },
            compact: compact
        )
        .frame(width: compact ? 168 : 184)
    }
}

struct EntryDashboardView: View {
    @Binding var section: SectionKey
    let layout: ResponsiveLayout
    let availableHeight: CGFloat

    var body: some View {
        if layout == .compact {
            VStack(spacing: 18) {
                EntryFormView(compact: true)
                RecentEntriesCard(listHeight: layout.recentEntriesHeight, fillsHeight: false) { section = .search }
                SummaryCardsRow()
                ThanksCard()
            }
        } else if layout.stacksEntry {
            ScrollView {
                VStack(spacing: 18) {
                    EntryFormView(compact: false)
                    RecentEntriesCard(listHeight: layout.recentEntriesHeight, fillsHeight: false) { section = .search }
                    SummaryCardsRow()
                    ThanksCard()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(height: availableHeight)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scrollIndicators(.visible)
        } else {
            HStack(alignment: .top, spacing: 18) {
                EntryFormView(compact: false, fillsHeight: true)
                    .frame(minWidth: layout.entryFormWidth, maxWidth: 640)
                    .frame(height: availableHeight)
                VStack(spacing: 18) {
                    RecentEntriesCard(listHeight: nil, fillsHeight: true) { section = .search }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    SummaryCardsRow(fillsHeight: true)
                        .frame(maxWidth: .infinity)
                    ThanksCard()
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: availableHeight, alignment: .topLeading)
            }
            .frame(minHeight: availableHeight, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}

struct EntryFormView: View {
    @EnvironmentObject private var state: AppState
    @FocusState private var nameFocused: Bool
    let compact: Bool
    var fillsHeight = false

    var body: some View {
        let dense = fillsHeight && !compact
        Card(padding: compact ? 18 : (dense ? 18 : 20), fillsAvailableSpace: fillsHeight) {
            if fillsHeight {
                VStack(alignment: .leading, spacing: dense ? 10 : 12) {
                    ScrollView {
                        formFields(dense: dense)
                            .padding(.trailing, 4)
                    }
                    .scrollIndicators(.visible)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    formAction(dense: dense)
                }
                .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(alignment: .leading, spacing: dense ? 9 : 12) {
                    formFields(dense: dense)
                    formAction(dense: dense)
                }
            }
        }
    }

    private func formFields(dense: Bool) -> some View {
        VStack(alignment: .leading, spacing: dense ? 9 : 12) {
            Text("새로운 축의 입력")
                .font(.system(size: dense ? 21 : 22, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text("필수: 이름, 금액 · 자동/기본: 봉투번호/계좌차번, 입금방식, 식권 0매 · 선택: 모임, 관계, 대상, 메모")
                .font(.caption)
                .foregroundStyle(AppColors.muted)
            AdaptivePair(stacked: compact) {
                FieldLabel(state.draft.paymentMethod == .transfer ? "계좌차번" : "봉투번호", badge: "자동") {
                    TextField(
                        state.draft.paymentMethod == .transfer ? "계좌차번" : "봉투번호",
                        value: state.draft.paymentMethod == .transfer ? $state.draft.transferNo : $state.draft.envelopeNo,
                        format: .number
                    )
                        .textFieldStyle(.plain)
                        .font(.system(size: 18, weight: .semibold))
                }
            } second: {
                FieldLabel("입금방식", badge: "기본") {
                    MenuValueField(
                        value: state.draft.paymentMethod.label,
                        placeholder: "방식 선택",
                        options: PaymentMethod.allCases.map(\.label)
                    ) { label in
                        if let method = PaymentMethod.allCases.first(where: { $0.label == label }) {
                            state.setDraftPaymentMethod(method)
                        }
                    }
                }
            }
            if state.draft.paymentMethod == .transfer {
                FieldLabel("입금시간", badge: "선택") {
                    HStack(spacing: 10) {
                        TextField("YYYY-MM-DD HH:mm:ss 또는 HH:mm:ss", text: $state.draft.createdAtText)
                            .textFieldStyle(.plain)
                        Button("현재") {
                            state.draft.createdAtText = nowString()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Text("계좌 입금은 실제 입금 시각을 수정할 수 있습니다. 당일은 HH:mm:ss만 입력해도 됩니다.")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
            }
            FieldLabel("이름", badge: "필수") {
                TextField("이름을 입력하세요", text: $state.draft.name)
                    .textFieldStyle(.plain)
                    .focused($nameFocused)
                    .onChange(of: state.draft.name) { _, _ in
                        state.updateDuplicateMatches()
                    }
            }
            guestContextFields(dense: dense)
            amountAndTicketFields
            VStack(alignment: .leading, spacing: 8) {
                Text("금액 빠른 선택")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppColors.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: dense ? 86 : 92), spacing: dense ? 8 : 10)], spacing: dense ? 8 : 10) {
                    ForEach(defaultQuickAmounts, id: \.self) { amount in
                        QuickAmountButton(amount == 0 ? "0원" : formatNumber(amount)) {
                            state.draft.amountText = formatNumber(amount)
                        }
                    }
                    QuickAmountButton("+1만원", outlined: true) {
                        state.draft.amountText = formatNumber(state.draft.amount + 10_000)
                    }
                }
            }
            FieldLabel("메모", badge: "선택") {
                TextEditor(text: $state.draft.memo)
                    .frame(minHeight: dense ? 42 : 52, idealHeight: dense ? 54 : 52, maxHeight: dense ? 72 : 52)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    private func formattedAmountInput(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return formatNumber(Int(digits) ?? 0)
    }

    @ViewBuilder
    private var amountAndTicketFields: some View {
        let fields = [
            AnyView(amountField),
            AnyView(ticketCounter(title: "성인 식권", count: $state.draft.mealTicketCount)),
            AnyView(ticketCounter(title: "소인 식권", count: $state.draft.childMealTicketCount))
        ]
        if compact {
            VStack(spacing: 12) {
                ForEach(fields.indices, id: \.self) { fields[$0] }
            }
        } else {
            HStack(spacing: 12) {
                ForEach(fields.indices, id: \.self) { fields[$0] }
            }
        }
    }

    private var amountField: some View {
        FieldLabel("금액", badge: "필수") {
            HStack {
                Text("₩").foregroundStyle(AppColors.muted)
                TextField("금액을 입력하세요", text: $state.draft.amountText)
                    .textFieldStyle(.plain)
                    .onChange(of: state.draft.amountText) { _, value in
                        state.draft.amountText = formattedAmountInput(value)
                    }
            }
        }
    }

    private func ticketCounter(title: String, count: Binding<Int>) -> some View {
        FieldLabel(title, badge: "기본") {
            HStack(spacing: 9) {
                Image(systemName: "fork.knife").foregroundStyle(AppColors.muted)
                TicketStepButton(title: "-") {
                    count.wrappedValue = max(0, count.wrappedValue - 1)
                }
                Text("\(count.wrappedValue)")
                    .font(.system(size: 15, weight: .semibold))
                    .monospacedDigit()
                    .frame(width: 32)
                TicketStepButton(title: "+") {
                    count.wrappedValue += 1
                }
                Text("매")
            }
        }
    }

    @ViewBuilder
    private func guestContextFields(dense: Bool) -> some View {
        if compact {
            VStack(spacing: dense ? 8 : 12) {
                guestContextField(title: "모임", text: $state.draft.groupName, suggestions: state.groups)
                guestContextField(title: "관계", text: $state.draft.relationship, suggestions: state.relationships)
                guestContextField(title: "대상", text: $state.draft.targetPerson, suggestions: state.targets)
            }
        } else {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible(minimum: dense ? 112 : 128), spacing: dense ? 10 : 12),
                    count: 3
                ),
                spacing: dense ? 8 : 10
            ) {
                guestContextField(title: "모임", text: $state.draft.groupName, suggestions: state.groups)
                guestContextField(title: "관계", text: $state.draft.relationship, suggestions: state.relationships)
                guestContextField(title: "대상", text: $state.draft.targetPerson, suggestions: state.targets)
            }
        }
    }

    private func guestContextField(title: String, text: Binding<String>, suggestions: [String]) -> some View {
        FieldLabel(title, badge: "선택") {
            SuggestionTextField(text: text, suggestions: suggestions)
        }
    }

    @ViewBuilder
    private func formAction(dense: Bool) -> some View {
        if state.duplicateMatches.isEmpty {
            Button {
                state.saveEntry()
                nameFocused = true
            } label: {
                Text("저장")
                    .font(.system(size: 20, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: dense ? 48 : 52)
                    .background(AppColors.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .foregroundStyle(AppColors.window)
            }
            .buttonStyle(.plain)
        } else {
            DuplicateNameReviewCard(matches: state.duplicateMatches) {
                state.saveEntry(forceDuplicate: true)
                nameFocused = true
            } cancel: {
                state.cancelDuplicateReview()
                nameFocused = true
            }
        }
    }
}

struct TicketStepButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.text)
                .frame(width: 34, height: 30)
                .background(AppColors.goldSoft.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.lineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct DuplicateNameReviewCard: View {
    let matches: [LedgerEntry]
    let saveDuplicate: () -> Void
    let cancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("같은 이름의 정상 기록이 있습니다.")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(AppColors.text)
            Text("기존 기록을 확인한 뒤 새 동명이인으로 저장하거나 취소할 수 있습니다.")
                .font(.footnote)
                .foregroundStyle(AppColors.muted)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(matches) { entry in
                        DuplicateEntryPreviewRow(entry: entry)
                    }
                }
            }
            .frame(maxHeight: 190)
            .scrollIndicators(.visible)
            HStack(spacing: 10) {
                PillButton("취소하고 확인", outlined: true, action: cancel)
                PillButton("새 동명이인으로 저장", action: saveDuplicate)
            }
        }
        .padding(16)
        .background(AppColors.goldSoft.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.gold.opacity(0.55), lineWidth: 1))
    }
}

struct DuplicateEntryPreviewRow: View {
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(entry.sequenceLabel)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text(entry.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text(ledgerClockText(entry.createdAt))
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
                    .help(entry.createdAt)
            }
            Text("모임 \(entry.groupName) · 관계 \(entry.relationship.isEmpty ? "-" : entry.relationship) · 대상 \(entry.targetPerson.isEmpty ? "-" : entry.targetPerson)")
                .font(.caption)
                .foregroundStyle(AppColors.muted)
            Text("금액 \(formatWon(entry.amount)) · 성인 \(entry.mealTicketCount)매 · 소인 \(entry.childMealTicketCount)매")
                .font(.caption)
                .foregroundStyle(AppColors.text)
        }
        .padding(12)
        .background(AppColors.field, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.lineSoft, lineWidth: 1))
    }
}

struct RecentEntriesCard: View {
    @EnvironmentObject private var state: AppState
    let listHeight: CGFloat?
    let fillsHeight: Bool
    let showAll: () -> Void

    var body: some View {
        Card(padding: 22, fillsAvailableSpace: fillsHeight) {
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
                .frame(maxHeight: fillsHeight ? .infinity : nil)
                .scrollIndicators(.visible)
            }
            .frame(maxHeight: fillsHeight ? .infinity : nil, alignment: .topLeading)
        }
    }
}

struct SummaryCardsRow: View {
    @EnvironmentObject private var state: AppState
    var fillsHeight = false

    var body: some View {
        LazyVGrid(columns: columns, spacing: fillsHeight ? 12 : 18) {
            StatCard(title: "총 축의금", value: formatWon(state.summary.totalAmount), footnote: "건수 \(state.summary.activeCount)건", symbol: "wonsign", fillsHeight: fillsHeight)
            StatCard(title: "총 식권", value: "\(state.summary.totalTickets + state.summary.totalChildTickets)매", footnote: ticketFootnote, symbol: "fork.knife", fillsHeight: fillsHeight)
            StatCard(title: "총 봉투수", value: "\(state.summary.activeCount)개", footnote: envelopeFootnote, symbol: "envelope", fillsHeight: fillsHeight)
            StatCard(
                title: "평균 축의금",
                value: formatWon(state.summary.activeCount == 0 ? 0 : state.summary.totalAmount / state.summary.activeCount),
                footnote: "(축의금 기준)",
                symbol: "creditcard",
                fillsHeight: fillsHeight
            )
        }
        .frame(maxWidth: .infinity)
    }

    private var columns: [GridItem] {
        fillsHeight
            ? [GridItem(.flexible(minimum: 150), spacing: 12), GridItem(.flexible(minimum: 150), spacing: 12)]
            : [GridItem(.adaptive(minimum: 190), spacing: 18)]
    }

    private var ticketFootnote: String {
        let adultTotal = state.operationSettings.totalMealTickets
        let childTotal = state.operationSettings.totalChildMealTickets
        let adultText = adultTotal > 0 ? "성인 \(state.summary.totalTickets)/\(adultTotal)매" : "성인 \(state.summary.totalTickets)매"
        let childText = childTotal > 0 ? "소인 \(state.summary.totalChildTickets)/\(childTotal)매" : "소인 \(state.summary.totalChildTickets)매"
        return "\(adultText) ㅣ \(childText)"
    }

    private var envelopeFootnote: String {
        let expected = state.operationSettings.expectedEnvelopeCount
        guard expected > 0 else { return "정상 기록 기준" }
        return "예상 \(expected)개 ㅣ 차이 \(expected - state.summary.activeCount)개"
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
    let availableHeight: CGFloat

    var body: some View {
        Card(padding: layout.cardPadding, fillsAvailableSpace: layout != .compact) {
            VStack(alignment: .leading, spacing: layout == .compact ? 18 : 14) {
                Text("검색")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: layout == .compact ? 150 : 156), spacing: 10)], spacing: 10) {
                    SoftTextField("이름", text: Binding(
                        get: { filters.name },
                        set: {
                            filters.name = $0
                            filters.exactName = false
                        }
                    ))
                    SoftTextField("모임", text: $filters.groupName)
                    SoftTextField("관계", text: $filters.relationship)
                    SoftTextField("대상", text: $filters.targetPerson)
                    SoftTextField("최소 금액", text: $filters.minAmount)
                        .onChange(of: filters.minAmount) { _, value in filters.minAmount = formatFilterAmount(value) }
                    SoftTextField("최대 금액", text: $filters.maxAmount)
                        .onChange(of: filters.maxAmount) { _, value in filters.maxAmount = formatFilterAmount(value) }
                    SoftTextField("성인 식권수", text: $filters.ticketCount)
                        .onChange(of: filters.ticketCount) { _, value in filters.ticketCount = value.filter(\.isNumber) }
                    SoftTextField("소인 식권수", text: $filters.childTicketCount)
                        .onChange(of: filters.childTicketCount) { _, value in filters.childTicketCount = value.filter(\.isNumber) }
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
                    SearchActionButton(title: "검색", primary: true) { performSearch() }
                        .keyboardShortcut(.return)
                    SearchActionButton(title: "초기화", primary: false) { resetSearch() }
                }
                .submitLabel(.search)
                .onSubmit(performSearch)
                DuplicateNameFilterRow(duplicates: state.summary.duplicateNames) { duplicate in
                    state.filterDuplicateName(duplicate.name)
                    filters = state.searchFilters
                }
                EntryTable(entries: state.searchResults, compact: layout == .compact, allowsManagement: true)
                    .frame(minHeight: layout == .compact ? nil : 220, maxHeight: layout == .compact ? nil : .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: layout == .compact ? nil : .infinity, alignment: .topLeading)
        }
        .frame(minHeight: layout == .compact ? nil : availableHeight, maxHeight: layout == .compact ? nil : .infinity)
        .onAppear {
            filters = state.searchFilters
        }
        .onChange(of: state.searchFilters) { _, value in
            filters = value
        }
    }

    private func formatFilterAmount(_ value: String) -> String {
        let digits = value.filter(\.isNumber)
        guard !digits.isEmpty else { return "" }
        return formatNumber(Int(digits) ?? 0)
    }

    private func performSearch() {
        state.search(filters: filters)
    }

    private func resetSearch() {
        filters = EntryFilters()
        state.resetSearch()
    }
}

struct SearchActionButton: View {
    let title: String
    let primary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.text)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(primary ? AppColors.goldSoft : AppColors.field, in: Capsule())
        .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
        .contentShape(Capsule())
    }
}

struct SummaryView: View {
    @EnvironmentObject private var state: AppState
    @Binding var section: SectionKey
    let layout: ResponsiveLayout
    let availableHeight: CGFloat

    var body: some View {
        Card(padding: layout.cardPadding, fillsAvailableSpace: layout != .compact) {
            VStack(alignment: .leading, spacing: 22) {
                Text("정산")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(AppColors.text)
                Text("최근 입력: \(latestEntryTime)")
                    .font(.footnote)
                    .foregroundStyle(AppColors.muted)
                SummaryOverviewSection(section: $section, layout: layout)
                ClosingChecklistCard(section: $section)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: layout == .compact ? nil : .infinity, alignment: .topLeading)
        }
        .frame(minHeight: layout == .compact ? nil : availableHeight)
    }

    private var latestEntryTime: String {
        guard let timestamp = state.recentEntries.first?.createdAt else {
            return "아직 입력 없음"
        }
        return "\(ledgerDateText(timestamp)) \(ledgerClockText(timestamp))"
    }
}

struct SummaryOverviewSection: View {
    @EnvironmentObject private var state: AppState
    @Binding var section: SectionKey
    let layout: ResponsiveLayout

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("정산 현황")
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Text("총 기록과 검수 정보를 중복 없이 한 번에 확인합니다.")
                    .font(.footnote)
                    .foregroundStyle(AppColors.muted)
                Spacer()
            }
            LazyVGrid(columns: columns, spacing: 12) {
                SettlementCheckCard(
                    title: "총 축의금",
                    value: formatWon(state.summary.totalAmount),
                    detail: "정상 \(state.summary.activeCount)건 · 취소 \(state.summary.voidCount)건",
                    symbol: "wonsign"
                )
                SettlementCheckCard(
                    title: "평균 축의금",
                    value: formatWon(averageAmount),
                    detail: state.summary.activeCount == 0 ? "정상 기록 기준" : "\(state.summary.activeCount)건 평균",
                    symbol: "divide.circle"
                )
                SettlementCheckCard(
                    title: "입금 방식",
                    value: paymentHeadline,
                    detail: paymentDetail,
                    symbol: "creditcard"
                )
                SettlementCheckCard(
                    title: "식권",
                    value: "\(state.summary.totalTickets + state.summary.totalChildTickets)매",
                    detail: ticketDetail,
                    symbol: "ticket"
                )
                SettlementCheckCard(
                    title: "봉투 검수",
                    value: "\(state.summary.activeCount)개",
                    detail: envelopeDetail,
                    symbol: "envelope.open"
                )
                Button {
                    if let duplicate = state.summary.duplicateNames.first {
                        state.filterDuplicateName(duplicate.name)
                        section = .search
                    }
                } label: {
                    SettlementCheckCard(
                        title: "동명이인",
                        value: state.summary.duplicateNames.isEmpty ? "없음" : "\(state.summary.duplicateNames.count)건",
                        detail: duplicateDetail,
                        symbol: "person.2"
                    )
                }
                .buttonStyle(.plain)
                .disabled(state.summary.duplicateNames.isEmpty)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppColors.field.opacity(0.58), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.line.opacity(0.45), lineWidth: 1))
    }

    private var columns: [GridItem] {
        switch layout {
        case .expanded:
            Array(repeating: GridItem(.flexible(minimum: 190), spacing: 12), count: 3)
        case .medium:
            Array(repeating: GridItem(.flexible(minimum: 180), spacing: 12), count: 2)
        case .compact:
            [GridItem(.adaptive(minimum: 180), spacing: 12)]
        }
    }

    private var averageAmount: Int {
        guard state.summary.activeCount > 0 else { return 0 }
        return state.summary.totalAmount / state.summary.activeCount
    }

    private var paymentHeadline: String {
        let cash = state.summary.paymentTotals[.cash] ?? 0
        let transfer = state.summary.paymentTotals[.transfer] ?? 0
        if transfer > cash { return "계좌 \(formatWon(transfer))" }
        return "현금 \(formatWon(cash))"
    }

    private var paymentDetail: String {
        let cash = state.summary.paymentTotals[.cash] ?? 0
        let transfer = state.summary.paymentTotals[.transfer] ?? 0
        let other = state.summary.paymentTotals[.other] ?? 0
        return "현금 \(formatWon(cash)) · 계좌 \(formatWon(transfer)) · 기타 \(formatWon(other))"
    }

    private var ticketDetail: String {
        let adult = state.operationSettings.totalMealTickets
        let child = state.operationSettings.totalChildMealTickets
        let adultText = adult > 0 ? "성인 \(state.summary.totalTickets)/\(adult)매" : "성인 \(state.summary.totalTickets)매"
        let childText = child > 0 ? "소인 \(state.summary.totalChildTickets)/\(child)매" : "소인 \(state.summary.totalChildTickets)매"
        return "\(adultText) · \(childText)"
    }

    private var envelopeDetail: String {
        let expected = state.operationSettings.expectedEnvelopeCount
        let expectedText = expected > 0 ? "예상 \(expected)개 · 차이 \(expected - state.summary.activeCount)개" : "예상 봉투수를 설정하면 차이를 표시합니다."
        let gapText = state.summary.envelopeGaps.isEmpty ? "누락 없음" : "누락 \(state.summary.envelopeGaps.prefix(6).map(String.init).joined(separator: ", "))"
        return "\(expectedText) · \(gapText)"
    }

    private var duplicateDetail: String {
        state.summary.duplicateNames.isEmpty
            ? "같은 이름 없음"
            : state.summary.duplicateNames.prefix(3).map { "\($0.name) \($0.count)명" }.joined(separator: ", ")
    }
}

struct ClosingChecklistCard: View {
    @EnvironmentObject private var state: AppState
    @Binding var section: SectionKey

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("마감 검수 순서")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text("모임보다 봉투, 현금, 계좌, 식권, 동명이인을 우선 확인하세요.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer()
                Button("상세 검색") {
                    section = .search
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppColors.gold)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                ClosingCheckItem(
                    number: "1",
                    title: "봉투 수",
                    detail: envelopeDetail,
                    checked: state.closingChecks.contains(.envelope)
                ) {
                    state.toggleClosingCheck(.envelope)
                }
                ClosingCheckItem(
                    number: "2",
                    title: "현금",
                    detail: "실물 현금 \(formatWon(state.summary.paymentTotals[.cash] ?? 0)) 대조",
                    checked: state.closingChecks.contains(.cash)
                ) {
                    state.toggleClosingCheck(.cash)
                }
                ClosingCheckItem(
                    number: "3",
                    title: "계좌",
                    detail: "계좌 입금 \(formatWon(state.summary.paymentTotals[.transfer] ?? 0)) 대조",
                    checked: state.closingChecks.contains(.transfer)
                ) {
                    state.toggleClosingCheck(.transfer)
                }
                ClosingCheckItem(
                    number: "4",
                    title: "식권",
                    detail: ticketDetail,
                    checked: state.closingChecks.contains(.ticket)
                ) {
                    state.toggleClosingCheck(.ticket)
                }
                ClosingCheckItem(
                    number: "5",
                    title: "누락/동명이인",
                    detail: duplicateAndGapDetail,
                    checked: state.closingChecks.contains(.issues)
                ) {
                    if let duplicate = state.summary.duplicateNames.first {
                        state.filterDuplicateName(duplicate.name)
                        section = .search
                    }
                    state.toggleClosingCheck(.issues)
                }
                ClosingCheckItem(
                    number: "6",
                    title: "백업/엑셀",
                    detail: "마감 전 백업 후 엑셀 추출",
                    checked: state.closingChecks.contains(.export)
                ) {
                    state.toggleClosingCheck(.export)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(AppColors.field, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.line.opacity(0.5), lineWidth: 1))
    }

    private var envelopeDetail: String {
        let expected = state.operationSettings.expectedEnvelopeCount
        guard expected > 0 else { return "정상 기록 \(state.summary.activeCount)개" }
        return "정상 \(state.summary.activeCount)개 / 예상 \(expected)개"
    }

    private var ticketDetail: String {
        [
            ticketUsageText(title: "성인", used: state.summary.totalTickets, prepared: state.operationSettings.totalMealTickets),
            ticketUsageText(title: "소인", used: state.summary.totalChildTickets, prepared: state.operationSettings.totalChildMealTickets)
        ].joined(separator: ", ")
    }

    private func ticketUsageText(title: String, used: Int, prepared: Int) -> String {
        guard prepared > 0 else { return "\(title) 사용 \(used)매" }
        return "\(title) 사용 \(used)/\(prepared)매 · 남은 \(max(0, prepared - used))매"
    }

    private var duplicateAndGapDetail: String {
        let gapText = state.summary.envelopeGaps.isEmpty ? "누락 없음" : "누락 \(state.summary.envelopeGaps.count)개"
        let duplicateText = state.summary.duplicateNames.isEmpty ? "동명이인 없음" : "동명이인 \(state.summary.duplicateNames.count)건"
        return "\(gapText), \(duplicateText)"
    }
}

struct ClosingCheckItem: View {
    let number: String
    let title: String
    let detail: String
    let checked: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(checked ? AppColors.gold : AppColors.muted)
                    .frame(width: 24, height: 24)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(number)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColors.gold)
                        Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(AppColors.text)
                    }
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 66, alignment: .topLeading)
            .background(checked ? AppColors.goldSoft.opacity(0.72) : AppColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(checked ? AppColors.gold.opacity(0.65) : AppColors.lineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct SettlementCheckCard: View {
    let title: String
    let value: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(AppColors.gold)
                .frame(width: 32, height: 32)
                .background(AppColors.goldSoft, in: Circle())
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppColors.muted)
                Text(value)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(detail.isEmpty ? "-" : detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .topLeading)
        .background(AppColors.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.line.opacity(0.48), lineWidth: 1))
    }
}

struct DuplicateNameFilterRow: View {
    let duplicates: [DuplicateName]
    let select: (DuplicateName) -> Void

    var body: some View {
        if !duplicates.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("동명이인 바로 확인")
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], spacing: 10) {
                    ForEach(duplicates) { duplicate in
                        Button {
                            select(duplicate)
                        } label: {
                            Text("\(duplicate.name) \(duplicate.count)명")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AppColors.text)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                                .background(AppColors.goldSoft, in: Capsule())
                                .overlay(Capsule().stroke(AppColors.gold.opacity(0.55), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
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
                    AppSegmentedControl(
                        selection: Binding(get: { state.mode }, set: { state.switchMode($0) }),
                        options: LedgerMode.allCases.map { mode in
                            (value: mode, title: mode.label)
                        },
                        compact: layout == .compact
                    )
                    .frame(width: 180)
                }
                OperationSettingsPanel()
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
                    SettingsActionButton("위치 열기") { state.openLastExportLocation() }
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
        panel.nameFieldStringValue = "wedding_ledger_export.xlsx"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]
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

struct OperationSettingsPanel: View {
    @EnvironmentObject private var state: AppState
    @State private var eventTitle = ""
    @State private var totalMealTickets = ""
    @State private var totalChildMealTickets = ""
    @State private var expectedEnvelopeCount = ""
    @State private var operationNote = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("운영 설정")
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text("정산 검수와 안내 페이지에 함께 반영됩니다.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.muted)
                }
                Spacer()
                PillButton("저장", action: save)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                SoftTextField("행사명", text: $eventTitle)
                SoftTextField("총 성인 식권수", text: $totalMealTickets)
                    .onChange(of: totalMealTickets) { _, value in totalMealTickets = formatSettingNumber(value) }
                SoftTextField("총 소인 식권수", text: $totalChildMealTickets)
                    .onChange(of: totalChildMealTickets) { _, value in totalChildMealTickets = formatSettingNumber(value) }
                SoftTextField("예상 봉투수", text: $expectedEnvelopeCount)
                    .onChange(of: expectedEnvelopeCount) { _, value in expectedEnvelopeCount = formatSettingNumber(value) }
            }
            TextEditor(text: $operationNote)
                .frame(minHeight: 76)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(AppColors.field, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.line, lineWidth: 1))
        }
        .padding(.vertical, 18)
        .overlay(Rectangle().fill(AppColors.lineSoft).frame(height: 1), alignment: .bottom)
        .onAppear(perform: sync)
        .onChange(of: state.operationSettings) { _, _ in sync() }
    }

    private func sync() {
        eventTitle = state.operationSettings.eventTitle
        totalMealTickets = state.operationSettings.totalMealTickets > 0 ? formatNumber(state.operationSettings.totalMealTickets) : ""
        totalChildMealTickets = state.operationSettings.totalChildMealTickets > 0 ? formatNumber(state.operationSettings.totalChildMealTickets) : ""
        expectedEnvelopeCount = state.operationSettings.expectedEnvelopeCount > 0 ? formatNumber(state.operationSettings.expectedEnvelopeCount) : ""
        operationNote = state.operationSettings.operationNote
    }

    private func save() {
        state.saveOperationSettings(
            OperationSettings(
                eventTitle: eventTitle,
                totalMealTickets: parseAmount(totalMealTickets),
                totalChildMealTickets: parseAmount(totalChildMealTickets),
                expectedEnvelopeCount: parseAmount(expectedEnvelopeCount),
                operationNote: operationNote
            )
        )
    }

    private func formatSettingNumber(_ value: String) -> String {
        let number = parseAmount(value)
        return number > 0 ? formatNumber(number) : ""
    }
}

struct GuideSheet: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.dismiss) private var dismiss
    let page: GuidePage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: page.symbol)
                        .foregroundStyle(AppColors.gold)
                        .frame(width: 42, height: 42)
                        .background(AppColors.goldSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(page.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(AppColors.text)
                        Text(state.operationSettings.eventTitle.isEmpty ? "현장 운영 가이드" : state.operationSettings.eventTitle)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.muted)
                    }
                    Spacer()
                    Button("닫기") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColors.text)
                }
                ForEach(guideSections(for: page, settings: state.operationSettings)) { section in
                    GuideSectionCard(section: section)
                }
            }
            .padding(28)
        }
        .frame(width: 660, height: 640)
        .background(AppColors.window)
    }
}

struct GuideSection: Identifiable {
    let id = UUID()
    let title: String
    let items: [String]
}

struct GuideSectionCard: View {
    let section: GuideSection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(AppColors.text)
            ForEach(section.items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle()
                        .fill(AppColors.gold)
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(item)
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.line.opacity(0.5), lineWidth: 1))
    }
}

private func guideSections(for page: GuidePage, settings: OperationSettings) -> [GuideSection] {
    switch page {
    case .tips:
        return [
            GuideSection(title: "정산의 정석", items: [
                "봉투와 돈은 즉시 분리하지 않습니다. 금액이 비었을 때 확인할 방법이 사라집니다.",
                "하객이 봉투를 주면 봉투 겉면에 순번을 먼저 적고, 앱의 봉투번호와 맞춥니다.",
                "봉투 안 금액을 확인한 뒤 봉투 뒷면에도 금액을 적고 앱에 이름, 관계, 대상, 금액을 기록합니다.",
                "봉투는 10장 또는 20장 단위로 고무줄이나 집게로 묶어두면 마감 정산이 빨라집니다."
            ]),
            GuideSection(title: "식권과 답례품", items: [
                "미리 도장이나 사인이 된 식권만 배부해 웨딩홀 공용 식권과 섞이지 않게 합니다.",
                "답례품권을 드릴 때는 반드시 식권을 회수한 뒤 드려 이중 지출을 막습니다.",
                "어린이 하객 식권은 성인 식권과 구분해 전달합니다. 식대 차이가 생길 수 있습니다.",
                "설정에 성인/소인 총 식권수를 입력해 정산 탭에서 남은 식권을 계속 확인합니다."
            ]),
            GuideSection(title: "보안과 사고 예방", items: [
                "낯선 사람이 가족, 심부름, 확인 명목으로 접근해도 신랑/신부 본인이나 미리 약속된 직계 가족이 아니면 봉투를 넘기지 않습니다.",
                "축의금 가방은 의자 뒤가 아니라 몸에 지니거나 책상 아래 깊숙이 보관합니다.",
                "자리 비움은 최소 2인 1조로 교대하고, 한 명은 반드시 축의대 자리를 지킵니다.",
                "무리한 요청에는 '저희는 전달만 받는 입장이라 권한이 없습니다. 죄송합니다.'라고 정중히 선을 긋습니다."
            ])
        ]
    case .checklist:
        return [
            GuideSection(title: "행사 전", items: [
                "비밀번호와 복구키를 확인합니다.",
                "테스트 모드에서 3건 이상 입력해 저장, 검색, 취소, 복구, 엑셀 추출을 점검합니다.",
                settings.totalMealTickets > 0 ? "설정된 총 성인 식권수: \(settings.totalMealTickets)매" : "설정에서 총 성인 식권수를 입력해 남은 식권을 볼 수 있게 합니다.",
                settings.totalChildMealTickets > 0 ? "설정된 총 소인 식권수: \(settings.totalChildMealTickets)매" : "소인 하객이 예상되면 총 소인 식권수도 입력합니다.",
                settings.expectedEnvelopeCount > 0 ? "설정된 예상 봉투수: \(settings.expectedEnvelopeCount)개" : "예상 봉투수가 있으면 설정에 입력해 봉투 차이를 확인합니다.",
                "볼펜 3~4자루, 고무줄, 집게, 실물 계산기, 간식, 물을 준비합니다."
            ]),
            GuideSection(title: "운영 중", items: [
                "봉투를 받으면 순번을 적고, 금액 확인 후 봉투 뒷면에도 금액을 적습니다. 계좌이체는 앱의 계좌차번으로 별도 대조합니다.",
                "앱 저장 후 최근 입력 내역에서 봉투번호와 이름이 맞는지 바로 확인합니다.",
                "방명록 없이 가려는 하객에게는 방명록 작성을 한 번 더 권유합니다.",
                "동명이인, 누락 봉투, 과도하게 큰 금액은 바로 메모 또는 검색으로 재확인합니다.",
                "식권 잔여량이 빠르게 줄면 정산 탭의 식권 대조 카드를 수시로 봅니다."
            ]),
            GuideSection(title: "마감", items: [
                "예식 시작 10~20분 뒤 하객 발길이 끊기면 준비된 정산실 또는 계산실로 이동합니다.",
                "정산 탭에서 현금 합계를 실물 현금과 대조합니다.",
                "계좌 합계를 계좌 입금 내역과 대조합니다.",
                "누락 봉투와 동명이인 목록을 확인합니다.",
                "남은 식권은 그대로 신랑/신부에게 돌려주어 웨딩홀 실제 사용량 대조 증거로 남깁니다.",
                "엑셀 추출 전에 수동 백업을 만들고, 추출 파일을 별도 위치에 보관합니다."
            ])
        ]
    case .usage:
        return [
            GuideSection(title: "입력", items: [
                "봉투번호는 자동 증가하지만 필요하면 직접 수정할 수 있습니다.",
                "이름과 금액은 필수이며, 금액은 0원도 저장할 수 있습니다. 식권 수는 성인/소인 모두 기본 0매입니다.",
                "모임, 관계, 대상은 직접 입력하면 이후 목록에서 다시 선택할 수 있습니다.",
                "같은 이름이 있으면 기존 기록이 즉시 표시되고 새 동명이인 저장 여부를 고를 수 있습니다."
            ]),
            GuideSection(title: "검색/정산", items: [
                "검색에서는 이름, 모임, 대상, 금액 범위, 성인/소인 식권수, 입금방식, 상태로 기록을 찾습니다.",
                "정산에서는 봉투 대조, 식권 대조, 현금 확인, 계좌 확인 카드를 먼저 확인합니다.",
                "마감 검수 순서에서 실물 봉투, 현금, 계좌 입금, 남은 식권, 동명이인을 차례로 확인합니다."
            ]),
            GuideSection(title: "설정/엑셀", items: [
                "설정에서 총 성인/소인 식권수와 예상 봉투수를 입력하면 입력과 정산 카드에 남은 수량과 차이가 표시됩니다.",
                "엑셀 추출은 전체내역, 요약, 검색용, 봉투 검수, 현금·계좌 정산, 식권 검수, 동명이인, 수정이력 시트를 포함합니다.",
                "백업 복원 전에는 현재 DB가 자동 백업됩니다."
            ])
        ]
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
            Button(state.isConfigured ? "로그인" : "비밀번호 설정", action: submit)
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
        .submitLabel(.done)
        .onSubmit(submit)
        .sheet(isPresented: $showRecovery) {
            PasswordResetView()
        }
    }

    private func submit() {
        if state.isConfigured {
            state.login(password: password)
        } else {
            state.setup(password: password, confirmation: confirmation)
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
    var allowsManagement = false
    @State private var sortOrder: [KeyPathComparator<LedgerEntry>] = []

    var body: some View {
        if entries.isEmpty {
            Text("아직 입력된 기록이 없습니다.")
                .foregroundStyle(AppColors.muted)
                .frame(maxWidth: .infinity, minHeight: 140)
        } else if compact {
            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    EntryCompactRow(entry: entry, allowsManagement: allowsManagement)
                    if entry.id != entries.last?.id {
                        Divider().background(AppColors.lineSoft)
                    }
                }
            }
            .background(AppColors.field, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.lineSoft, lineWidth: 1))
        } else {
            Table(displayedEntries, sortOrder: $sortOrder) {
                TableColumn("차번", value: \.sortSequence) { Text($0.shortSequenceLabel).monospacedDigit() }
                    .width(min: 58, ideal: 72, max: 86)
                TableColumn("이름", value: \.name) { Text($0.name).lineLimit(1) }
                    .width(min: 78, ideal: 100, max: 150)
                TableColumn("분류", value: \.sortCategory) { EntryCategoryCell(entry: $0) }
                    .width(min: 94, ideal: 116, max: 142)
                TableColumn("금액", value: \.amount) { Text(formatWon($0.amount)).foregroundStyle(AppColors.gold).monospacedDigit() }
                    .width(min: 92, ideal: 112, max: 132)
                TableColumn("식권", value: \.totalMealTicketCount) { TicketCountCell(entry: $0) }
                    .width(min: 58, ideal: 70, max: 84)
                TableColumn("방식", value: \.sortPaymentMethod) { Text($0.paymentMethod.label) }
                    .width(min: 48, ideal: 56, max: 64)
                TableColumn("상태", value: \.sortStatus) { EntryStatusBadge(status: $0.status) }
                    .width(min: 54, ideal: 62, max: 72)
                TableColumn("시간", value: \.createdAt) { EntryTimeCell(timestamp: $0.createdAt) }
                    .width(min: 84, ideal: 94, max: 108)
                TableColumn("메모", value: \.memo) { entry in
                    Text(entry.memo.isEmpty ? "-" : entry.memo)
                        .foregroundStyle(entry.memo.isEmpty ? AppColors.muted : AppColors.text)
                        .lineLimit(1)
                        .help(entry.memo.isEmpty ? "메모 없음" : entry.memo)
                }
                .width(min: 90, ideal: 116, max: 160)
                TableColumn("관리") { EntryManagementActions(entry: $0, compact: false) }
                    .width(min: 112, ideal: 124, max: 142)
            }
            .frame(minHeight: 220, maxHeight: .infinity)
            .onChange(of: sortOrder) { oldValue, newValue in
                guard
                    let oldSort = oldValue.first,
                    let newSort = newValue.first,
                    oldSort.keyPath == newSort.keyPath,
                    oldSort.order == .reverse,
                    newSort.order == .forward
                else { return }
                sortOrder = []
            }
        }
    }

    private var displayedEntries: [LedgerEntry] {
        guard !sortOrder.isEmpty else { return entries }
        return entries.sorted(using: sortOrder)
    }
}

private extension LedgerEntry {
    var sortCategory: String {
        [groupName, relationship, targetPerson].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var sortSequence: String {
        if paymentMethod == .transfer {
            return "2-\(String(format: "%08d", transferNo > 0 ? transferNo : envelopeNo))"
        }
        return "1-\(String(format: "%08d", envelopeNo))"
    }

    var sortPaymentMethod: String {
        paymentMethod.label
    }

    var sortStatus: String {
        status.label
    }
}

struct TicketCountCell: View {
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("성 \(entry.mealTicketCount)")
                .font(.caption)
                .foregroundStyle(AppColors.text)
                .monospacedDigit()
            Text("소 \(entry.childMealTicketCount)")
                .font(.caption2)
                .foregroundStyle(AppColors.muted)
                .monospacedDigit()
        }
    }
}

struct EntryCategoryCell: View {
    let entry: LedgerEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.groupName)
                .font(.caption)
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
            Text([entry.relationship, entry.targetPerson.isEmpty ? "" : "대상 \(entry.targetPerson)"].filter { !$0.isEmpty }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(AppColors.muted)
                .lineLimit(1)
        }
    }
}

struct EntryStatusBadge: View {
    let status: EntryStatus

    var body: some View {
        Text(status.label)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(status == .active ? AppColors.text : AppColors.danger)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status == .active ? AppColors.goldSoft.opacity(0.72) : AppColors.danger.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(status == .active ? AppColors.line : AppColors.danger.opacity(0.35), lineWidth: 1))
    }
}

struct EntryTimeCell: View {
    let timestamp: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ledgerClockText(timestamp))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColors.text)
            Text(ledgerDateText(timestamp))
                .font(.caption2)
                .foregroundStyle(AppColors.muted)
        }
        .help(timestamp)
    }
}

struct EntryCompactRow: View {
    let entry: LedgerEntry
    var allowsManagement = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Text(entry.shortSequenceLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 48, alignment: .leading)
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name)
                        .font(.headline)
                        .foregroundStyle(AppColors.text)
                    Text([entry.groupName, entry.relationship, entry.targetPerson.isEmpty ? "" : "대상 \(entry.targetPerson)"].filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.muted)
                    if !entry.memo.isEmpty {
                        Text(entry.memo)
                            .font(.caption)
                            .foregroundStyle(AppColors.muted)
                            .lineLimit(2)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text(formatWon(entry.amount))
                        .font(.headline)
                        .foregroundStyle(AppColors.gold)
                    Text("성인 \(entry.mealTicketCount)매 · 소인 \(entry.childMealTicketCount)매")
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                    Text(ledgerClockText(entry.createdAt))
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                        .help(entry.createdAt)
                }
            }
            if allowsManagement {
                EntryManagementActions(entry: entry, compact: true)
            }
        }
        .padding(16)
    }
}

struct EntryManagementActions: View {
    @EnvironmentObject private var state: AppState
    @State private var confirmsDelete = false
    let entry: LedgerEntry
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 8 : 6) {
            Button(entry.status == .active ? "취소" : "복구") {
                if entry.status == .active {
                    state.voidEntry(entry)
                } else {
                    state.restoreEntry(entry)
                }
            }
            .buttonStyle(.borderless)

            Button("삭제", role: .destructive) {
                confirmsDelete = true
            }
            .buttonStyle(.borderless)
        }
        .font(.system(size: compact ? 13 : 12, weight: .semibold))
        .frame(maxWidth: compact ? .infinity : nil, alignment: compact ? .trailing : .center)
        .confirmationDialog("기록을 삭제할까요?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                state.deleteEntry(entry)
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("\(entry.sequenceLabel) \(entry.name) 기록은 검색과 정산에서 제거됩니다. 삭제 이력은 수정이력에 남습니다.")
        }
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
        case .light: "라이트"
        case .dark: "다크"
        }
    }
}
