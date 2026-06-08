import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let outputDirectory = root.appendingPathComponent("assets/readme/screenshots", isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
let readmeVersion = try currentAppVersion()

let canvas = CGSize(width: 1440, height: 900)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

let ink = color(245, 240, 232)
let muted = color(185, 170, 151)
let gold = color(224, 184, 116)
let goldSoft = color(63, 52, 40)
let field = color(42, 36, 30)
let card = color(48, 42, 34)
let sidebar = color(36, 31, 27)
let window = color(20, 19, 17)
let line = color(84, 70, 55)
let danger = color(230, 128, 112)

func currentAppVersion() throws -> String {
    let buildScript = root.appendingPathComponent("scripts/build_swift_macos_app.py")
    let contents = try String(contentsOf: buildScript, encoding: .utf8)
    let marker = #"APP_VERSION = os.environ.get("APP_VERSION", ""#
    guard
        let start = contents.range(of: marker)?.upperBound,
        let end = contents[start...].firstIndex(of: "\"")
    else {
        throw NSError(domain: "ReadmeScreenshots", code: 1, userInfo: [NSLocalizedDescriptionKey: "APP_VERSION 값을 찾을 수 없습니다."])
    }
    return String(contents[start..<end])
}

struct Rect {
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat

    var ns: NSRect { NSRect(x: x, y: canvas.height - y - h, width: w, height: h) }
}

func rounded(_ rect: Rect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil, width: CGFloat = 1) {
    let path = NSBezierPath(roundedRect: rect.ns, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = width
        path.stroke()
    }
}

func drawLine(from start: CGPoint, to end: CGPoint, width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: start.x, y: canvas.height - start.y))
    path.line(to: CGPoint(x: end.x, y: canvas.height - end.y))
    path.lineWidth = width
    color.setStroke()
    path.stroke()
}

func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = ink, width: CGFloat = 400, align: NSTextAlignment = .left) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = align
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ]
    value.draw(with: NSRect(x: x, y: canvas.height - y - size * 1.45, width: width, height: size * 1.45), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes)
}

func pill(_ title: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 40, fill: NSColor = goldSoft, stroke: NSColor = line, color: NSColor = ink) {
    rounded(Rect(x: x, y: y, w: w, h: h), radius: h / 2, fill: fill, stroke: stroke)
    text(title, x: x, y: y + (h - 18) / 2 - 1, size: 15, weight: .semibold, color: color, width: w, align: .center)
}

func fieldBox(_ title: String, value: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 56) {
    text(title, x: x, y: y - 24, size: 14, weight: .bold, color: ink, width: w)
    rounded(Rect(x: x, y: y, w: w, h: h), radius: 16, fill: color(35, 30, 26), stroke: line)
    text(value, x: x + 16, y: y + 17, size: 16, weight: .medium, color: value.isEmpty ? muted : ink, width: w - 32)
}

func screenshot(_ name: String, draw: () -> Void) throws {
    let image = NSImage(size: canvas)
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    NSGradient(colors: [color(58, 55, 49), window, color(12, 12, 11)])?.draw(in: NSRect(origin: .zero, size: canvas), angle: -28)
    rounded(Rect(x: 18, y: 18, w: canvas.width - 36, h: canvas.height - 36), radius: 30, fill: color(21, 20, 18, 0.94), stroke: color(102, 91, 76), width: 1.4)
    drawSidebar(active: name)
    drawTopBar()
    draw()

    image.unlockFocus()
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "ScreenshotGeneration", code: 1)
    }
    try data.write(to: outputDirectory.appendingPathComponent("\(name).png"))
}

func drawSidebar(active: String) {
    rounded(Rect(x: 18, y: 18, w: 258, h: canvas.height - 36), radius: 30, fill: sidebar, stroke: color(81, 66, 48, 0.7))
    text("⌘", x: 0, y: 112, size: 33, weight: .bold, color: gold, width: 294, align: .center)
    text("축의대 장부", x: 0, y: 158, size: 31, weight: .bold, color: ink, width: 294, align: .center)
    let items = [("entry", "입력", "✎"), ("search", "검색", "⌕"), ("summary", "정산", "▤"), ("settings", "설정", "⚙")]
    for (index, item) in items.enumerated() {
        let y = 278 + CGFloat(index) * 86
        let isActive = active == item.0
        rounded(Rect(x: 52, y: y, w: 190, h: 58), radius: 22, fill: isActive ? color(82, 72, 60) : sidebar, stroke: isActive ? color(82, 72, 60) : color(130, 119, 105, 0.6))
        rounded(Rect(x: 74, y: y + 11, w: 36, h: 36), radius: 18, fill: isActive ? gold : sidebar, stroke: isActive ? gold : color(130, 119, 105, 0.6))
        text(item.2, x: 72, y: y + 19, size: 16, weight: .bold, color: isActive ? .white : muted, width: 40, align: .center)
        text(item.1, x: 126, y: y + 17, size: 20, weight: .semibold, color: ink, width: 90)
    }
}

