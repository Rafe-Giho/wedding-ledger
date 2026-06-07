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
    let headers = ["봉투번호", "이름", "모임", "관계", "금액", "식권수", "입금방식", "상태", "모드", "입력시간", "입력일시값", "수정시간", "입력일", "시간대", "메모"]
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
            .formula("IF(J\(row)=\"\",\"\",HOUR(K\(row)))"),
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

private func groupRows(summary: LedgerSummary, lastRow: Int) -> [[XLSXCell]] {
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let groupRange = "'전체내역'!$C$2:$C$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    var rows: [[XLSXCell]] = [[.text("모임", style: styleHeader), .text("건수", style: styleHeader), .text("총액", style: styleHeader), .text("식권 수", style: styleHeader), .text("평균 축의금", style: styleHeader)]]
    for (index, group) in summary.groupTotals.enumerated() {
        let row = index + 2
        rows.append([
            .text(group.groupName),
            .formula("COUNTIFS(\(groupRange),A\(row),\(statusRange),\"정상\")"),
            .formula("SUMIFS(\(amountRange),\(groupRange),A\(row),\(statusRange),\"정상\")", style: styleMoney),
            .formula("SUMIFS(\(ticketRange),\(groupRange),A\(row),\(statusRange),\"정상\")"),
            .formula("IFERROR(C\(row)/B\(row),0)", style: styleMoney)
        ])
    }
    return rows
}

private func searchRows(lastRow: Int) -> [[XLSXCell]] {
    let detailRange = "'전체내역'!$A$2:$O$\(lastRow)"
    let nameRange = "'전체내역'!$B$2:$B$\(lastRow)"
    let groupRange = "'전체내역'!$C$2:$C$\(lastRow)"
    let relationshipRange = "'전체내역'!$D$2:$D$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    let paymentRange = "'전체내역'!$G$2:$G$\(lastRow)"
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let serialRange = "'전체내역'!$K$2:$K$\(lastRow)"
    let criteria = """
    (IF($B$3="",TRUE,ISNUMBER(SEARCH($B$3,\(nameRange)))))*
    (IF($B$4="",TRUE,ISNUMBER(SEARCH($B$4,\(groupRange)))))*
    (IF($B$5="",TRUE,ISNUMBER(SEARCH($B$5,\(relationshipRange)))))*
    (IF($B$6="",TRUE,\(paymentRange)=$B$6))*
    (IF($B$7="",TRUE,\(statusRange)=$B$7))*
    (\(amountRange)>=IF($B$8="",0,$B$8))*
    (\(amountRange)<=IF($B$9="",999999999,$B$9))*
    (IF($B$10="",TRUE,\(ticketRange)=$B$10))*
    (\(serialRange)>=IF($B$11="",0,DATEVALUE(LEFT($B$11,10))+TIMEVALUE(RIGHT($B$11,8))))*
    (\(serialRange)<=IF($B$12="",999999,DATEVALUE(LEFT($B$12,10))+TIMEVALUE(RIGHT($B$12,8))))
    """.replacingOccurrences(of: "\n", with: "")
    let filterFormula = "FILTER(\(detailRange),\(criteria),\"조건에 맞는 기록 없음\")"
    return [
        [.text("검색 조건", style: styleTitle), .text("입력값", style: styleTitle), .text("설명", style: styleTitle), .blank(), .text("검색 요약", style: styleTitle), .text("값", style: styleTitle)],
        [.text("사용법"), .text("B열에 조건 입력"), .text("아래 결과가 자동 갱신됩니다."), .blank(), .text("결과 건수"), .formula("IFERROR(ROWS(A16#),0)")],
        [.text("이름 포함"), .blank(), .text("예: 김민수"), .blank(), .text("결과 총액"), .formula("IFERROR(SUM(INDEX(A16#,0,5)),0)", style: styleMoney)],
        [.text("모임 포함"), .blank(), .text("예: 회사"), .blank(), .text("결과 식권"), .formula("IFERROR(SUM(INDEX(A16#,0,6)),0)")],
        [.text("관계 포함"), .blank(), .text("예: 친구"), .blank(), .text("최근 결과 입력시간"), .formula("IFERROR(MAX(INDEX(A16#,0,11)),\"\")", style: styleDateTime)],
        [.text("입금방식"), .blank(), .text("현금/계좌/기타"), .blank(), .blank(), .blank()],
        [.text("상태"), .text("정상"), .text("정상/취소"), .blank(), .blank(), .blank()],
        [.text("최소 금액"), .blank(), .text("숫자만 입력"), .blank(), .blank(), .blank()],
        [.text("최대 금액"), .blank(), .text("숫자만 입력"), .blank(), .blank(), .blank()],
        [.text("식권수"), .blank(), .text("정확히 일치"), .blank(), .blank(), .blank()],
        [.text("시작 입력시간"), .blank(), .text("yyyy-mm-dd hh:mm:ss"), .blank(), .blank(), .blank()],
        [.text("종료 입력시간"), .blank(), .text("yyyy-mm-dd hh:mm:ss"), .blank(), .blank(), .blank()],
        [.blank(), .blank(), .blank(), .blank(), .blank(), .blank()],
        [.text("검색 결과", style: styleTitle), .blank(), .blank(), .blank(), .blank(), .blank()],
        ["봉투번호", "이름", "모임", "관계", "금액", "식권수", "입금방식", "상태", "모드", "입력시간", "입력일시값", "수정시간", "입력일", "시간대", "메모"].map { .text($0, style: styleHeader) },
        [.formula(filterFormula)]
    ]
}

