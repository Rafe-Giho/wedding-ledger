import Foundation

private struct XLSXCell {
    var text: String?
    var number: Double?
    var formula: String?
    var style: Int

    static func text(_ value: String, style: Int = 0) -> XLSXCell {
        XLSXCell(text: value, number: nil, formula: nil, style: style)
    }

    static func number(_ value: Int, style: Int = 0) -> XLSXCell {
        XLSXCell(text: nil, number: Double(value), formula: nil, style: style)
    }

    static func formula(_ formula: String, style: Int = 0) -> XLSXCell {
        XLSXCell(text: nil, number: nil, formula: formula, style: style)
    }

    static func blank(style: Int = 0) -> XLSXCell {
        XLSXCell(text: "", number: nil, formula: nil, style: style)
    }
}

private struct XLSXColumn {
    let index: Int
    let width: Double
    var hidden = false
}

private let styleNormal = 0
private let styleHeader = 1
private let styleMoney = 2
private let styleTitle = 3
private let styleMuted = 4
private let styleDateTime = 5
private let styleDate = 6

private func xmlEscape(_ value: Any) -> String {
    String(describing: value)
        .replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private func columnName(_ index: Int) -> String {
    var value = index
    var result = ""
    while value > 0 {
        let remainder = (value - 1) % 26
        result = String(UnicodeScalar(65 + remainder)!) + result
        value = (value - 1) / 26
    }
    return result
}

private func cellXML(_ cell: XLSXCell, row: Int, column: Int) -> String {
    let reference = "\(columnName(column))\(row)"
    let styleAttribute = cell.style == styleNormal ? "" : " s=\"\(cell.style)\""
    if let formula = cell.formula {
        return "<c r=\"\(reference)\"\(styleAttribute)><f>\(xmlEscape(formula))</f></c>"
    }
    if let number = cell.number {
        let value = number.rounded() == number ? String(Int(number)) : String(number)
        return "<c r=\"\(reference)\"\(styleAttribute)><v>\(value)</v></c>"
    }
    return "<c r=\"\(reference)\"\(styleAttribute) t=\"inlineStr\"><is><t>\(xmlEscape(cell.text ?? ""))</t></is></c>"
}

private func worksheetXML(
    rows: [[XLSXCell]],
    columns: [XLSXColumn],
    frozenRows: Int = 1,
    autoFilter: String? = nil,
    dataValidations: String = "",
    conditionalFormatting: String = ""
) -> String {
    let maxColumnCount = max(rows.map(\.count).max() ?? 1, columns.map(\.index).max() ?? 1)
    let dimension = "A1:\(columnName(maxColumnCount))\(max(rows.count, 1))"
    let columnXML = columns.map {
        "<col min=\"\($0.index)\" max=\"\($0.index)\" width=\"\($0.width)\" customWidth=\"1\"\($0.hidden ? " hidden=\"1\"" : "")/>"
    }.joined()
    let sheetRows = rows.enumerated().map { rowOffset, cells in
        let rowNumber = rowOffset + 1
        let cellsXML = cells.enumerated().map { columnOffset, cell in
            cellXML(cell, row: rowNumber, column: columnOffset + 1)
        }.joined()
        return "<row r=\"\(rowNumber)\">\(cellsXML)</row>"
    }.joined()
    let paneXML = frozenRows > 0
        ? "<sheetViews><sheetView workbookViewId=\"0\"><pane ySplit=\"\(frozenRows)\" topLeftCell=\"A\(frozenRows + 1)\" activePane=\"bottomLeft\" state=\"frozen\"/></sheetView></sheetViews>"
        : "<sheetViews><sheetView workbookViewId=\"0\"/></sheetViews>"
    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <dimension ref="\(dimension)"/>
      \(paneXML)
      <cols>\(columnXML)</cols>
      <sheetData>\(sheetRows)</sheetData>
      \(autoFilter.map { "<autoFilter ref=\"\($0)\"/>" } ?? "")
      \(dataValidations)
      \(conditionalFormatting)
    </worksheet>
    """
}

private func workbookXML(sheetNames: [String], definedNames: String) -> String {
    let sheets = sheetNames.enumerated().map { index, name in
        "<sheet name=\"\(xmlEscape(name))\" sheetId=\"\(index + 1)\" r:id=\"rId\(index + 1)\"/>"
    }.joined()
    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <workbookPr date1904="false"/>
      <sheets>\(sheets)</sheets>
      <definedNames>\(definedNames)</definedNames>
      <calcPr calcId="191029" fullCalcOnLoad="1" forceFullCalc="1"/>
    </workbook>
    """
}

private func workbookRelsXML(sheetCount: Int) -> String {
    let sheetRels = (1...sheetCount).map {
        "<Relationship Id=\"rId\($0)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet\" Target=\"worksheets/sheet\($0).xml\"/>"
    }.joined()
    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      \(sheetRels)
      <Relationship Id="rId\(sheetCount + 1)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
    </Relationships>
    """
}

private func rootRelsXML() -> String {
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
    </Relationships>
    """
}

