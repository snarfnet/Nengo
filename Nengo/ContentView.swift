import SwiftUI
import UIKit

struct ContentView: View {
    @State private var activeTool = 0
    @State private var convertMode = 0
    @State private var seirekiInput = "1989"
    @State private var warekiEra = 3
    @State private var warekiInput = "1"
    @State private var birthDate = Calendar.current.date(from: DateComponents(year: 2000, month: 5, day: 12)) ?? Date()
    @State private var elementaryName = "〇〇小学校"
    @State private var juniorHighName = "〇〇中学校"
    @State private var highSchoolName = "〇〇高等学校"
    @State private var copiedMessage = ""

    private let eras: [Era] = [
        Era(name: "明治", start: 1868, end: 1912, offset: 1867),
        Era(name: "大正", start: 1912, end: 1926, offset: 1911),
        Era(name: "昭和", start: 1926, end: 1989, offset: 1925),
        Era(name: "平成", start: 1989, end: 2019, offset: 1988),
        Era(name: "令和", start: 2019, end: 9999, offset: 2018)
    ]
    private let eto = ["子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥"]
    private let currentYear = Calendar.current.component(.year, from: Date())

    private var seirekiResult: YearResult? {
        guard let year = Int(seirekiInput), year >= 1868, year <= 2100 else { return nil }
        return result(for: year)
    }

    private var warekiResult: YearResult? {
        guard let number = Int(warekiInput), number >= 1 else { return nil }
        let era = eras[warekiEra]
        let year = number + era.offset
        guard year >= era.start && year <= min(era.end, 2100) else { return nil }
        return result(for: year)
    }

    private var educationRows: [EducationRow] {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: birthDate)
        let birthYear = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1
        let earlyBirth = month < 4 || (month == 4 && day <= 1)
        let elementaryStart = birthYear + (earlyBirth ? 6 : 7)

        return [
            EducationRow(year: elementaryStart, month: 4, school: elementaryName, event: "入学"),
            EducationRow(year: elementaryStart + 6, month: 3, school: elementaryName, event: "卒業"),
            EducationRow(year: elementaryStart + 6, month: 4, school: juniorHighName, event: "入学"),
            EducationRow(year: elementaryStart + 9, month: 3, school: juniorHighName, event: "卒業"),
            EducationRow(year: elementaryStart + 9, month: 4, school: highSchoolName, event: "入学"),
            EducationRow(year: elementaryStart + 12, month: 3, school: highSchoolName, event: "卒業")
        ]
    }

    private var educationText: String {
        educationRows.map { row in
            "\(warekiString(for: row.year)) \(row.month)月　\(row.school) \(row.event)"
        }.joined(separator: "\n")
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        hero
                        toolTabs

                        if activeTool == 0 {
                            converterPanel
                            eraTable
                        } else {
                            resumePanel
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .onTapGesture { hideKeyboard() }

                BannerAdView(adUnitID: "ca-app-pub-9404799280370656/5700666818")
                    .frame(height: 50)
                    .background(.ultraThinMaterial)
            }
        }
        .preferredColorScheme(.light)
    }

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            Image("nengo-hero")
                .resizable()
                .scaledToFill()
                .frame(height: 210)
                .clipped()

            LinearGradient(
                colors: [.black.opacity(0.1), .black.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    EraChip(text: "昭和")
                    EraChip(text: "平成")
                    EraChip(text: "令和")
                }

                Text("年号変換")
                    .font(.system(size: 38, weight: .black, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("西暦・和暦・履歴書の学歴をすばやく確認")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(20)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.18)))
        .shadow(color: Color.black.opacity(0.18), radius: 22, y: 12)
    }

    private var toolTabs: some View {
        Picker("機能", selection: $activeTool) {
            Label("年号", systemImage: "calendar").tag(0)
            Label("履歴書", systemImage: "doc.text").tag(1)
        }
        .pickerStyle(.segmented)
        .padding(5)
        .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 8))
    }

    private var converterPanel: some View {
        VStack(spacing: 14) {
            Picker("変換", selection: $convertMode) {
                Text("西暦から").tag(0)
                Text("和暦から").tag(1)
            }
            .pickerStyle(.segmented)

            if convertMode == 0 {
                InputCard(title: "西暦を入力", caption: "1868年から2100年まで対応") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("1989", text: $seirekiInput)
                            .keyboardType(.numberPad)
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(Color.charcoal)
                        Text("年")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                ResultCard(result: seirekiResult, placeholder: "西暦を入れると、和暦・年齢・干支を表示します")
            } else {
                InputCard(title: "和暦を入力", caption: "明治から令和まで対応") {
                    VStack(spacing: 12) {
                        Picker("元号", selection: $warekiEra) {
                            ForEach(eras.indices, id: \.self) { index in
                                Text(eras[index].name).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)

                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            TextField("1", text: $warekiInput)
                                .keyboardType(.numberPad)
                                .font(.system(size: 52, weight: .black, design: .rounded))
                                .foregroundStyle(Color.charcoal)
                            Text("年")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ResultCard(result: warekiResult, placeholder: "元号と年を入れると、西暦・年齢・干支を表示します")
            }
        }
    }

    private var resumePanel: some View {
        VStack(spacing: 14) {
            InputCard(title: "生年月日", caption: "4月入学の一般的な学歴を作成") {
                DatePicker("生年月日", selection: $birthDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .font(.headline)
            }

            InputCard(title: "学校名", caption: "あとで履歴書に合わせて直せます") {
                VStack(spacing: 10) {
                    ResumeTextField(title: "小学校", text: $elementaryName)
                    ResumeTextField(title: "中学校", text: $juniorHighName)
                    ResumeTextField(title: "高校", text: $highSchoolName)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "学歴テンプレート", subtitle: "履歴書へそのまま写せる形")

                VStack(spacing: 0) {
                    ForEach(educationRows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(warekiString(for: row.year))
                                    .font(.system(size: 17, weight: .black))
                                    .foregroundStyle(Color.vermillion)
                                Text("\(row.year)年 \(row.month)月")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 92, alignment: .leading)

                            Text("\(row.school) \(row.event)")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(Color.charcoal)
                                .lineLimit(2)
                                .minimumScaleFactor(0.85)

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)

                        if row.id != educationRows.last?.id {
                            Divider().padding(.leading, 104)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.06)))

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = educationText
                        copiedMessage = "コピーしました"
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text(copiedMessage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.5)))
        }
    }

    private var eraTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "元号対応表", subtitle: "明治から令和まで")

            VStack(spacing: 0) {
                ForEach(eras) { era in
                    HStack(spacing: 12) {
                        Text(era.name)
                            .font(.system(size: 20, weight: .black, design: .serif))
                            .foregroundStyle(Color.vermillion)
                            .frame(width: 58, alignment: .leading)

                        Text("\(era.start)年 - \(era.end == 9999 ? "現在" : "\(era.end)年")")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.charcoal.opacity(0.78))

                        Spacer()

                        Text("元年 \(era.start)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.04), in: Capsule())
                    }
                    .padding(.vertical, 11)

                    if era.id != eras.last?.id {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.06)))
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.5)))
    }

    private func result(for year: Int) -> YearResult {
        let age = currentYear - year
        return YearResult(
            main: warekiString(for: year),
            seireki: "\(year)年",
            age: age >= 0 ? "今年\(age)歳" : "",
            eto: "\(eto[(year - 4) % 12])年"
        )
    }

    private func warekiString(for year: Int) -> String {
        for era in eras.reversed() where year >= era.start {
            let number = year - era.offset
            return number == 1 ? "\(era.name)元年" : "\(era.name)\(number)年"
        }
        return "\(year)年"
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            Color.washi.ignoresSafeArea()
            LinearGradient(
                colors: [Color.ivory.opacity(0.96), Color.washi, Color.greenInk.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct InputCard<Content: View>: View {
    let title: String
    let caption: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: title, subtitle: caption)
            content
        }
        .padding(18)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.07)))
        .shadow(color: Color.black.opacity(0.07), radius: 18, y: 10)
    }
}