private func hourlyRows(lastRow: Int) -> [[XLSXCell]] {
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let hourRange = "'전체내역'!$N$2:$N$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    var rows: [[XLSXCell]] = [[.text("시간대", style: styleHeader), .text("건수", style: styleHeader), .text("총액", style: styleHeader), .text("식권 수", style: styleHeader)]]
    for hour in 0...23 {
        let row = hour + 2
        rows.append([
            .number(hour),
            .formula("COUNTIFS(\(hourRange),A\(row),\(statusRange),\"정상\")"),
            .formula("SUMIFS(\(amountRange),\(hourRange),A\(row),\(statusRange),\"정상\")", style: styleMoney),
            .formula("SUMIFS(\(ticketRange),\(hourRange),A\(row),\(statusRange),\"정상\")")
        ])
    }
    return rows
}

private func duplicateRows(summary: LedgerSummary, lastRow: Int) -> [[XLSXCell]] {
    let nameRange = "'전체내역'!$B$2:$B$\(lastRow)"
    let statusRange = "'전체내역'!$H$2:$H$\(lastRow)"
    let amountRange = "'전체내역'!$E$2:$E$\(lastRow)"
    let ticketRange = "'전체내역'!$F$2:$F$\(lastRow)"
    let envelopeRange = "'전체내역'!$A$2:$A$\(lastRow)"
    var rows: [[XLSXCell]] = [[.text("이름", style: styleHeader), .text("인원", style: styleHeader), .text("총액", style: styleHeader), .text("식권 수", style: styleHeader), .text("봉투번호", style: styleHeader)]]
    if summary.duplicateNames.isEmpty {
        rows.append([.text("없음"), .blank(), .blank(), .blank(), .blank()])
        return rows
    }
    for (index, duplicate) in summary.duplicateNames.enumerated() {
        let row = index + 2
        rows.append([
            .text(duplicate.name),
            .formula("IF(A\(row)=\"\",\"\",COUNTIFS(\(nameRange),A\(row),\(statusRange),\"정상\"))"),
            .formula("IF(A\(row)=\"\",\"\",SUMIFS(\(amountRange),\(nameRange),A\(row),\(statusRange),\"정상\"))", style: styleMoney),
            .formula("IF(A\(row)=\"\",\"\",SUMIFS(\(ticketRange),\(nameRange),A\(row),\(statusRange),\"정상\"))"),
            .formula("IF(A\(row)=\"\",\"\",TEXTJOIN(\", \",TRUE,FILTER(\(envelopeRange),(\(nameRange)=A\(row))*(\(statusRange)=\"정상\"))))")
        ])
    }
    return rows
}

private func auditRows(_ auditRows: [[String: String]]) -> [[XLSXCell]] {
    let headers = ["시간", "봉투번호", "이름", "동작", "사유", "변경 전", "변경 후"]
    var rows = [headers.map { XLSXCell.text($0, style: styleHeader) }]
    rows += auditRows.map {
        [
            .text($0["created_at"] ?? ""),
            .text($0["envelope_no"] ?? ""),
            .text($0["name"] ?? ""),
            .text($0["action"] ?? ""),
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
        [.text("검색용"), .text("B열 조건을 입력하면 A16부터 결과가 자동으로 펼쳐집니다.")],
        [.text("모임별"), .text("모임별 건수, 총액, 식권, 평균 축의금을 계산합니다.")],
        [.text("시간대별"), .text("입력시간 기준 시간대별 집중도를 확인합니다.")],
        [.text("동명이인"), .text("같은 이름의 정상 기록을 자동으로 찾아 인원과 봉투번호를 보여줍니다.")],
        [.text("수정이력"), .text("취소, 복구 등 감사 로그를 확인합니다.")]
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
    let sheetNames = ["전체내역", "요약", "검색용", "모임별", "시간대별", "동명이인", "수정이력", "안내"]
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
                .init(index: 13, width: 13), .init(index: 14, width: 9), .init(index: 15, width: 28)
            ],
            autoFilter: "A1:O\(lastRow)",
            conditionalFormatting: detailConditionalFormatting
        ),
        worksheetXML(
            rows: summaryRows(lastRow: lastRow, settings: settings),
            columns: [.init(index: 1, width: 18), .init(index: 2, width: 20), .init(index: 3, width: 34)]
        ),
        worksheetXML(
            rows: searchRows(lastRow: lastRow),
            columns: (1...15).map { .init(index: $0, width: $0 == 15 ? 28 : 14) },
            frozenRows: 15,
            dataValidations: searchValidations
        ),
        worksheetXML(
            rows: groupRows(summary: summary, lastRow: lastRow),
            columns: [.init(index: 1, width: 18), .init(index: 2, width: 10), .init(index: 3, width: 14), .init(index: 4, width: 10), .init(index: 5, width: 14)],
            autoFilter: "A1:E\(max(summary.groupTotals.count + 1, 2))"
        ),
        worksheetXML(
            rows: hourlyRows(lastRow: lastRow),
            columns: [.init(index: 1, width: 10), .init(index: 2, width: 10), .init(index: 3, width: 14), .init(index: 4, width: 10)]
        ),
        worksheetXML(
            rows: duplicateRows(summary: summary, lastRow: lastRow),
            columns: [.init(index: 1, width: 14), .init(index: 2, width: 10), .init(index: 3, width: 14), .init(index: 4, width: 10), .init(index: 5, width: 24)]
        ),
        worksheetXML(
            rows: auditRows(rawAuditRows),
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