private func contentTypesXML(sheetCount: Int) -> String {
    let sheetOverrides = (1...sheetCount).map {
        "<Override PartName=\"/xl/worksheets/sheet\($0).xml\" ContentType=\"application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml\"/>"
    }.joined()
    return """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
      <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
      <Default Extension="xml" ContentType="application/xml"/>
      <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
      <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
      \(sheetOverrides)
    </Types>
    """
}

private func stylesXML() -> String {
    """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
      <numFmts count="3">
        <numFmt numFmtId="164" formatCode="₩#,##0"/>
        <numFmt numFmtId="165" formatCode="yyyy-mm-dd hh:mm:ss"/>
        <numFmt numFmtId="166" formatCode="yyyy-mm-dd"/>
      </numFmts>
      <fonts count="4">
        <font><sz val="11"/><name val="Apple SD Gothic Neo"/></font>
        <font><b/><sz val="11"/><color rgb="FFFFFFFF"/><name val="Apple SD Gothic Neo"/></font>
        <font><b/><sz val="14"/><color rgb="FF2B2118"/><name val="Apple SD Gothic Neo"/></font>
        <font><sz val="10"/><color rgb="FF786F65"/><name val="Apple SD Gothic Neo"/></font>
      </fonts>
      <fills count="4">
        <fill><patternFill patternType="none"/></fill>
        <fill><patternFill patternType="gray125"/></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FF2B2118"/><bgColor indexed="64"/></patternFill></fill>
        <fill><patternFill patternType="solid"><fgColor rgb="FFF4EFE7"/><bgColor indexed="64"/></patternFill></fill>
      </fills>
      <borders count="2">
        <border><left/><right/><top/><bottom/><diagonal/></border>
        <border><left style="thin"><color rgb="FFD8CFC2"/></left><right style="thin"><color rgb="FFD8CFC2"/></right><top style="thin"><color rgb="FFD8CFC2"/></top><bottom style="thin"><color rgb="FFD8CFC2"/></bottom><diagonal/></border>
      </borders>
      <cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
      <cellXfs count="7">
        <xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0"/>
        <xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
        <xf numFmtId="164" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>
        <xf numFmtId="0" fontId="2" fillId="3" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1"/>
        <xf numFmtId="0" fontId="3" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>
        <xf numFmtId="165" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>
        <xf numFmtId="166" fontId="0" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyBorder="1"/>
      </cellXfs>
      <dxfs count="1">
        <dxf><font><color rgb="FF8A8177"/></font><fill><patternFill patternType="solid"><fgColor rgb="FFF1ECE5"/><bgColor indexed="64"/></patternFill></fill></dxf>
      </dxfs>
      <cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
    </styleSheet>
    """
}

private func detailRows(entries: [LedgerEntry]) -> [[XLSXCell]] {
    let headers = ["봉투번호", "이름", "모임", "관계", "금액", "식권수", "입금방식", "상태", "모드", "입력시간", "입력일시값", "수정시간", "입력일", "메모"]
    var rows = [headers.map { XLSXCell.text($0, style: styleHeader) }]
    for (index, entry) in entries.enumerated() {
        let row = index + 2
        rows.append([
            .number(entry.envelopeNo),
            .text(entry.name),
            .text(entry.groupName),
            .text(entry.relationship),
            .number(entry.amount, style: styleMoney),
            .number(entry.mealTicketCount),
            .text(entry.paymentMethod.label),
            .text(entry.status.label),
            .text(entry.mode.label),
            .text(entry.createdAt),
            .formula("IF(J\(row)=\"\",\"\",DATEVALUE(LEFT(J\(row),10))+TIMEVALUE(RIGHT(J\(row),8)))", style: styleDateTime),
            .text(entry.updatedAt),
            .formula("IF(J\(row)=\"\",\"\",DATEVALUE(LEFT(J\(row),10)))", style: styleDate),
            .text(entry.memo)
        ])
    }
    return rows
}

