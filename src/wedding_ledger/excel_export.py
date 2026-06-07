from __future__ import annotations

from pathlib import Path
from typing import Any
from xml.sax.saxutils import escape

from .constants import MODE_LABELS, PAYMENT_METHODS, STATUS_ACTIVE, STATUS_LABELS


def money(value: int | None) -> int:
    return int(value or 0)


def cell(value: Any, style: str | None = None, formula: str | None = None) -> str:
    attrs = []
    if style:
        attrs.append(f'ss:StyleID="{style}"')
    if formula:
        escaped_formula = escape(formula, {'"': "&quot;"})
        attrs.append(f'ss:Formula="{escaped_formula}"')
    attr_text = " " + " ".join(attrs) if attrs else ""
    if isinstance(value, int):
        return f"<Cell{attr_text}><Data ss:Type=\"Number\">{value}</Data></Cell>"
    return f"<Cell{attr_text}><Data ss:Type=\"String\">{escape(str(value or ''))}</Data></Cell>"


def row(values: list[Any], style: str | None = None) -> str:
    return "<Row>" + "".join(cell(value, style=style) for value in values) + "</Row>"


def workbook_xml(entries: list[dict[str, Any]], summary: dict[str, Any], audit_rows: list[dict[str, Any]]) -> str:
    last_row = max(len(entries) + 1, 2)
    group_totals = summary["group_totals"]
    active_entries = [entry for entry in entries if entry["status"] == STATUS_ACTIVE]

    names = f"""
    <Names>
      <NamedRange ss:Name="전체내역_이름" ss:RefersTo="=전체내역!R2C2:R{last_row}C2"/>
      <NamedRange ss:Name="전체내역_모임" ss:RefersTo="=전체내역!R2C3:R{last_row}C3"/>
      <NamedRange ss:Name="전체내역_금액" ss:RefersTo="=전체내역!R2C5:R{last_row}C5"/>
      <NamedRange ss:Name="전체내역_식권" ss:RefersTo="=전체내역!R2C6:R{last_row}C6"/>
    </Names>
    """

    detail_headers = [
        "봉투번호",
        "이름",
        "모임",
        "관계",
        "금액",
        "식권수",
        "입금방식",
        "상태",
        "모드",
        "입력시간",
        "수정시간",
        "메모",
    ]
    detail_rows = [row(detail_headers, "Header")]
    for entry in entries:
        detail_rows.append(
            row(
                [
                    int(entry["envelope_no"]),
                    entry["name"],
                    entry["group_name"],
                    entry["relationship"],
                    int(entry["amount"]),
                    int(entry["meal_ticket_count"]),
                    PAYMENT_METHODS.get(entry["payment_method"], entry["payment_method"]),
                    STATUS_LABELS.get(entry["status"], entry["status"]),
                    MODE_LABELS.get(entry["mode"], entry["mode"]),
                    entry["created_at"],
                    entry["updated_at"],
                    entry["memo"],
                ]
            )
        )

    summary_rows = [
        row(["항목", "값"], "Header"),
        "<Row>" + cell("정상 기록 수") + cell(summary["active_count"], formula=f"=COUNTIF(전체내역!R2C8:R{last_row}C8,\"정상\")") + "</Row>",
        "<Row>" + cell("취소 기록 수") + cell(summary["void_count"], formula=f"=COUNTIF(전체내역!R2C8:R{last_row}C8,\"취소\")") + "</Row>",
        "<Row>" + cell("총 축의금") + cell(summary["total_amount"], style="Money", formula=f"=SUMIF(전체내역!R2C8:R{last_row}C8,\"정상\",전체내역!R2C5:R{last_row}C5)") + "</Row>",
        "<Row>" + cell("총 식권 수") + cell(summary["total_tickets"], formula=f"=SUMIF(전체내역!R2C8:R{last_row}C8,\"정상\",전체내역!R2C6:R{last_row}C6)") + "</Row>",
        "<Row>" + cell("현금 합계") + cell(summary["payment_totals"]["cash"], style="Money", formula=f"=SUMIFS(전체내역!R2C5:R{last_row}C5,전체내역!R2C7:R{last_row}C7,\"현금\",전체내역!R2C8:R{last_row}C8,\"정상\")") + "</Row>",
        "<Row>" + cell("계좌 합계") + cell(summary["payment_totals"]["transfer"], style="Money", formula=f"=SUMIFS(전체내역!R2C5:R{last_row}C5,전체내역!R2C7:R{last_row}C7,\"계좌\",전체내역!R2C8:R{last_row}C8,\"정상\")") + "</Row>",
        "<Row>" + cell("기타 합계") + cell(summary["payment_totals"]["other"], style="Money", formula=f"=SUMIFS(전체내역!R2C5:R{last_row}C5,전체내역!R2C7:R{last_row}C7,\"기타\",전체내역!R2C8:R{last_row}C8,\"정상\")") + "</Row>",
    ]

    group_rows = [row(["모임", "건수", "총액", "식권 수"], "Header")]
    for item in group_totals:
        group_rows.append(
            row(
                [
                    item["group_name"],
                    int(item["count"] or 0),
                    money(item["total_amount"]),
                    int(item["total_tickets"] or 0),
                ]
            )
        )

    search_rows = [
        row(["검색 조건", "입력값", "결과"], "Header"),
        row(["사용법", "B열에 조건을 입력하면 C열 수식이 계산됩니다.", ""]),
        "<Row>" + cell("이름") + cell("") + cell(0, formula=f"=COUNTIF(전체내역!R2C2:R{last_row}C2,R3C2)") + "</Row>",
        "<Row>" + cell("모임") + cell("") + cell(0, style="Money", formula=f"=SUMIF(전체내역!R2C3:R{last_row}C3,R4C2,전체내역!R2C5:R{last_row}C5)") + "</Row>",
        "<Row>" + cell("최소 금액") + cell(0) + cell("") + "</Row>",
        "<Row>" + cell("최대 금액") + cell(1000000) + cell(summary["total_amount"], style="Money", formula=f"=SUMIFS(전체내역!R2C5:R{last_row}C5,전체내역!R2C5:R{last_row}C5,\">=\"&R5C2,전체내역!R2C5:R{last_row}C5,\"<=\"&R6C2,전체내역!R2C8:R{last_row}C8,\"정상\")") + "</Row>",
        "<Row>" + cell("모임별 식권 수") + cell("") + cell(0, formula=f"=SUMIF(전체내역!R2C3:R{last_row}C3,R7C2,전체내역!R2C6:R{last_row}C6)") + "</Row>",
    ]

    audit_headers = ["시간", "봉투번호", "이름", "동작", "사유", "변경 전", "변경 후"]
    audit_sheet_rows = [row(audit_headers, "Header")]
    for audit in audit_rows:
        audit_sheet_rows.append(
            row(
                [
                    audit["created_at"],
                    audit.get("envelope_no") or "",
                    audit.get("name") or "",
                    audit["action"],
                    audit.get("reason") or "",
                    audit.get("before_json") or "",
                    audit.get("after_json") or "",
                ]
            )
        )

    return f"""<?xml version="1.0"?>
<?mso-application progid="Excel.Sheet"?>
<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:o="urn:schemas-microsoft-com:office:office"
 xmlns:x="urn:schemas-microsoft-com:office:excel"
 xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"
 xmlns:html="http://www.w3.org/TR/REC-html40">
  <DocumentProperties xmlns="urn:schemas-microsoft-com:office:office">
    <Title>축의대 장부 Export</Title>
  </DocumentProperties>
  <Styles>
    <Style ss:ID="Default" ss:Name="Normal">
      <Alignment ss:Vertical="Center"/>
      <Font ss:FontName="Apple SD Gothic Neo" ss:Size="11"/>
    </Style>
    <Style ss:ID="Header">
      <Font ss:FontName="Apple SD Gothic Neo" ss:Bold="1" ss:Color="#FFFFFF"/>
      <Interior ss:Color="#315E4D" ss:Pattern="Solid"/>
    </Style>
    <Style ss:ID="Money">
      <NumberFormat ss:Format="₩#,##0"/>
    </Style>
  </Styles>
  {names}
  <Worksheet ss:Name="전체내역">
    <Table>{''.join(detail_rows)}</Table>
    <WorksheetOptions xmlns="urn:schemas-microsoft-com:office:excel">
      <FreezePanes/>
      <FrozenNoSplit/>
      <SplitHorizontal>1</SplitHorizontal>
      <TopRowBottomPane>1</TopRowBottomPane>
    </WorksheetOptions>
  </Worksheet>
  <Worksheet ss:Name="요약">
    <Table>{''.join(summary_rows)}</Table>
  </Worksheet>
  <Worksheet ss:Name="모임별">
    <Table>{''.join(group_rows)}</Table>
  </Worksheet>
  <Worksheet ss:Name="검색용">
    <Table>{''.join(search_rows)}</Table>
  </Worksheet>
  <Worksheet ss:Name="수정이력">
    <Table>{''.join(audit_sheet_rows)}</Table>
  </Worksheet>
</Workbook>
"""


def export_xls(path: Path | str, entries: list[dict[str, Any]], summary: dict[str, Any], audit_rows: list[dict[str, Any]]) -> Path:
    path = Path(path)
    if path.suffix.lower() != ".xls":
        path = path.with_suffix(".xls")
    xml = workbook_xml(entries, summary, audit_rows)
    path.write_text(xml, encoding="utf-8")
    return path
