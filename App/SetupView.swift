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
    @State private var selectionFocus: SetupGuideFocus = .custom

    private func title(_ step: SetupStep) -> String {
        switch step {
        case .install: return model.text("安装屏保", "Install screen saver")
        case .wallpaper: return model.text("打开屏保设置", "Open screen saver settings")
        case .select: return model.text("选中 QScreen", "Choose QScreen")
        case .password: return model.text("立即要求密码", "Require a password immediately")
        case .finish: return model.text("从菜单栏快速锁屏", "Lock from the menu bar")
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
        .onChange(of: model.setupStep) { _ in selectionFocus = .custom }
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
            guidePanel(.wallpaper, instruction: model.text("墙纸 → Screen Saver…（屏幕保护程序）", "Wallpaper → Screen Saver…")) {
                settingsButton(model.text("打开墙纸设置", "Open Wallpaper settings")) { model.openScreenSaverSettings() }
            }
        case .select:
            guidePanel(selectionFocus, instruction: "") {
                settingsButton(model.text("打开系统设置", "Open System Settings")) { model.openScreenSaverSettings() }
            }
        case .password:
            guidePanel(.password, instruction: model.text("锁屏 → 要求输入密码 → Immediately（立即）", "Lock Screen → Require password → Immediately")) {
                settingsButton(model.text("打开锁屏设置", "Open Lock Screen settings")) { model.openLockSettings() }
                Button(model.text("重新检查", "Recheck")) { model.refreshLockPolicy() }
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(setupAccent)
                Spacer(minLength: 8)
                policyStatus.font(.system(size: 11))
            }
        case .finish:
            VStack(alignment: .leading, spacing: 24) {
                MenuBarTutorial(model: model).frame(maxWidth: .infinity)
                HStack {
                    if model.ready {
                        Button { model.showPreview?() } label: {
                            Label(model.text("全屏预览", "Full-screen preview"), systemImage: "arrow.up.left.and.arrow.down.right")
                        }.buttonStyle(.plain).foregroundStyle(setupAccent)
                    } else {
                        Label(model.text("设置尚未完成", "Setup is incomplete"), systemImage: "exclamationmark.circle")
                            .foregroundStyle(.secondary)
                        Button(model.text("继续完成设置", "Review setup")) {
                            model.setSetupStep(SetupFlow.firstIncomplete(installed: model.installed, selected: model.selectedInSystem, policy: model.lockPolicy))
                        }.buttonStyle(.plain).foregroundStyle(setupAccent)
                    }
                    Spacer()
                    Text(model.text("菜单操作示意", "Menu illustration")).font(.system(size: 10)).foregroundStyle(.secondary)
                }.font(.system(size: 12)).frame(height: 38)
                Spacer(minLength: 0)
            }.padding(.top, 18)
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if model.setupStep == .select {
            actionButton(model.text("已选中 QScreen", "I've selected QScreen"), enabled: model.installed) {
                model.confirmSelection()
                model.advanceSetup()
            }
        } else if model.setupStep == .finish {
            actionButton(model.finishingSetup ? model.text("正在检查…", "Checking…") : model.text("完成并打开菜单", "Finish & open menu"), enabled: model.canAdvanceSetup && !model.finishingSetup) {
                model.finishSetup(openQuickPicker: true)
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

    private func guidePanel<Actions: View>(_ focus: SetupGuideFocus, instruction: String, @ViewBuilder actions: () -> Actions) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if model.setupStep == .select {
                    HStack(spacing: 10) {
                        selectionChip(.custom, number: 1, title: "Custom", hint: model.text("自定", ""))
                        selectionChip(.qscreen, number: 2, title: model.text("下滑至 Other → QScreen", "Scroll to Other → QScreen"), hint: "")
                        selectionChip(.done, number: 3, title: "Done", hint: model.text("完成", ""))
                    }
                } else {
                    Text(instruction).font(.system(size: 14, weight: .medium))
                }
            }.frame(height: 44, alignment: .leading)
            SetupIllustration(focus: focus)
                .frame(maxWidth: .infinity).frame(height: 328)
                .accessibilityLabel(model.text("macOS 设置示意图，小动物指向需要点击的位置", "Illustrated macOS settings, with a character pointing to the control"))
                .allowsHitTesting(false)
            HStack(spacing: 16) {
                actions()
            }.frame(height: 38).padding(.top, 20)
            Spacer(minLength: 12)
            HStack {
                Text(model.text("macOS 设置示意图", "Illustrated macOS settings"))
                    .foregroundStyle(.secondary)
                Spacer()
                Link(model.text("其他 macOS 版本", "Other macOS versions"), destination: URL(string: "https://support.apple.com/guide/mac-help/mchl4b68853d/mac")!)
                    .foregroundStyle(setupAccent)
            }.font(.system(size: 10))
        }
    }

    private func selectionChip(_ focus: SetupGuideFocus, number: Int, title: String, hint: String) -> some View {
        Button { selectionFocus = focus } label: {
            HStack(spacing: 7) {
                Text("\(number)").font(.system(size: 10, weight: .semibold))
                    .frame(width: 20, height: 20)
                    .foregroundStyle(selectionFocus == focus ? .white : setupAccent)
                    .background(selectionFocus == focus ? setupAccent : setupAccent.opacity(0.08), in: Circle())
                Text(title + (hint.isEmpty ? "" : " · " + hint)).font(.system(size: 11, weight: .medium))
            }.padding(.horizontal, 9).padding(.vertical, 7)
                .background(selectionFocus == focus ? setupAccent.opacity(0.07) : Color.clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
            .accessibilityLabel(model.text("查看第 \(number) 步：", "Show step \(number): ") + title)
            .accessibilityAddTraits(selectionFocus == focus ? .isSelected : [])
    }

    private func settingsButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: "arrow.up.forward")
                .font(.system(size: 12, weight: .medium))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(setupPaper, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain)
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

}
