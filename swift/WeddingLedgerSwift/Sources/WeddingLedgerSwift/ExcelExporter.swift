import Foundation

func xmlEscape(_ value: Any) -> String {
    String(describing: value)
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
}

func excelCell(_ value: Any, style: String? = nil, formula: String? = nil) -> String {
    var attrs = ""
    if let style { attrs += " ss:StyleID=\"\(style)\"" }
    if let formula { attrs += " ss:Formula=\"\(xmlEscape(formula))\"" }
    if let value = value as? Int {
        return "<Cell\(attrs)><Data ss:Type=\"Number\">\(value)</Data></Cell>"
    }
    return "<Cell\(attrs)><Data ss:Type=\"String\">\(xmlEscape(value))</Data></Cell>"
}

func excelRow(_ values: [Any], style: String? = nil) -> String {
    "<Row>" + values.map { excelCell($0, style: style) }.joined() + "</Row>"
}

func workbookXML(entries: [LedgerEntry], summary: LedgerSummary, auditRows: [[String: String]]) -> String {
    let lastRow = max(entries.count + 1, 2)
    let detailHeaders = ["봉투번호", "이름", "모임", "관계", "금액", "식권수", "입금방식", "상태", "모드", "입력시간", "수정시간", "메모"]
    let detailRows = [excelRow(detailHeaders, style: "Header")] + entries.map {
        excelRow([
            $0.envelopeNo,
            $0.name,
            $0.groupName,
            $0.relationship,
            $0.amount,
            $0.mealTicketCount,
            $0.paymentMethod.label,
            $0.status.label,
            $0.mode.label,
            $0.createdAt,
            $0.updatedAt,
            $0.memo
        ])
    }
    let summaryRows = [
        excelRow(["항목", "값"], style: "Header"),
        "<Row>" + excelCell("정상 기록 수") + excelCell(summary.activeCount, formula: "=COUNTIF(전체내역!R2C8:R\(lastRow)C8,\"정상\")") + "</Row>",
        "<Row>" + excelCell("취소 기록 수") + excelCell(summary.voidCount, formula: "=COUNTIF(전체내역!R2C8:R\(lastRow)C8,\"취소\")") + "</Row>",
        "<Row>" + excelCell("총 축의금") + excelCell(summary.totalAmount, style: "Money", formula: "=SUMIF(전체내역!R2C8:R\(lastRow)C8,\"정상\",전체내역!R2C5:R\(lastRow)C5)") + "</Row>",
        "<Row>" + excelCell("총 식권 수") + excelCell(summary.totalTickets, formula: "=SUMIF(전체내역!R2C8:R\(lastRow)C8,\"정상\",전체내역!R2C6:R\(lastRow)C6)") + "</Row>",
        "<Row>" + excelCell("현금 합계") + excelCell(summary.paymentTotals[.cash] ?? 0, style: "Money", formula: "=SUMIFS(전체내역!R2C5:R\(lastRow)C5,전체내역!R2C7:R\(lastRow)C7,\"현금\",전체내역!R2C8:R\(lastRow)C8,\"정상\")") + "</Row>",
        "<Row>" + excelCell("계좌 합계") + excelCell(summary.paymentTotals[.transfer] ?? 0, style: "Money", formula: "=SUMIFS(전체내역!R2C5:R\(lastRow)C5,전체내역!R2C7:R\(lastRow)C7,\"계좌\",전체내역!R2C8:R\(lastRow)C8,\"정상\")") + "</Row>",
        "<Row>" + excelCell("기타 합계") + excelCell(summary.paymentTotals[.other] ?? 0, style: "Money", formula: "=SUMIFS(전체내역!R2C5:R\(lastRow)C5,전체내역!R2C7:R\(lastRow)C7,\"기타\",전체내역!R2C8:R\(lastRow)C8,\"정상\")") + "</Row>"
    ]
    let groupRows = [excelRow(["모임", "건수", "총액", "식권 수"], style: "Header")] + summary.groupTotals.map {
        excelRow([$0.groupName, $0.count, $0.totalAmount, $0.totalTickets])
    }
    let searchRows = [
        excelRow(["검색 조건", "입력값", "결과"], style: "Header"),
        excelRow(["사용법", "B열에 조건을 입력하면 C열 수식이 계산됩니다.", ""]),
        "<Row>" + excelCell("이름") + excelCell("") + excelCell(0, formula: "=COUNTIF(전체내역!R2C2:R\(lastRow)C2,R3C2)") + "</Row>",
        "<Row>" + excelCell("모임") + excelCell("") + excelCell(0, style: "Money", formula: "=SUMIF(전체내역!R2C3:R\(lastRow)C3,R4C2,전체내역!R2C5:R\(lastRow)C5)") + "</Row>",
        "<Row>" + excelCell("최소 금액") + excelCell(0) + excelCell("") + "</Row>",
        "<Row>" + excelCell("최대 금액") + excelCell(1000000) + excelCell(summary.totalAmount, style: "Money", formula: "=SUMIFS(전체내역!R2C5:R\(lastRow)C5,전체내역!R2C5:R\(lastRow)C5,\">=\"&R5C2,전체내역!R2C5:R\(lastRow)C5,\"<=\"&R6C2,전체내역!R2C8:R\(lastRow)C8,\"정상\")") + "</Row>",
        "<Row>" + excelCell("모임별 식권 수") + excelCell("") + excelCell(0, formula: "=SUMIF(전체내역!R2C3:R\(lastRow)C3,R7C2,전체내역!R2C6:R\(lastRow)C6)") + "</Row>"
    ]
    let auditSheetRows = [excelRow(["시간", "봉투번호", "이름", "동작", "사유", "변경 전", "변경 후"], style: "Header")] + auditRows.map {
        excelRow([$0["created_at"] ?? "", $0["envelope_no"] ?? "", $0["name"] ?? "", $0["action"] ?? "", $0["reason"] ?? "", $0["before_json"] ?? "", $0["after_json"] ?? ""])
    }
    return """
    <?xml version="1.0"?>
    <?mso-application progid="Excel.Sheet"?>
    <Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
     xmlns:o="urn:schemas-microsoft-com:office:office"
     xmlns:x="urn:schemas-microsoft-com:office:excel"
     xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet">
      <Styles>
        <Style ss:ID="Default" ss:Name="Normal"><Alignment ss:Vertical="Center"/><Font ss:FontName="Apple SD Gothic Neo" ss:Size="11"/></Style>
        <Style ss:ID="Header"><Font ss:FontName="Apple SD Gothic Neo" ss:Bold="1" ss:Color="#FFFFFF"/><Interior ss:Color="#315E4D" ss:Pattern="Solid"/></Style>
        <Style ss:ID="Money"><NumberFormat ss:Format="₩#,##0"/></Style>
      </Styles>
      <Names>
        <NamedRange ss:Name="전체내역_이름" ss:RefersTo="=전체내역!R2C2:R\(lastRow)C2"/>
        <NamedRange ss:Name="전체내역_모임" ss:RefersTo="=전체내역!R2C3:R\(lastRow)C3"/>
        <NamedRange ss:Name="전체내역_금액" ss:RefersTo="=전체내역!R2C5:R\(lastRow)C5"/>
        <NamedRange ss:Name="전체내역_식권" ss:RefersTo="=전체내역!R2C6:R\(lastRow)C6"/>
      </Names>
      <Worksheet ss:Name="전체내역"><Table>\(detailRows.joined())</Table></Worksheet>
      <Worksheet ss:Name="요약"><Table>\(summaryRows.joined())</Table></Worksheet>
      <Worksheet ss:Name="모임별"><Table>\(groupRows.joined())</Table></Worksheet>
      <Worksheet ss:Name="검색용"><Table>\(searchRows.joined())</Table></Worksheet>
      <Worksheet ss:Name="수정이력"><Table>\(auditSheetRows.joined())</Table></Worksheet>
    </Workbook>
    """
}

@discardableResult
func exportXLSFile(to url: URL, entries: [LedgerEntry], summary: LedgerSummary, auditRows: [[String: String]]) throws -> URL {
    let output = url.pathExtension.lowercased() == "xls" ? url : url.deletingPathExtension().appendingPathExtension("xls")
    try workbookXML(entries: entries, summary: summary, auditRows: auditRows).write(to: output, atomically: true, encoding: .utf8)
    return output
}
