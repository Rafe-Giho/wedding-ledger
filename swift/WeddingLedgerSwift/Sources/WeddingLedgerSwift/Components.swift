import SwiftUI

enum AppColors {
    static let background = Color(nsColor: .windowBackgroundColor)
    static let sidebar = Color(red: 0.94, green: 0.90, blue: 0.84)
    static let sidebarActive = Color(red: 0.92, green: 0.87, blue: 0.79)
    static let card = Color(red: 1.0, green: 0.985, blue: 0.955).opacity(0.88)
    static let field = Color(red: 1.0, green: 0.99, blue: 0.97)
    static let line = Color(red: 0.84, green: 0.77, blue: 0.68)
    static let gold = Color(red: 0.64, green: 0.42, blue: 0.17)
    static let ink = Color(red: 0.14, green: 0.14, blue: 0.14)
}

struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(30)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppColors.line.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 26, y: 14)
    }
}

struct FieldLabel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content
                .padding(.horizontal, 14)
                .frame(minHeight: 54)
                .background(AppColors.field, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppColors.line.opacity(0.65), lineWidth: 1))
        }
    }
}

struct SuggestionTextField: View {
    @Binding var text: String
    let suggestions: [String]

    var body: some View {
        HStack {
            TextField("입력", text: $text)
                .textFieldStyle(.plain)
            Menu {
                if suggestions.isEmpty {
                    Text("저장된 목록이 없습니다.")
                } else {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { text = suggestion }
                    }
                }
            } label: {
                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
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
                .background(outlined ? Color.clear : Color(red: 0.91, green: 0.87, blue: 0.80), in: Capsule())
                .overlay(Capsule().stroke(outlined ? AppColors.gold : .clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let footnote: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Image(systemName: symbol)
                    .foregroundStyle(AppColors.gold)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(AppColors.gold.opacity(0.45)))
            }
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .minimumScaleFactor(0.75)
            Text(footnote)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(22)
        .frame(maxWidth: .infinity, minHeight: 164)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.line.opacity(0.48)))
    }
}

struct SummaryTile: View {
    let title: String
    let value: String

    init(_ title: String, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .background(AppColors.field, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(AppColors.line.opacity(0.5)))
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