private func summaryRows(lastRow: Int, settings: OperationSettings) -> [[XLSXCell]] {
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    let paymentRange = "'전체내역'!$G$2:$G$\(lastRow)"
    let serialRange = "'전체내역'!$K$2:$K$\(lastRow)"
    return [
        [.text("요약 지표", style: styleTitle), .text("값", style: styleTitle), .text("설명", style: styleTitle)],
        [.text("정상 기록 수"), .formula("COUNTIF(\(statusRange),\"정상\")"), .text("취소 제외")],
        [.text("취소 기록 수"), .formula("COUNTIF(\(statusRange),\"취소\")"), .text("취소 처리된 기록")],
        [.text("총 봉투수"), .formula("COUNTIF(\(statusRange),\"정상\")"), .text("정상 기록 기준")],
        [.text("예상 봉투수"), .number(settings.expectedEnvelopeCount), .text("설정값")],
        [.text("봉투 차이"), .formula("IF(B5=0,\"\",B5-B4)"), .text("예상 봉투수 - 정상 기록 수")],
        [.text("총 축의금"), .formula("SUMIF(\(statusRange),\"정상\",\(amountRange))", style: styleMoney), .text("정상 기록 금액 합계")],
        [.text("평균 축의금"), .formula("IFERROR(AVERAGEIFS(\(amountRange),\(statusRange),\"정상\"),0)", style: styleMoney), .text("정상 기록 평균")],
        [.text("총 식권 수"), .formula("SUMIF(\(statusRange),\"정상\",\(ticketRange))"), .text("정상 기록 식권 합계")],
        [.text("준비 식권 수"), .number(settings.totalMealTickets), .text("설정값")],
        [.text("남은 식권 수"), .formula("IF(B10=0,\"\",B10-B9)"), .text("준비 식권 수 - 사용 식권 수")],
        [.text("현금 합계"), .formula("SUMIFS(\(amountRange),\(paymentRange),\"현금\",\(statusRange),\"정상\")", style: styleMoney), .text("")],
        [.text("계좌 합계"), .formula("SUMIFS(\(amountRange),\(paymentRange),\"계좌\",\(statusRange),\"정상\")", style: styleMoney), .text("")],
        [.text("기타 합계"), .formula("SUMIFS(\(amountRange),\(paymentRange),\"기타\",\(statusRange),\"정상\")", style: styleMoney), .text("")],
        [.text("최초 입력시간"), .formula("IFERROR(TEXT(MINIFS(\(serialRange),\(statusRange),\"정상\"),\"yyyy-mm-dd hh:mm:ss\"),\"\")"), .text("초 단위")],
        [.text("최근 입력시간"), .formula("IFERROR(TEXT(MAXIFS(\(serialRange),\(statusRange),\"정상\"),\"yyyy-mm-dd hh:mm:ss\"),\"\")"), .text("초 단위")]
    ]
}

private func searchRows(lastRow: Int) -> [[XLSXCell]] {
    let detailRange = "'전체내역'!$A$2:$N$\(lastRow)"
    let envelopeRange = "'전체내역'!$A$2:$A$\(lastRow)"
    let nameRange = "'전체내역'!$B$2:$B$\(lastRow)"
    let groupRange = "'전체내역'!$C$2:$C$\(lastRow)"
    let relationshipRange = "'전체내역'!$D$2:$D$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    let paymentRange = "'전체내역'!$G$2:$G$\(lastRow)"
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let serialRange = "'전체내역'!$K$2:$K$\(lastRow)"
    let criteria = [
        "\(envelopeRange)<>\"\"",
        "(($B$3=\"\")+ISNUMBER(SEARCH($B$3,\(nameRange))))>0",
        "(($B$4=\"\")+ISNUMBER(SEARCH($B$4,\(groupRange))))>0",
        "(($B$5=\"\")+ISNUMBER(SEARCH($B$5,\(relationshipRange))))>0",
        "(($B$6=\"\")+(\(paymentRange)=$B$6))>0",
        "(($B$7=\"\")+(\(statusRange)=$B$7))>0",
        "\(amountRange)>=IF($B$8=\"\",0,VALUE(SUBSTITUTE($B$8,\",\",\"\")))",
        "\(amountRange)<=IF($B$9=\"\",999999999,VALUE(SUBSTITUTE($B$9,\",\",\"\")))",
        "(($B$10=\"\")+(\(ticketRange)=IFERROR(VALUE(SUBSTITUTE($B$10,\",\",\"\")),-1)))>0",
        "\(serialRange)>=IF($B$11=\"\",0,DATEVALUE(LEFT($B$11,10))+TIMEVALUE(RIGHT($B$11,8)))",
        "\(serialRange)<=IF($B$12=\"\",999999,DATEVALUE(LEFT($B$12,10))+TIMEVALUE(RIGHT($B$12,8)))"
    ]
    let filterCriteria = criteria.map { "--(\($0))" }.joined(separator: "*")
    let sumProductCriteria = criteria.map { "--(\($0))" }.joined(separator: ",")
    let filterFormula = "IFERROR(FILTER(\(detailRange),\(filterCriteria)>0),\"조건에 맞는 기록 없음\")"
    return [
        [.text("검색 조건", style: styleTitle), .text("입력값", style: styleTitle), .text("설명", style: styleTitle), .blank(), .text("검색 요약", style: styleTitle), .text("값", style: styleTitle)],
        [.text("사용법"), .text("B열에 조건 입력"), .text("조건을 비우면 전체 포함. 결과는 16행부터 표시됩니다."), .blank(), .text("결과 건수"), .formula("SUMPRODUCT(\(sumProductCriteria))")],
        [.text("이름 포함"), .blank(), .text("예: 김민수"), .blank(), .text("결과 총액"), .formula("SUMPRODUCT(\(sumProductCriteria),\(amountRange))", style: styleMoney)],
        [.text("모임 포함"), .blank(), .text("예: 회사"), .blank(), .text("결과 식권"), .formula("SUMPRODUCT(\(sumProductCriteria),\(ticketRange))")],
        [.text("관계 포함"), .blank(), .text("예: 친구"), .blank(), .blank(), .blank()],
        [.text("입금방식"), .blank(), .text("현금/계좌/기타"), .blank(), .blank(), .blank()],
        [.text("상태"), .text("정상"), .text("정상/취소"), .blank(), .blank(), .blank()],
        [.text("최소 금액"), .blank(), .text("숫자만 입력"), .blank(), .blank(), .blank()],
        [.text("최대 금액"), .blank(), .text("숫자만 입력"), .blank(), .blank(), .blank()],
        [.text("식권수"), .blank(), .text("정확히 일치"), .blank(), .blank(), .blank()],
        [.text("시작 입력시간"), .blank(), .text("yyyy-mm-dd hh:mm:ss"), .blank(), .blank(), .blank()],
        [.text("종료 입력시간"), .blank(), .text("yyyy-mm-dd hh:mm:ss"), .blank(), .blank(), .blank()],
        [.text("주의"), .text("입금방식/상태는 드롭다운 권장"), .text("금액과 식권수는 쉼표 없이 숫자만 입력하면 가장 안전합니다."), .blank(), .blank(), .blank()],
        [.text("검색 결과", style: styleTitle), .blank(), .blank(), .blank(), .blank(), .blank()],
        ["봉투번호", "이름", "모임", "관계", "금액", "식권수", "입금방식", "상태", "모드", "입력시간", "입력일시값", "수정시간", "입력일", "메모"].map { .text($0, style: styleHeader) },
        [.formula(filterFormula)]
    ]
}

