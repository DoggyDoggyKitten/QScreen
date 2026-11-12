import SwiftUI

private let tutorialInk = Color(red: 0.20, green: 0.25, blue: 0.22)
private let tutorialGreen = Color(red: 0.33, green: 0.43, blue: 0.34)
private let tutorialPaper = Color(red: 0.98, green: 0.97, blue: 0.94)

struct MenuBarTutorial: View {
    @ObservedObject var model: QScreenModel

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 20).fill(tutorialPaper)
            menuBar
            instruction(1, model.text("点击顶部菜单栏的 QScreen 图标", "Click QScreen in the top menu bar"))
                .frame(width: 295, alignment: .leading).offset(x: 28, y: 68)
            instruction(2, model.text("选择离席理由，立即锁屏", "Choose a reason to lock your screen"))
                .frame(width: 295, alignment: .leading).offset(x: 28, y: 155)
            Text(model.text("右侧分钟数可以调整返回时间", "Adjust your return time using the minutes on the right"))
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .frame(width: 270, alignment: .leading).offset(x: 61, y: 206)
            if model.hotkeyAvailable {
                VStack(alignment: .leading, spacing: 9) {
                    Text("⌃ ⌥ Q").font(.system(size: 14, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(.white, in: RoundedRectangle(cornerRadius: 7))
                    Text(model.text("也能打开离席菜单", "also opens the away menu"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }.offset(x: 61, y: 263)
            }
            picker.frame(width: 260).offset(x: 400, y: 39)
        }
        .foregroundStyle(tutorialInk)
        .frame(width: 680, height: 328)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.text("点击屏幕顶部菜单栏的 QScreen 图标，调整右侧分钟数，再选择离席理由即可锁屏。", "Click the QScreen icon in the top menu bar, adjust the minutes on the right, then choose a reason to lock.") + (model.hotkeyAvailable ? model.text("快捷键 Control Option Q 也能打开菜单。", " Control Option Q also opens the menu.") : ""))
    }

    private var menuBar: some View {
        ZStack(alignment: .leading) {
            Color(red: 0.88, green: 0.91, blue: 0.87)
            HStack(spacing: 17) {
                Image(systemName: "apple.logo").font(.system(size: 12))
                Text("Finder").fontWeight(.semibold)
                Text("File")
                Text("Edit")
                Text("View")
                Spacer()
                Image(systemName: "wifi")
                Image(systemName: "battery.100percent")
                Text("9:41")
            }.font(.system(size: 10)).foregroundStyle(tutorialInk.opacity(0.65)).padding(.horizontal, 18)
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 14, weight: .medium))
                .frame(width: 30, height: 24)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(tutorialGreen, lineWidth: 1.5))
                .offset(x: 515)
            badge(1).offset(x: 551)
        }.frame(height: 28)
    }

    private var picker: some View {
        VStack(spacing: 0) {
            VStack(spacing: 1) {
                ForEach(model.reasons, id: \.self) { reason in
                    HStack(spacing: 9) {
                        thumbnail(reason)
                        Text(model.reasonTitle(reason)).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Spacer(minLength: 4)
                        if reason == "offwork" {
                            Text(model.text("无倒计时", "No timer")).foregroundStyle(.tertiary)
                        } else {
                            Text(model.minutesText(model.durations[reason] ?? QSDefaultMinutes(reason)))
                            Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold))
                        }
                    }
                    .font(.system(size: 10)).padding(.horizontal, 8).frame(height: 33)
                    .background(reason == "coffee" ? tutorialGreen.opacity(0.09) : .clear, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .leading) {
                        if reason == "coffee" { badge(2).offset(x: -19) }
                    }
                }
                HStack(spacing: 9) {
                    thumbnail("custom")
                    Text(model.text("自定义…", "Custom…")).font(.system(size: 11, weight: .medium))
                    Spacer()
                    Image(systemName: "square.and.pencil").font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(.horizontal, 8).frame(height: 33)
            }.padding(6)
            Divider().padding(.horizontal, 12)
            HStack {
                Label("QScreen", systemImage: "slider.horizontal.3").foregroundStyle(.secondary)
                Spacer()
                Text("中文").foregroundStyle(model.language == "zh" ? .white : .secondary)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(model.language == "zh" ? tutorialGreen : .clear, in: RoundedRectangle(cornerRadius: 4))
                Text("English").foregroundStyle(model.language == "en" ? .white : .secondary)
                    .padding(.horizontal, 5).padding(.vertical, 3)
                    .background(model.language == "en" ? tutorialGreen : .clear, in: RoundedRectangle(cornerRadius: 4))
            }.font(.system(size: 9)).padding(.horizontal, 12).frame(height: 29)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tutorialGreen.opacity(0.17), lineWidth: 1))
        .shadow(color: tutorialInk.opacity(0.09), radius: 6, y: 3)
        .allowsHitTesting(false)
    }

    private func thumbnail(_ reason: String) -> some View {
        CharacterScene(session: reason == "custom" ? model.customSceneSession : QSSession(reason, 15, Date().timeIntervalSince1970) as NSDictionary, characterOnly: true, animated: false)
            .frame(width: 27, height: 27).clipShape(RoundedRectangle(cornerRadius: 7))
    }

    private func badge(_ number: Int) -> some View {
        Text("\(number)").font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white).frame(width: 21, height: 21).background(tutorialGreen, in: Circle())
    }

    private func instruction(_ number: Int, _ title: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            badge(number)
            Text(title).font(.system(size: 16, weight: .semibold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
