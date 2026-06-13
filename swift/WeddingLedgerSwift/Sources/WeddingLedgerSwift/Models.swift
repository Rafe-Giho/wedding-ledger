import Foundation

struct LedgerEntry: Identifiable, Equatable {
    let id: String
    var mode: LedgerMode
    var envelopeNo: Int
    var name: String
    var groupName: String
    var relationship: String
    var targetPerson: String
    var amount: Int
    var mealTicketCount: Int
    var childMealTicketCount: Int
    var transferNo: Int
    var paymentMethod: PaymentMethod
    var memo: String
    var status: EntryStatus
    var createdAt: String
    var updatedAt: String

    var sequenceLabel: String {
        if paymentMethod == .transfer {
            return "계좌 #\(transferNo > 0 ? transferNo : envelopeNo)"
        }
        return "봉투 #\(envelopeNo)"
    }

    var shortSequenceLabel: String {
        if paymentMethod == .transfer {
            return "계좌 \(transferNo > 0 ? transferNo : envelopeNo)"
        }
        return "#\(envelopeNo)"
    }

    var totalMealTicketCount: Int {
        mealTicketCount + childMealTicketCount
    }
}

struct GroupTotal: Identifiable, Equatable {
    var id: String { groupName }
    let groupName: String
    let count: Int
    let totalAmount: Int
    let totalTickets: Int
    let totalChildTickets: Int
}

struct DuplicateName: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let count: Int
}

enum ClosingCheckKey: String, CaseIterable, Identifiable {
    case envelope
    case cash
    case transfer
    case ticket
    case issues
    case export

    var id: String { rawValue }
}

struct OperationSettings: Equatable {
    var eventTitle = ""
    var totalMealTickets = 0
    var totalChildMealTickets = 0
    var expectedEnvelopeCount = 0
    var operationNote = ""

    static let empty = OperationSettings()
}

struct LedgerSummary: Equatable {
    var mode: LedgerMode
    var activeCount: Int
    var voidCount: Int
    var totalAmount: Int
    var totalTickets: Int
    var totalChildTickets: Int
    var paymentTotals: [PaymentMethod: Int]
    var groupTotals: [GroupTotal]
    var duplicateNames: [DuplicateName]
    var envelopeGaps: [Int]

    static let empty = LedgerSummary(
        mode: .test,
        activeCount: 0,
        voidCount: 0,
        totalAmount: 0,
        totalTickets: 0,
        totalChildTickets: 0,
        paymentTotals: [.cash: 0, .transfer: 0, .other: 0],
        groupTotals: [],
        duplicateNames: [],
        envelopeGaps: []
    )
}

struct EntryDraft {
    var envelopeNo: Int
    var transferNo = 1
    var name = ""
    var groupName = defaultGroup
    var relationship = ""
    var targetPerson = ""
    var amountText = ""
    var mealTicketCount = 0
    var childMealTicketCount = 0
    var paymentMethod: PaymentMethod = .cash
    var createdAtText = ""
    var memo = ""

    var amount: Int { parseAmount(amountText) }
}

struct EntryFilters: Equatable {
    var name = ""
    var exactName = false
    var groupName = ""
    var relationship = ""
    var targetPerson = ""
    var minAmount = ""
    var maxAmount = ""
    var ticketCount = ""
    var childTicketCount = ""
    var paymentMethod: PaymentMethod?
    var status: EntryStatus?
}