private func envelopeReviewRows(entries: [LedgerEntry], summary: LedgerSummary, auditRows: [[String: String]]) -> [[XLSXCell]] {
    let canceled = entries.filter { $0.status == .void }.sorted { $0.envelopeNo < $1.envelopeNo }
    let deleted = auditRows.filter { $0["action"] == "delete" }
    let duplicateEnvelopeNumbers = Dictionary(grouping: entries, by: \.envelopeNo)
        .filter { $0.value.count > 1 }
        .keys
        .sorted()
    var rows: [[XLSXCell]] = [
        [.text("봉투 검수 요약", style: styleTitle), .text("값", style: styleTitle), .text("설명", style: styleTitle)],
        [.text("정상 봉투수"), .number(summary.activeCount), .text("현재 정산에 포함되는 봉투")],
        [.text("취소 봉투수"), .number(summary.voidCount), .text("취소 처리되어 정산에서 제외")],
        [.text("삭제 이력 수"), .number(deleted.count), .text("검색에서 확인 후 삭제한 기록")],
        [.text("누락 봉투번호"), .text(summary.envelopeGaps.isEmpty ? "없음" : summary.envelopeGaps.map(String.init).joined(separator: ", ")), .text("현재 남아 있는 기록 기준")],
        [.text("중복 봉투번호"), .text(duplicateEnvelopeNumbers.isEmpty ? "없음" : duplicateEnvelopeNumbers.map(String.init).joined(separator: ", ")), .text("동일 모드 내 중복 여부")],
        [.blank(), .blank(), .blank()],
        [.text("취소 기록", style: styleTitle), .blank(), .blank()],
        [.text("봉투번호", style: styleHeader), .text("이름", style: styleHeader), .text("금액", style: styleHeader), .text("식권수", style: styleHeader), .text("입력시간", style: styleHeader), .text("메모", style: styleHeader)]
    ]
    if canceled.isEmpty {
        rows.append([.text("없음"), .blank(), .blank(), .blank(), .blank(), .blank()])
    } else {
        for entry in canceled {
            rows.append([.number(entry.envelopeNo), .text(entry.name), .number(entry.amount, style: styleMoney), .number(entry.mealTicketCount), .text(entry.createdAt), .text(entry.memo)])
        }
    }
    rows += [
        [.blank(), .blank(), .blank()],
        [.text("삭제 이력", style: styleTitle), .blank(), .blank()],
        [.text("삭제시간", style: styleHeader), .text("봉투번호", style: styleHeader), .text("이름", style: styleHeader), .text("사유", style: styleHeader), .text("삭제 전 값", style: styleHeader)]
    ]
    if deleted.isEmpty {
        rows.append([.text("없음"), .blank(), .blank(), .blank(), .blank()])
    } else {
        for audit in deleted {
            rows.append([.text(audit["created_at"] ?? ""), .text(audit["envelope_no"] ?? ""), .text(audit["name"] ?? ""), .text(audit["reason"] ?? ""), .text(audit["before_json"] ?? "")])
        }
    }
    return rows
}

