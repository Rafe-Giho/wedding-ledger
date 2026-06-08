import AppKit
import SwiftUI

enum AppColors {
    static let background = Color.adaptive(light: rgb(0.91, 0.89, 0.86), dark: rgb(0.07, 0.06, 0.06))
    static let window = Color.adaptive(light: rgb(0.98, 0.98, 0.97), dark: rgb(0.09, 0.09, 0.08))
    static let sidebar = Color.adaptive(light: rgba(0.97, 0.96, 0.94, 0.92), dark: rgba(0.11, 0.10, 0.09, 0.92))
    static let sidebarActive = Color.adaptive(light: rgb(0.93, 0.90, 0.85), dark: rgb(0.22, 0.19, 0.16))
    static let card = Color.adaptive(light: rgba(1.0, 0.99, 0.97, 0.84), dark: rgba(0.14, 0.13, 0.11, 0.88))
    static let cardStrong = Color.adaptive(light: rgb(1.0, 0.99, 0.97), dark: rgb(0.14, 0.13, 0.11))
    static let field = Color.adaptive(light: rgba(1.0, 0.99, 0.97, 0.94), dark: rgba(0.11, 0.10, 0.09, 0.94))
    static let line = Color.adaptive(light: rgb(0.89, 0.84, 0.79), dark: rgb(0.29, 0.25, 0.21))
    static let lineSoft = Color.adaptive(light: rgba(0.83, 0.76, 0.67, 0.48), dark: rgba(0.36, 0.30, 0.24, 0.58))
    static let text = Color.adaptive(light: rgb(0.13, 0.11, 0.09), dark: rgb(0.96, 0.94, 0.91))
    static let muted = Color.adaptive(light: rgb(0.48, 0.44, 0.40), dark: rgb(0.72, 0.66, 0.60))
    static let gold = Color.adaptive(light: rgb(0.65, 0.44, 0.17), dark: rgb(0.85, 0.67, 0.43))
    static let goldSoft = Color.adaptive(light: rgb(0.94, 0.91, 0.85), dark: rgb(0.23, 0.20, 0.17))
    static let ink = Color.adaptive(light: rgb(0.14, 0.14, 0.14), dark: rgb(0.95, 0.91, 0.86))
    static let danger = Color.adaptive(light: rgb(0.72, 0.26, 0.21), dark: rgb(0.94, 0.58, 0.50))
}

struct Card<Content: View>: View {
    var padding: CGFloat = 30
    var fillsAvailableSpace = false
    @ViewBuilder let content: Content

    @ViewBuilder
    var body: some View {
        let sizedContent = content
            .padding(padding)
            .frame(
                maxWidth: fillsAvailableSpace ? .infinity : nil,
                maxHeight: fillsAvailableSpace ? .infinity : nil,
                alignment: .topLeading
            )
        sizedContent
            .background(AppColors.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.line.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.13), radius: 28, y: 18)
    }
}

struct FieldLabel<Content: View>: View {
    let title: String
    let badge: String?
    @ViewBuilder let content: Content

    init(_ title: String, badge: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.badge = badge
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.text)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(badge == "필수" ? AppColors.gold : AppColors.muted)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(badge == "필수" ? AppColors.goldSoft : AppColors.field, in: Capsule())
                        .overlay(Capsule().stroke(AppColors.lineSoft, lineWidth: 1))
                }
            }
            content
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.field, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(AppColors.line.opacity(0.65), lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SuggestionTextField: View {
    @Binding var text: String
    let suggestions: [String]

    var body: some View {
        HStack {
            TextField("입력", text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(AppColors.text)
            OptionMenuButton(options: suggestions, emptyMessage: "저장된 목록이 없습니다.") { suggestion in
                text = suggestion
            }
        }
    }
}

struct MenuValueField: View {
    let value: String
    let placeholder: String
    let options: [String]
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(value.isEmpty ? placeholder : value)
                .foregroundStyle(value.isEmpty ? AppColors.muted : AppColors.text)
                .lineLimit(1)
            Spacer(minLength: 8)
            OptionMenuButton(options: options, emptyMessage: "선택 가능한 값이 없습니다.", onSelect: onSelect)
        }
    }
}

struct OptionMenuButton: View {
    let options: [String]
    let emptyMessage: String
    let onSelect: (String) -> Void

    var body: some View {
        Menu {
            if options.isEmpty {
                Text(emptyMessage)
            } else {
                ForEach(options, id: \.self) { option in
                    Button(option) { onSelect(option) }
                }
            }
        } label: {
            Text("목록")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppColors.muted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(AppColors.goldSoft.opacity(0.72), in: Capsule())
                .overlay(Capsule().stroke(AppColors.lineSoft, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
}

struct PillButton: View {
    let title: String
    let outlined: Bool
    let action: () -> Void

    init(_ title: String, outlined: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.outlined = outlined
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .padding(.horizontal, 18)
                .frame(height: 46)
                .foregroundStyle(AppColors.text)
                .background(outlined ? Color.clear : AppColors.goldSoft, in: Capsule())
                .overlay(Capsule().stroke(outlined ? AppColors.gold : AppColors.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let footnote: String
    let symbol: String
    var fillsHeight = false

    var body: some View {
        let compact = fillsHeight
        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColors.text)
                Spacer()
                Image(systemName: symbol)
                    .foregroundStyle(AppColors.gold)
                    .frame(width: compact ? 30 : 34, height: compact ? 30 : 34)
                    .overlay(Circle().stroke(AppColors.gold.opacity(0.45)))
            }
            Text(value)
                .font(.system(size: compact ? 26 : 30, weight: .bold))
                .foregroundStyle(AppColors.text)
                .minimumScaleFactor(0.75)
            Text(footnote)
                .font(compact ? .caption : .subheadline)
                .foregroundStyle(AppColors.muted)
                .lineLimit(2)
        }
        .padding(compact ? 18 : 22)
        .frame(maxWidth: .infinity, minHeight: compact ? 126 : 164)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.line.opacity(0.48)))
    }
}

struct ModePill: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(AppColors.muted)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(AppColors.field, in: Capsule())
            .overlay(Capsule().stroke(AppColors.line, lineWidth: 1))
    }
}

private func rgb(_ red: Double, _ green: Double, _ blue: Double) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1)
}

private func rgba(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) -> NSColor {
    NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
}

private extension Color {
    static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let match = appearance.bestMatch(from: [.darkAqua, .aqua])
            return match == .darkAqua ? dark : light
        })
    }
}

struct FloralLineArt: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: w * 0.16, y: h * 0.92))
        path.addCurve(
            to: CGPoint(x: w * 0.84, y: h * 0.08),
            control1: CGPoint(x: w * 0.44, y: h * 0.72),
            control2: CGPoint(x: w * 0.45, y: h * 0.32)
        )
        for seed in stride(from: 0.18, through: 0.82, by: 0.16) {
            let y = h * seed
            let x = w * (0.18 + seed * 0.62)
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(
                to: CGPoint(x: x - 44, y: y + 34),
                control1: CGPoint(x: x - 28, y: y + 2),
                control2: CGPoint(x: x - 42, y: y + 16)
            )
            path.move(to: CGPoint(x: x, y: y))
            path.addCurve(
                to: CGPoint(x: x + 46, y: y + 20),
                control1: CGPoint(x: x + 22, y: y - 8),
                control2: CGPoint(x: x + 40, y: y + 2)
            )
            path.addEllipse(in: CGRect(x: x - 14, y: y - 14, width: 28, height: 28))
        }
        return path
    }
}
