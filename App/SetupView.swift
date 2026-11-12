import SwiftUI

private let setupPaper = Color(red: 0.98, green: 0.97, blue: 0.94)
private let setupInk = Color(red: 0.20, green: 0.25, blue: 0.22)
private let setupAccent = Color(red: 0.33, green: 0.43, blue: 0.34)

struct QScreenRootView: View {
    @ObservedObject var model: QScreenModel
    var body: some View {
        if model.setupVisible { SetupView(model: model) }
        else { MainView(model: model) }
    }
}

struct SetupView: View {
    @ObservedObject var model: QScreenModel

    private func title(_ step: SetupStep) -> String {
        switch step {
        case .install: return model.text("安装屏保", "Install screen saver")
        case .wallpaper: return model.text("打开屏保设置", "Open screen saver settings")
        case .select: return model.text("选中 QScreen", "Choose QScreen")
        case .password: return model.text("立即要求密码", "Require a password immediately")
        case .finish: return model.text("设置完成", "You're ready")
        }
    }

    private func shortTitle(_ step: SetupStep) -> String {
        switch step {
        case .install: return model.text("安装屏保", "Install")
        case .wallpaper: return model.text("打开系统设置", "Open settings")
        case .select: return model.text("选择 QScreen", "Choose QScreen")
        case .password: return model.text("锁屏密码", "Password")
        case .finish: return model.text("完成", "Ready")
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Label("QScreen", systemImage: "sparkles.rectangle.stack")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .padding(.bottom, 48)
                ForEach(SetupStep.allCases, id: \.rawValue) { step in
                    HStack(spacing: 13) {
                        ZStack {
                            Circle().fill(step == model.setupStep ? setupAccent : setupAccent.opacity(0.08))
                            if step.rawValue < model.setupStep.rawValue {
                                Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(setupAccent)
                            } else {
                                Text("\(step.rawValue + 1)").font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(step == model.setupStep ? Color.white : setupInk.opacity(0.45))
                            }
                        }.frame(width: 27, height: 27)
                        Text(shortTitle(step)).font(.system(size: 13, weight: step == model.setupStep ? .semibold : .regular))
                            .foregroundStyle(step.rawValue <= model.setupStep.rawValue ? setupInk : setupInk.opacity(0.45))
                    }.frame(height: 58)
                }
                Spacer()
                Text(model.text("首次设置", "First-time setup"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(28).frame(width: 228).background(setupPaper)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Text(title(model.setupStep)).font(.system(size: 25, weight: .semibold, design: .rounded))
                    Spacer(minLength: 16)
                    LanguageSwitch(model: model)
                }
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
                if let error = model.setupError {
                    Text(error).font(.system(size: 12)).foregroundStyle(.red)
                }
                Divider()
                HStack(spacing: 16) {
                    if model.setupStep != .install {
                        Button(model.text("上一步", "Back")) {
                            if let previous = SetupStep(rawValue: model.setupStep.rawValue - 1) { model.setSetupStep(previous) }
                        }.buttonStyle(.plain)
                    }
                    Button(model.text("稍后设置", "Set up later")) { model.dismissSetup() }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                    Spacer()
                    primaryAction
                }.font(.system(size: 13)).frame(height: 44)
            }
            .padding(32).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white)
        }
        .foregroundStyle(setupInk).frame(minWidth: 1000, minHeight: 672)
        .alert("QScreen", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(model.text("好", "OK")) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    @ViewBuilder private var content: some View {
        switch model.setupStep {
        case .install:
            VStack(spacing: 25) {
                CharacterScene(session: QSSession("away", 15, Date().timeIntervalSince1970) as NSDictionary, characterOnly: true)
                    .frame(width: 230, height: 210).clipShape(RoundedRectangle(cornerRadius: 28))
                if model.installed {
                    Label(model.text("屏保已安装", "Screen saver installed"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(setupAccent)
                } else {
                    Button(model.text("安装 QScreen 屏保", "Install QScreen screen saver")) { model.installSaver() }
                        .controlSize(.large)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .wallpaper:
            VStack(alignment: .leading, spacing: 18) {
                Text(model.text("在「系统设置 → 墙纸」顶部，点击 Screen Saver…（屏幕保护程序）。", "In System Settings → Wallpaper, click Screen Saver… near the top."))
                    .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                SetupScreenshot(name: "wallpaper", model: model, topOnly: true)
                Button(model.text("打开墙纸设置", "Open Wallpaper settings")) { model.openScreenSaverSettings() }
                    .controlSize(.large)
                Spacer(minLength: 0)
                HStack {
                    screenshotNote
                    Spacer()
                    Link(model.text("其他 macOS 版本", "Other macOS versions"), destination: URL(string: "https://support.apple.com/guide/mac-help/mchl4b68853d/mac")!)
                        .font(.system(size: 11)).foregroundStyle(setupAccent)
                }
            }
        case .select:
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 20) {
                    SetupScreenshot(name: "screen-saver", model: model)
                    VStack(alignment: .leading, spacing: 20) {
                        instruction(1, model.text("选择 Custom（自定）。", "Select Custom."))
                        instruction(2, model.text("向下找到 Other（其他），选中 QScreen。", "Scroll to Other and choose QScreen."))
                        instruction(3, model.text("确认显示 QScreen，点 Done（完成）。", "Check that QScreen is shown, then click Done."))
                        Spacer(minLength: 0)
                    }.frame(width: 174).padding(.top, 12)
                }.frame(maxHeight: .infinity)
                HStack {
                    Button(model.text("打开系统设置", "Open System Settings")) { model.openScreenSaverSettings() }
                    Spacer()
                    screenshotNote
                }
            }
        case .password:
            VStack(alignment: .leading, spacing: 16) {
                Text(model.text("在「系统设置 → 锁屏」中，把启动屏保后要求输入密码设为 Immediately（立即）。", "In System Settings → Lock Screen, set Require password after screen saver begins or display is turned off to Immediately."))
                    .font(.system(size: 14)).fixedSize(horizontal: false, vertical: true)
                SetupScreenshot(name: "password", model: model, topOnly: true)
                HStack {
                    Button(model.text("打开锁屏设置", "Open Lock Screen settings")) { model.openLockSettings() }
                    Button(model.text("重新检查", "Recheck")) { model.refreshLockPolicy() }
                    Spacer()
                    policyStatus
                }.controlSize(.large)
                screenshotNote
            }
        case .finish:
            VStack(spacing: 24) {
                CharacterScene(session: QSSession("lunch", 15, Date().timeIntervalSince1970) as NSDictionary, characterOnly: true)
                    .frame(width: 190, height: 170).clipShape(RoundedRectangle(cornerRadius: 26))
                VStack(alignment: .leading, spacing: 15) {
                    readiness(model.text("屏保已安装", "Screen saver installed"), done: model.installed)
                    readiness(model.text("已确认选中 QScreen", "QScreen selection confirmed"), done: model.selectedInSystem)
                    readiness(model.text("退出屏保立即要求密码", "Password required immediately"), done: model.lockPolicy == .immediate)
                }
                if model.ready {
                    Button { model.showPreview?() } label: {
                        Label(model.text("先看看全屏预览", "Try a full-screen preview"), systemImage: "arrow.up.left.and.arrow.down.right")
                    }.buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(setupAccent)
                } else {
                    Button(model.text("继续完成设置", "Review remaining setup")) {
                        model.setSetupStep(SetupFlow.firstIncomplete(installed: model.installed, selected: model.selectedInSystem, policy: model.lockPolicy))
                    }.buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(setupAccent)
                }
                Text("⌃⌥Q  " + model.text("打开快速离席菜单", "opens the quick away menu"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if model.setupStep == .select {
            actionButton(model.text("已选中 QScreen", "I've selected QScreen"), enabled: model.installed) {
                model.confirmSelection()
                model.advanceSetup()
            }
        } else if model.setupStep == .finish {
            actionButton(model.finishingSetup ? model.text("正在检查…", "Checking…") : model.text("开始使用 QScreen", "Start using QScreen"), enabled: model.canAdvanceSetup && !model.finishingSetup) {
                model.finishSetup()
            }
        } else {
            actionButton(model.text("下一步", "Continue"), enabled: model.canAdvanceSetup) { model.advanceSetup() }
        }
    }

    private func actionButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 18).padding(.vertical, 12)
                .foregroundStyle(.white).background(setupAccent).clipShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.4)
    }

    private func instruction(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(number)").font(.system(size: 12, weight: .semibold)).foregroundStyle(setupAccent)
                .frame(width: 20, height: 20).background(setupAccent.opacity(0.09)).clipShape(Circle())
            Text(text).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var screenshotNote: some View {
        Text(model.text("实机截图：macOS 27 · 英文系统界面", "Actual screenshots: macOS 27 · English system UI"))
            .font(.system(size: 10)).foregroundStyle(.secondary)
    }

    @ViewBuilder private var policyStatus: some View {
        switch model.lockPolicy {
        case .immediate:
            Label(model.text("已检测到「立即」", "Immediately detected"), systemImage: "checkmark.circle.fill").foregroundStyle(setupAccent)
        case .requiresConfiguration:
            Label(model.text("请改为「立即」", "Choose Immediately"), systemImage: "circle").foregroundStyle(.secondary)
        case .unknown:
            Label(model.text("尚未确认，请重新检查", "Not confirmed. Recheck."), systemImage: "questionmark.circle").foregroundStyle(.secondary)
        }
    }

    private func readiness(_ title: String, done: Bool) -> some View {
        Label(title, systemImage: done ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 14)).foregroundStyle(done ? setupAccent : .secondary)
    }
}

private struct SetupScreenshot: View {
    let name: String
    @ObservedObject var model: QScreenModel
    var topOnly = false
    @State private var enlarged = false

    private var screenshot: NSImage? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Setup") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        Group {
            if let image = screenshot {
                Group {
                    if topOnly {
                        Image(nsImage: image).resizable().scaledToFill().frame(height: 240, alignment: .top).clipped()
                    } else {
                        Image(nsImage: image).resizable().scaledToFit()
                    }
                }
                .overlay {
                    if topOnly {
                        GeometryReader { geometry in
                            let scale = geometry.size.width / image.size.width
                            let target = name == "wallpaper" ? CGRect(x: 216, y: 137, width: 119, height: 28)
                                                               : CGRect(x: 12, y: 91, width: 465, height: 51)
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(setupAccent, lineWidth: 2)
                                .frame(width: target.width * scale, height: target.height * scale)
                                .position(x: target.midX * scale, y: target.midY * scale)
                        }.allowsHitTesting(false)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .bottomTrailing) {
                    Button { enlarged = true } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right").padding(9)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }.buttonStyle(.plain).padding(7)
                        .accessibilityLabel(model.text("放大截图", "Enlarge screenshot"))
                }
            } else {
                Text(model.text("截图未能载入，请按上方路径打开系统设置。", "Screenshot unavailable. Use the settings path above."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
        .sheet(isPresented: $enlarged) {
            VStack(spacing: 16) {
                if let image = screenshot { Image(nsImage: image).resizable().scaledToFit().frame(maxHeight: 600) }
                Button(model.text("关闭", "Close")) { enlarged = false }.keyboardShortcut(.cancelAction)
            }.padding(24).frame(width: 740)
        }
    }
}