private struct ResultCard: View {
    let result: YearResult?
    let placeholder: String

    var body: some View {
        VStack(spacing: 14) {
            if let result {
                Text(result.main)
                    .font(.system(size: 48, weight: .black, design: .serif))
                    .foregroundStyle(Color.ivory)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                HStack(spacing: 10) {
                    ResultPill(icon: "calendar", text: result.seireki)
                    if !result.age.isEmpty {
                        ResultPill(icon: "person.crop.circle", text: result.age)
                    }
                    ResultPill(icon: "sparkles", text: result.eto)
                }
            } else {
                Text(placeholder)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.ivory.opacity(0.82))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(
            LinearGradient(colors: [Color.charcoal, Color.greenInk], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.brass.opacity(0.45)))
        .shadow(color: Color.black.opacity(0.16), radius: 20, y: 12)
    }
}

private struct ResultPill: View {
    let icon: String
    let text: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.ivory)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.12), in: Capsule())
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(Color.charcoal)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

private struct EraChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.vermillion.opacity(0.82), in: Capsule())
    }
}

private struct ResumeTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 42)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .black))
            .foregroundStyle(.white)
            .frame(height: 46)
            .padding(.horizontal, 18)
            .background(Color.vermillion.opacity(configuration.isPressed ? 0.78 : 1), in: RoundedRectangle(cornerRadius: 8))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct Era: Identifiable {
    var id: String { name }
    let name: String
    let start: Int
    let end: Int
    let offset: Int
}

private struct YearResult {
    let main: String
    let seireki: String
    let age: String
    let eto: String
}

private struct EducationRow: Identifiable {
    var id: String { "\(year)-\(month)-\(school)-\(event)" }
    let year: Int
    let month: Int
    let school: String
    let event: String
}

extension Color {
    static let washi = Color(red: 0.89, green: 0.85, blue: 0.76)
    static let ivory = Color(red: 0.98, green: 0.95, blue: 0.86)
    static let charcoal = Color(red: 0.11, green: 0.11, blue: 0.10)
    static let vermillion = Color(red: 0.68, green: 0.16, blue: 0.10)
    static let brass = Color(red: 0.72, green: 0.54, blue: 0.26)
    static let greenInk = Color(red: 0.12, green: 0.24, blue: 0.20)
}

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
