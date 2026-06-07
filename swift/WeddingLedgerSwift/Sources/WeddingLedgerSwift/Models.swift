import Foundation

struct LedgerEntry: Identifiable, Equatable {
    let id: String
    var mode: LedgerMode
    var envelopeNo: Int
    var name: String
    var groupName: String
    var relationship: String
    var amount: Int
    var mealTicketCount: Int
    var paymentMethod: PaymentMethod
    var memo: String
    var status: EntryStatus
    var createdAt: String
    var updatedAt: String
}

struct GroupTotal: Identifiable, Equatable {
    var id: String { groupName }
    let groupName: String
    let count: Int
    let totalAmount: Int
    let totalTickets: Int
}

struct DuplicateName: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let count: Int
}

struct LedgerSummary: Equatable {
    var mode: LedgerMode
    var activeCount: Int
    var voidCount: Int
    var totalAmount: Int
    var totalTickets: Int
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
        paymentTotals: [.cash: 0, .transfer: 0, .other: 0],
        groupTotals: [],
        duplicateNames: [],
        envelopeGaps: []
    )
}

struct EntryDraft {
    var envelopeNo: Int
    var name = ""
    var groupName = defaultGroup
    var relationship = ""
    var amountText = ""
    var mealTicketCount = 0
    var paymentMethod: PaymentMethod = .cash
    var memo = ""

    var amount: Int { parseAmount(amountText) }
}

struct EntryFilters {
    var name = ""
    var groupName = ""
    var minAmount = ""
    var maxAmount = ""
    var ticketCount = ""
    var paymentMethod: PaymentMethod?
    var status: EntryStatus?
}