func drawTopBar() {
    pill("운영 모드", x: 1002, y: 74, w: 86, h: 34, fill: color(39, 34, 29), stroke: color(116, 91, 62), color: muted)
    pill("라이트", x: 1122, y: 74, w: 90, h: 34, fill: color(45, 41, 37), stroke: color(55, 50, 45), color: muted)
    pill("다크", x: 1216, y: 74, w: 90, h: 34, fill: goldSoft, stroke: gold, color: ink)
    pill("v\(readmeVersion)", x: 1318, y: 77, w: 76, h: 28, fill: color(42, 36, 30, 0.72), stroke: color(98, 82, 63), color: muted)
}

func cardBox(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, title: String) {
    rounded(Rect(x: x, y: y, w: w, h: h), radius: 22, fill: card, stroke: line)
    text(title, x: x + 22, y: y + 22, size: 24, weight: .bold, color: ink, width: w - 44)
}

try screenshot("entry") {
    cardBox(x: 316, y: 134, w: 520, h: 650, title: "새로운 축의 입력")
    text("필수: 이름, 금액 · 선택: 모임, 관계, 대상, 메모", x: 348, y: 182, size: 12, weight: .regular, color: muted, width: 454)
    fieldBox("봉투번호", value: "10", x: 348, y: 214, w: 222)
    fieldBox("입금방식", value: "계좌", x: 588, y: 214, w: 214)
    fieldBox("이름", value: "홍길동", x: 348, y: 294, w: 454)
    fieldBox("모임", value: "회사", x: 348, y: 374, w: 222)
    fieldBox("관계", value: "동료", x: 588, y: 374, w: 214)
    fieldBox("대상", value: "아버지", x: 348, y: 454, w: 454)
    fieldBox("금액", value: "₩ 100,000", x: 348, y: 534, w: 222)
    fieldBox("식권", value: "2매", x: 588, y: 534, w: 214)
    text("금액 빠른 선택", x: 348, y: 610, size: 15, weight: .bold)
    for (index, amount) in ["30,000", "50,000", "100,000", "150,000", "200,000", "+1만원"].enumerated() {
        pill(amount, x: 348 + CGFloat(index % 3) * 146, y: 640 + CGFloat(index / 3) * 48, w: 118)
    }
    rounded(Rect(x: 348, y: 738, w: 454, h: 48), radius: 18, fill: ink)
    text("저장", x: 348, y: 751, size: 18, weight: .bold, color: window, width: 454, align: .center)

    cardBox(x: 866, y: 134, w: 490, h: 318, title: "최근 입력 내역")
    let rows = [("#9 오세훈", "1,000,000원 · 10:31:09"), ("#7 정우진", "300,000원 · 기타"), ("#6 최하은", "50,000원 · 답례품")]
    for (index, row) in rows.enumerated() {
        text(row.0, x: 898, y: 210 + CGFloat(index) * 62, size: 17, weight: .bold, color: ink, width: 210)
        text(row.1, x: 1120, y: 210 + CGFloat(index) * 62, size: 15, weight: .medium, color: gold, width: 200, align: .right)
    }
    let stats = [("총 축의금", "2,300,000원"), ("총 식권", "12매"), ("총 봉투수", "7개"), ("평균 축의금", "328,571원")]
    for (index, stat) in stats.enumerated() {
        let x = 866 + CGFloat(index % 2) * 252
        let y = 482 + CGFloat(index / 2) * 154
        rounded(Rect(x: x, y: y, w: 238, h: 126), radius: 20, fill: card, stroke: line)
        text(stat.0, x: x + 22, y: y + 24, size: 15, weight: .bold, color: ink, width: 160)
        text(stat.1, x: x + 22, y: y + 66, size: 24, weight: .heavy, color: ink, width: 188)
    }
}