private func paymentReviewRows(lastRow: Int) -> [[XLSXCell]] {
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let paymentRange = "'전체내역'!$G$2:$G$\(lastRow)"
    return [
        [.text("현금·계좌 정산", style: styleTitle), .blank(), .blank(), .blank()],
        [.text("입금방식", style: styleHeader), .text("정상 건수", style: styleHeader), .text("정상 합계", style: styleHeader), .text("취소 건수", style: styleHeader), .text("검수 메모", style: styleHeader)],
        [.text("현금"), .formula("COUNTIFS(\(paymentRange),A3,\(statusRange),\"정상\")"), .formula("SUMIFS(\(amountRange),\(paymentRange),A3,\(statusRange),\"정상\")", style: styleMoney), .formula("COUNTIFS(\(paymentRange),A3,\(statusRange),\"취소\")"), .blank()],
        [.text("계좌"), .formula("COUNTIFS(\(paymentRange),A4,\(statusRange),\"정상\")"), .formula("SUMIFS(\(amountRange),\(paymentRange),A4,\(statusRange),\"정상\")", style: styleMoney), .formula("COUNTIFS(\(paymentRange),A4,\(statusRange),\"취소\")"), .blank()],
        [.text("기타"), .formula("COUNTIFS(\(paymentRange),A5,\(statusRange),\"정상\")"), .formula("SUMIFS(\(amountRange),\(paymentRange),A5,\(statusRange),\"정상\")", style: styleMoney), .formula("COUNTIFS(\(paymentRange),A5,\(statusRange),\"취소\")"), .blank()],
        [.text("총액"), .formula("SUM(B3:B5)"), .formula("SUM(C3:C5)", style: styleMoney), .formula("SUM(D3:D5)"), .blank()],
        [.blank(), .blank(), .blank(), .blank(), .blank()],
        [.text("현금 실물 검수", style: styleTitle), .blank(), .blank(), .blank(), .blank()],
        [.text("앱 현금 합계"), .formula("C3", style: styleMoney), .text("전체내역 기준")],
        [.text("실제 현금 입력"), .blank(style: styleMoney), .text("마감 때 직접 입력")],
        [.text("차이"), .formula("IF(B10=\"\",\"\",B10-B9)", style: styleMoney), .text("실제 현금 - 앱 현금 합계")]
    ]
}

private func ticketReviewRows(entries: [LedgerEntry], lastRow: Int, settings: OperationSettings) -> [[XLSXCell]] {
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    let ticketEntries = entries.filter { $0.mealTicketCount > 0 }.sorted { $0.envelopeNo < $1.envelopeNo }
    var rows: [[XLSXCell]] = [
        [.text("식권 검수", style: styleTitle), .text("값", style: styleTitle), .text("설명", style: styleTitle)],
        [.text("준비 식권"), .number(settings.totalMealTickets), .text("앱 설정값")],
        [.text("배부 식권"), .formula("SUMIF(\(statusRange),\"정상\",\(ticketRange))"), .text("정상 기록 기준")],
        [.text("남은 식권"), .formula("IF(B2=0,\"\",B2-B3)"), .text("준비 식권 - 배부 식권")],
        [.text("취소 기록 식권"), .formula("SUMIF(\(statusRange),\"취소\",\(ticketRange))"), .text("취소되어 정산 제외")],
        [.blank(), .blank(), .blank()],
        [.text("식권 배부 기록", style: styleTitle), .blank(), .blank()],
        [.text("봉투번호", style: styleHeader), .text("이름", style: styleHeader), .text("식권수", style: styleHeader), .text("상태", style: styleHeader), .text("입금방식", style: styleHeader), .text("입력시간", style: styleHeader)]
    ]
    if ticketEntries.isEmpty {
        rows.append([.text("없음"), .blank(), .blank(), .blank(), .blank(), .blank()])
    } else {
        for entry in ticketEntries {
            rows.append([.number(entry.envelopeNo), .text(entry.name), .number(entry.mealTicketCount), .text(entry.status.label), .text(entry.paymentMethod.label), .text(entry.createdAt)])
        }
    }
    return rows
}

private func duplicateReviewRows(entries: [LedgerEntry], summary: LedgerSummary) -> [[XLSXCell]] {
    let duplicateCounts = Dictionary(uniqueKeysWithValues: summary.duplicateNames.map { ($0.name, $0.count) })
    let duplicateEntries = entries
        .filter { $0.status == .active && duplicateCounts[$0.name] != nil }
        .sorted { $0.name == $1.name ? $0.envelopeNo < $1.envelopeNo : $0.name < $1.name }
    var rows: [[XLSXCell]] = [[.text("이름", style: styleHeader), .text("인원", style: styleHeader), .text("봉투번호", style: styleHeader), .text("모임", style: styleHeader), .text("관계", style: styleHeader), .text("금액", style: styleHeader), .text("식권수", style: styleHeader), .text("입금방식", style: styleHeader), .text("입력시간", style: styleHeader), .text("메모", style: styleHeader)]]
    if duplicateEntries.isEmpty {
        rows.append([.text("동명이인 없음"), .blank(), .blank(), .blank(), .blank(), .blank(), .blank(), .blank(), .blank(), .blank()])
        return rows
    }
    for entry in duplicateEntries {
        rows.append([.text(entry.name), .number(duplicateCounts[entry.name] ?? 0), .number(entry.envelopeNo), .text(entry.groupName), .text(entry.relationship), .number(entry.amount, style: styleMoney), .number(entry.mealTicketCount), .text(entry.paymentMethod.label), .text(entry.createdAt), .text(entry.memo)])
    }
    return rows
}

private func amountReviewRows(entries: [LedgerEntry], lastRow: Int) -> [[XLSXCell]] {
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let quickAmounts = Set(defaultQuickAmounts)
    let specialEntries = entries
        .filter { $0.status == .active && specialAmountReason($0.amount, quickAmounts: quickAmounts) != nil }
        .sorted { $0.amount == $1.amount ? $0.envelopeNo < $1.envelopeNo : $0.amount > $1.amount }
    let directInputCount = entries.filter { $0.status == .active && !quickAmounts.contains($0.amount) }.count
    let notTenThousandUnitCount = entries.filter { $0.status == .active && $0.amount % 10_000 != 0 }.count
    var rows: [[XLSXCell]] = [
        [.text("고액·특이금액 요약", style: styleTitle), .blank(), .blank(), .blank()],
        [.text("구분", style: styleHeader), .text("기준", style: styleHeader), .text("건수", style: styleHeader), .text("합계", style: styleHeader)],
        [.text("30만원 이상"), .text(">= 300,000"), .formula("COUNTIFS(\(amountRange),\">=300000\",\(statusRange),\"정상\")"), .formula("SUMIFS(\(amountRange),\(amountRange),\">=300000\",\(statusRange),\"정상\")", style: styleMoney)],
        [.text("50만원 이상"), .text(">= 500,000"), .formula("COUNTIFS(\(amountRange),\">=500000\",\(statusRange),\"정상\")"), .formula("SUMIFS(\(amountRange),\(amountRange),\">=500000\",\(statusRange),\"정상\")", style: styleMoney)],
        [.text("100만원 이상"), .text(">= 1,000,000"), .formula("COUNTIFS(\(amountRange),\">=1000000\",\(statusRange),\"정상\")"), .formula("SUMIFS(\(amountRange),\(amountRange),\">=1000000\",\(statusRange),\"정상\")", style: styleMoney)],
        [.text("빠른선택 외 금액"), .text("직접 입력 가능성"), .number(directInputCount), .blank()],
        [.text("만원 단위 아님"), .text("금액 확인 권장"), .number(notTenThousandUnitCount), .blank()],
        [.blank(), .blank(), .blank(), .blank()],
        [.text("상세 기록", style: styleTitle), .blank(), .blank(), .blank()],
        [.text("봉투번호", style: styleHeader), .text("이름", style: styleHeader), .text("금액", style: styleHeader), .text("확인 사유", style: styleHeader), .text("입금방식", style: styleHeader), .text("입력시간", style: styleHeader), .text("메모", style: styleHeader)]
    ]
    if specialEntries.isEmpty {
        rows.append([.text("없음"), .blank(), .blank(), .blank(), .blank(), .blank(), .blank()])
    } else {
        for entry in specialEntries {
            rows.append([.number(entry.envelopeNo), .text(entry.name), .number(entry.amount, style: styleMoney), .text(specialAmountReason(entry.amount, quickAmounts: quickAmounts) ?? ""), .text(entry.paymentMethod.label), .text(entry.createdAt), .text(entry.memo)])
        }
    }
    return rows
}

private func specialAmountReason(_ amount: Int, quickAmounts: Set<Int>) -> String? {
    var reasons: [String] = []
    if amount >= 1_000_000 {
        reasons.append("100만원 이상")
    } else if amount >= 500_000 {
        reasons.append("50만원 이상")
    } else if amount >= 300_000 {
        reasons.append("30만원 이상")
    }
    if !quickAmounts.contains(amount) {
        reasons.append("빠른선택 외")
    }
    if amount % 10_000 != 0 {
        reasons.append("만원 단위 아님")
    }
    return reasons.isEmpty ? nil : reasons.joined(separator: ", ")
}

private func auditActionLabel(_ action: String) -> String {
    switch action {
    case "create": "생성"
    case "void": "취소"
    case "restore": "복구"
    case "delete": "삭제"
    default: action
    }
}

private func correctionAuditRows(_ auditRows: [[String: String]]) -> [[XLSXCell]] {
    let headers = ["시간", "봉투번호", "이름", "동작", "사유", "변경 전", "변경 후"]
    var rows = [headers.map { XLSXCell.text($0, style: styleHeader) }]
    let trackedRows = auditRows.filter { ["void", "restore", "delete"].contains($0["action"] ?? "") }
    if trackedRows.isEmpty {
        rows.append([.text("없음"), .blank(), .blank(), .blank(), .blank(), .blank(), .blank()])
        return rows
    }
    rows += trackedRows.map {
        [
            .text($0["created_at"] ?? ""),
            .text($0["envelope_no"] ?? ""),
            .text($0["name"] ?? ""),
            .text(auditActionLabel($0["action"] ?? "")),
            .text($0["reason"] ?? ""),
            .text($0["before_json"] ?? ""),
            .text($0["after_json"] ?? "")
        ]
    }
    return rows
}