try screenshot("search") {
    cardBox(x: 316, y: 134, w: 1040, h: 650, title: "검색")
    let filters = [("이름", "김민수"), ("모임", ""), ("관계", "동료"), ("대상", "아버지"), ("최소 금액", "50,000"), ("식권수", ""), ("입금방식", "전체"), ("상태", "정상")]
    for (index, item) in filters.enumerated() {
        let x = 348 + CGFloat(index % 4) * 238
        let y = 214 + CGFloat(index / 4) * 82
        fieldBox(item.0, value: item.1, x: x, y: y, w: 206, h: 48)
    }
    pill("검색", x: 1066, y: 296, w: 108, h: 42, fill: goldSoft, stroke: line)
    pill("초기화", x: 1190, y: 296, w: 108, h: 42, fill: field, stroke: line)
    rounded(Rect(x: 348, y: 382, w: 968, h: 344), radius: 18, fill: color(35, 30, 26), stroke: line)
    let headers = ["봉투", "이름", "분류", "금액", "식권", "방식", "상태", "시간", "메모", "관리"]
    var x: CGFloat = 368
    for header in headers {
        text(header, x: x, y: 406, size: 13, weight: .bold, color: muted, width: 82)
        x += header == "메모" ? 150 : 86
    }
    let tableRows = [
        ["1", "김민수", "대학 동기/친구", "100,000원", "1", "현금", "정상", "10:01:12", "동아리 동기", "취소·삭제"],
        ["4", "김민수", "회사/동료", "150,000원", "1", "계좌", "정상", "10:11:33", "동명이인 확인", "취소·삭제"],
        ["8", "한지민", "회사/후배", "100,000원", "1", "현금", "취소", "10:25:19", "방명록 안내", "복구·삭제"]
    ]
    for (rowIndex, row) in tableRows.enumerated() {
        let y = 460 + CGFloat(rowIndex) * 74
        drawLine(from: CGPoint(x: 368, y: y - 16), to: CGPoint(x: 1294, y: y - 16), width: 1, color: color(75, 63, 50))
        var cellX: CGFloat = 368
        for (cellIndex, value) in row.enumerated() {
            let cellColor = value == "취소" && cellIndex == 6 ? danger : (cellIndex == 3 ? gold : ink)
            text(value, x: cellX, y: y, size: cellIndex == 8 ? 13 : 14, weight: cellIndex == 3 ? .bold : .medium, color: cellColor, width: cellIndex == 8 ? 140 : 82)
            cellX += cellIndex == 8 ? 150 : 86
        }
    }
}

try screenshot("summary") {
    cardBox(x: 316, y: 134, w: 1040, h: 650, title: "정산")
    text("최근 입력: 오늘 10:31:09", x: 348, y: 190, size: 14, weight: .regular, color: muted)
    let cards = [("총 축의금", "2,300,000원", "정상 7건 · 취소 1건"), ("평균 축의금", "328,571원", "7건 평균"), ("입금 방식", "현금 1,050,000원", "계좌 1,350,000원 · 기타 300,000원"), ("식권", "12매", "준비 180매 · 남은 168매"), ("봉투 검수", "7개", "예상 42개 · 누락 5"), ("동명이인", "1건", "김민수 2명")]
    for (index, item) in cards.enumerated() {
        let x = 348 + CGFloat(index % 3) * 318
        let y = 232 + CGFloat(index / 3) * 130
        rounded(Rect(x: x, y: y, w: 292, h: 108), radius: 18, fill: field, stroke: line)
        text(item.0, x: x + 18, y: y + 18, size: 13, weight: .bold, color: muted, width: 150)
        text(item.1, x: x + 18, y: y + 46, size: 20, weight: .heavy, color: ink, width: 242)
        text(item.2, x: x + 18, y: y + 78, size: 12, weight: .regular, color: muted, width: 252)
    }
    rounded(Rect(x: 348, y: 530, w: 968, h: 190), radius: 20, fill: field, stroke: line)
    text("마감 검수 순서", x: 370, y: 552, size: 18, weight: .bold)
    let checks = ["봉투 수", "현금", "계좌", "식권", "누락/동명이인", "백업/엑셀"]
    for (index, check) in checks.enumerated() {
        let x = 370 + CGFloat(index % 3) * 306
        let y = 598 + CGFloat(index / 3) * 58
        rounded(Rect(x: x, y: y, w: 280, h: 42), radius: 14, fill: card, stroke: line)
        text("□ \(index + 1)  \(check)", x: x + 14, y: y + 12, size: 14, weight: .bold, color: ink, width: 250)
    }
}

try screenshot("settings") {
    cardBox(x: 316, y: 134, w: 1040, h: 650, title: "설정")
    text("운영 모드", x: 348, y: 202, size: 17, weight: .bold)
    pill("테스트", x: 348, y: 236, w: 110, h: 42)
    pill("운영", x: 472, y: 236, w: 110, h: 42, fill: goldSoft, stroke: gold)
    text("화면 테마", x: 660, y: 202, size: 17, weight: .bold)
    pill("라이트", x: 660, y: 236, w: 120, h: 42)
    pill("다크", x: 794, y: 236, w: 120, h: 42, fill: goldSoft, stroke: gold)
    fieldBox("총 식권수", value: "180", x: 348, y: 344, w: 240)
    fieldBox("예상 봉투수", value: "42", x: 620, y: 344, w: 240)
    fieldBox("행사명", value: "지호 & 라페 결혼식", x: 892, y: 344, w: 360)
    rounded(Rect(x: 348, y: 464, w: 904, h: 90), radius: 16, fill: field, stroke: line)
    text("운영 메모", x: 370, y: 482, size: 14, weight: .bold, color: muted)
    text("README 캡처용 데모 데이터입니다. 마감 전 백업과 엑셀 추출을 확인하세요.", x: 370, y: 518, size: 15, weight: .regular, color: ink, width: 820)
    pill("백업 만들기", x: 348, y: 604, w: 150, h: 44, fill: field)
    pill("엑셀 추출", x: 516, y: 604, w: 150, h: 44, fill: goldSoft, stroke: gold)
    pill("운영 TIP", x: 684, y: 604, w: 150, h: 44, fill: field)
}

print(outputDirectory.path)