private func guideRows(mode: LedgerMode, exportDate: String, settings: OperationSettings) -> [[XLSXCell]] {
    [
        [.text("축의대 장부 엑셀 안내", style: styleTitle), .blank()],
        [.text("행사명"), .text(settings.eventTitle.isEmpty ? "-" : settings.eventTitle)],
        [.text("추출 모드"), .text(mode.label)],
        [.text("추출 시간"), .text(exportDate)],
        [.text("총 식권수"), .text(settings.totalMealTickets > 0 ? "\(settings.totalMealTickets)매" : "미설정")],
        [.text("예상 봉투수"), .text(settings.expectedEnvelopeCount > 0 ? "\(settings.expectedEnvelopeCount)개" : "미설정")],
        [.text("운영 메모"), .text(settings.operationNote.isEmpty ? "-" : settings.operationNote)],
        [.text("전체내역"), .text("원본 데이터입니다. 필터가 켜져 있고 입력시간은 초 단위까지 표시됩니다.")],
        [.text("요약"), .text("주요 수치는 전체내역을 참조하는 함수로 계산됩니다.")],
        [.text("검색용"), .text("B열 조건을 입력하면 16행부터 결과가 자동으로 채워집니다. Google Sheets와 Excel 365에서 열기 쉬운 FILTER/SUMPRODUCT 수식을 사용합니다.")],
        [.text("봉투 검수"), .text("봉투번호 누락, 중복, 취소 기록, 삭제 이력을 확인합니다.")],
        [.text("현금·계좌 정산"), .text("현금, 계좌, 기타 합계와 현금 실물 검수 차이를 확인합니다.")],
        [.text("식권 검수"), .text("배부 식권, 준비 식권, 남은 식권과 식권 배부 기록을 확인합니다.")],
        [.text("동명이인 점검"), .text("같은 이름의 정상 기록을 목록으로 확인합니다.")],
        [.text("고액·특이금액"), .text("30만/50만/100만 이상, 빠른선택 외 금액, 만원 단위가 아닌 금액을 확인합니다.")],
        [.text("취소·삭제 이력"), .text("취소, 복구, 삭제 등 잘못 입력한 기록의 정정 흐름을 추적합니다.")]
    ]
}

private func writeText(_ text: String, to url: URL) throws {
    guard let data = text.data(using: .utf8) else {
        throw LedgerError.invalid("엑셀 XML을 만들 수 없습니다.")
    }
    try data.write(to: url, options: .atomic)
}

private func createXLSXPackage(
    at packageURL: URL,
    entries: [LedgerEntry],
    summary: LedgerSummary,
    auditRows rawAuditRows: [[String: String]],
    mode: LedgerMode,
    settings: OperationSettings
) throws {
    let fileManager = FileManager.default
    let xlURL = packageURL.appendingPathComponent("xl", isDirectory: true)
    let worksheetsURL = xlURL.appendingPathComponent("worksheets", isDirectory: true)
    let relsURL = packageURL.appendingPathComponent("_rels", isDirectory: true)
    let xlRelsURL = xlURL.appendingPathComponent("_rels", isDirectory: true)
    try fileManager.createDirectory(at: worksheetsURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: relsURL, withIntermediateDirectories: true)
    try fileManager.createDirectory(at: xlRelsURL, withIntermediateDirectories: true)

    let lastRow = max(entries.count + 1, 2)
    let sheetNames = ["전체내역", "요약", "검색용", "봉투 검수", "현금·계좌 정산", "식권 검수", "동명이인 점검", "고액·특이금액", "취소·삭제 이력", "안내"]
    let definedNames = """
    <definedName name="전체내역_이름">'전체내역'!$B$2:$B$\(lastRow)</definedName>
    <definedName name="전체내역_모임">'전체내역'!$C$2:$C$\(lastRow)</definedName>
    <definedName name="전체내역_금액">'전체내역'!$E$2:$E$\(lastRow)</definedName>
    <definedName name="전체내역_식권">'전체내역'!$F$2:$F$\(lastRow)</definedName>
    <definedName name="전체내역_입력일시값">'전체내역'!$K$2:$K$\(lastRow)</definedName>
    """
    let detailConditionalFormatting = """
    <conditionalFormatting sqref="H2:H\(lastRow)">
      <cfRule type="cellIs" priority="1" operator="equal" dxfId="0"><formula>"취소"</formula></cfRule>
    </conditionalFormatting>
    """
    let searchValidations = """
    <dataValidations count="2">
      <dataValidation type="list" allowBlank="1" showErrorMessage="1" sqref="B6"><formula1>"현금,계좌,기타"</formula1></dataValidation>
      <dataValidation type="list" allowBlank="1" showErrorMessage="1" sqref="B7"><formula1>"정상,취소"</formula1></dataValidation>
    </dataValidations>
    """
    let sheets: [String] = [
        worksheetXML(
            rows: detailRows(entries: entries),
            columns: [
                .init(index: 1, width: 10), .init(index: 2, width: 14), .init(index: 3, width: 16), .init(index: 4, width: 16),
                .init(index: 5, width: 13), .init(index: 6, width: 10), .init(index: 7, width: 10), .init(index: 8, width: 10),
                .init(index: 9, width: 9), .init(index: 10, width: 21), .init(index: 11, width: 0, hidden: true), .init(index: 12, width: 21),
                .init(index: 13, width: 13), .init(index: 14, width: 28)
            ],
            autoFilter: "A1:N\(lastRow)",
            conditionalFormatting: detailConditionalFormatting
        ),
        worksheetXML(
            rows: summaryRows(lastRow: lastRow, settings: settings),
            columns: [.init(index: 1, width: 18), .init(index: 2, width: 20), .init(index: 3, width: 34)]
        ),
        worksheetXML(
            rows: searchRows(lastRow: lastRow),
            columns: (1...14).map { .init(index: $0, width: $0 == 11 ? 0 : ($0 == 14 ? 28 : 14), hidden: $0 == 11) },
            frozenRows: 15,
            dataValidations: searchValidations
        ),
        worksheetXML(
            rows: envelopeReviewRows(entries: entries, summary: summary, auditRows: rawAuditRows),
            columns: [.init(index: 1, width: 18), .init(index: 2, width: 18), .init(index: 3, width: 24), .init(index: 4, width: 14), .init(index: 5, width: 44), .init(index: 6, width: 28)]
        ),
        worksheetXML(
            rows: paymentReviewRows(lastRow: lastRow),
            columns: [.init(index: 1, width: 18), .init(index: 2, width: 14), .init(index: 3, width: 16), .init(index: 4, width: 14), .init(index: 5, width: 28)]
        ),
        worksheetXML(
            rows: ticketReviewRows(entries: entries, lastRow: lastRow, settings: settings),
            columns: [.init(index: 1, width: 16), .init(index: 2, width: 14), .init(index: 3, width: 18), .init(index: 4, width: 12), .init(index: 5, width: 12), .init(index: 6, width: 21)]
        ),
        worksheetXML(
            rows: duplicateReviewRows(entries: entries, summary: summary),
            columns: [.init(index: 1, width: 14), .init(index: 2, width: 10), .init(index: 3, width: 10), .init(index: 4, width: 16), .init(index: 5, width: 16), .init(index: 6, width: 14), .init(index: 7, width: 10), .init(index: 8, width: 10), .init(index: 9, width: 21), .init(index: 10, width: 28)],
            autoFilter: "A1:J\(max(entries.count + 1, 2))"
        ),
        worksheetXML(
            rows: amountReviewRows(entries: entries, lastRow: lastRow),
            columns: [.init(index: 1, width: 16), .init(index: 2, width: 16), .init(index: 3, width: 14), .init(index: 4, width: 18), .init(index: 5, width: 12), .init(index: 6, width: 21), .init(index: 7, width: 28)]
        ),
        worksheetXML(
            rows: correctionAuditRows(rawAuditRows),
            columns: [.init(index: 1, width: 21), .init(index: 2, width: 10), .init(index: 3, width: 14), .init(index: 4, width: 12), .init(index: 5, width: 18), .init(index: 6, width: 44), .init(index: 7, width: 44)],
            autoFilter: "A1:G\(max(rawAuditRows.count + 1, 2))"
        ),
        worksheetXML(
            rows: guideRows(mode: mode, exportDate: nowString(), settings: settings),
            columns: [.init(index: 1, width: 18), .init(index: 2, width: 72)]
        )
    ]

    try writeText(contentTypesXML(sheetCount: sheetNames.count), to: packageURL.appendingPathComponent("[Content_Types].xml"))
    try writeText(rootRelsXML(), to: relsURL.appendingPathComponent(".rels"))
    try writeText(workbookXML(sheetNames: sheetNames, definedNames: definedNames), to: xlURL.appendingPathComponent("workbook.xml"))
    try writeText(workbookRelsXML(sheetCount: sheetNames.count), to: xlRelsURL.appendingPathComponent("workbook.xml.rels"))
    try writeText(stylesXML(), to: xlURL.appendingPathComponent("styles.xml"))
    for (index, sheet) in sheets.enumerated() {
        try writeText(sheet, to: worksheetsURL.appendingPathComponent("sheet\(index + 1).xml"))
    }
}

private func zipPackage(packageURL: URL, outputURL: URL) throws {
    if FileManager.default.fileExists(atPath: outputURL.path) {
        try FileManager.default.removeItem(at: outputURL)
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.arguments = ["-qr", outputURL.path, "."]
    process.currentDirectoryURL = packageURL
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw LedgerError.invalid("엑셀 파일 압축 생성에 실패했습니다.")
    }
}

@discardableResult
func exportXLSXFile(
    to url: URL,
    entries: [LedgerEntry],
    summary: LedgerSummary,
    auditRows: [[String: String]],
    mode: LedgerMode,
    settings: OperationSettings
) throws -> URL {
    let output = url.pathExtension.lowercased() == "xlsx" ? url : url.deletingPathExtension().appendingPathExtension("xlsx")
    let tempURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("wedding-ledger-xlsx-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: tempURL) }
    try createXLSXPackage(at: tempURL, entries: entries, summary: summary, auditRows: auditRows, mode: mode, settings: settings)
    try zipPackage(packageURL: tempURL, outputURL: output)
    return output
}
