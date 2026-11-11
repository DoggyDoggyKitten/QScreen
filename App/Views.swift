import SwiftUI
import QuartzCore

private let paper = Color(red: 0.98, green: 0.97, blue: 0.94)
private let ink = Color(red: 0.20, green: 0.25, blue: 0.22)
private let accent = Color(red: 0.33, green: 0.43, blue: 0.34)

struct CharacterScene: NSViewRepresentable {
    let session: NSDictionary
    var characterOnly = false
    var animated = true

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> QSSceneView {
        let view = QSSceneView(frame: .zero)
        view.characterOnly = characterOnly
        context.coordinator.attach(view, animated: animated)
        return view
    }
    func updateNSView(_ view: QSSceneView, context: Context) {
        view.session = session as! [AnyHashable: Any]
        view.characterOnly = characterOnly
        view.referenceTime = Date().timeIntervalSince1970
    }
    static func dismantleNSView(_ view: QSSceneView, coordinator: Coordinator) { coordinator.timer?.invalidate() }

    final class Coordinator {
        var timer: Timer?
        func attach(_ view: QSSceneView, animated: Bool) {
            guard animated else { view.animationTime = 2; return }
            let start = CACurrentMediaTime()
            timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak view] _ in
                guard let view, view.window?.isVisible == true else { return }
                view.animationTime = CACurrentMediaTime() - start
                view.referenceTime = Date().timeIntervalSince1970
            }
            RunLoop.main.add(timer!, forMode: .common)
        }
        deinit { timer?.invalidate() }
    }
}

struct MainView: View {
    @ObservedObject var model: QScreenModel
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 9) {
                    Image(systemName: "sparkles.rectangle.stack").font(.system(size: 22, weight: .medium))
                    Text("QScreen").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Spacer()
                }.padding(.bottom, 28)
                ForEach(model.reasons, id: \.self) { reason in
                    Button {
                        model.selectedReason = reason
                        model.settingsVisible = false
                    } label: {
                        HStack(spacing: 12) {
                            CharacterScene(session: QSSession(reason, 15, Date().timeIntervalSince1970) as NSDictionary, characterOnly: true, animated: false)
                                .frame(width: 52, height: 52).clipShape(RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 5) {
                                Text(model.reasonTitle(reason)).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                                Text(reason == "offwork" ? model.text("无倒计时", "No timer") : model.minutesText(model.durations[reason] ?? 15))
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if model.selectedReason == reason && !model.settingsVisible {
                                Circle().fill(accent).frame(width: 7, height: 7)
                            }
                        }.padding(9)
                            .background(model.selectedReason == reason && !model.settingsVisible ? Color.white.opacity(0.8) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.bottom, 5)
                }
                Button { model.openCustomEditor() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil").font(.system(size: 18)).frame(width: 52)
                        Text(model.text("自定义", "Custom")).font(.system(size: 14, weight: .medium))
                        Spacer()
                        if model.selectedReason == "custom" && !model.settingsVisible {
                            Circle().fill(accent).frame(width: 7, height: 7)
                        }
                    }
                    .padding(.horizontal, 9).frame(height: 42)
                    .background(model.selectedReason == "custom" && !model.settingsVisible ? Color.white.opacity(0.8) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)
                Spacer(minLength: 18)
                Button {
                    model.settingsVisible.toggle()
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text(model.text("设置", "Settings"))
                        Spacer()
                        if !model.ready { Circle().fill(Color.orange.opacity(0.8)).frame(width: 7, height: 7) }
                    }.font(.system(size: 13, weight: .medium)).padding(12)
                }.buttonStyle(.plain)
                Text(model.hotkeyAvailable ? model.text("⌃ ⌥ Q  快速离席", "⌃ ⌥ Q  Quick away") : model.text("快捷键已被占用，请使用菜单栏", "Shortcut in use. Use the menu bar."))
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 9)
            }.padding(22).frame(width: model.language == "en" ? 276 : 248).background(paper)
            Rectangle().fill(ink.opacity(0.08)).frame(width: 1)
            VStack(spacing: 0) {
                if model.settingsVisible {
                    SettingsView(model: model)
                } else {
                    HStack {
                        if model.selectedReason == "custom" {
                            Menu {
                                ForEach(model.reasons, id: \.self) { reason in
                                    Button(model.characterName(reason)) { model.setCustomCharacter(reason) }
                                }
                            } label: {
                                Text(model.characterName(model.customCharacter))
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .menuStyle(.borderlessButton).fixedSize()
                            .accessibilityLabel(model.text("选择角色", "Choose character"))
                        } else {
                            Text(model.characterName(model.selectedReason)).font(.system(size: 14, weight: .medium))
                        }
                        Spacer()
                        Button { model.showPreview?() } label: { Label(model.text("全屏预览", "Full-screen preview"), systemImage: "arrow.up.left.and.arrow.down.right") }
                            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                    }.padding(.bottom, 17)
                    CharacterScene(session: model.sceneSession)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.06), lineWidth: 1))
                    if model.selectedReason == "custom" {
                        HStack(spacing: 12) {
                            Text(model.text("理由", "Reason")).font(.system(size: 13)).foregroundStyle(.secondary)
                            TextField(model.text("例如：出门遛狗", "e.g. Walking the dog"), text: Binding(get: { model.customReason }, set: { model.setCustomReason($0) }))
                                .textFieldStyle(.roundedBorder).font(.system(size: 14))
                                .accessibilityLabel(model.text("自定义离席理由", "Custom away reason"))
                            Text("\(model.customReason.count)/40").font(.system(size: 11)).monospacedDigit().foregroundStyle(.secondary)
                        }.padding(.top, 16)
                    }
                    HStack(spacing: 10) {
                        if model.selectedReason != "offwork" {
                            Text(model.text("返回时间", "Return in")).font(.system(size: 13)).foregroundStyle(.secondary)
                            Spacer()
                            ForEach([5, 15, 30, 60], id: \.self) { minutes in
                                Button { model.setDuration(minutes) } label: {
                                    Text("\(minutes)").font(.system(size: 13, weight: .medium, design: .rounded))
                                        .frame(width: 36, height: 30)
                                        .background(model.duration == minutes ? accent.opacity(0.12) : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                            DurationInput(model: model, reason: model.selectedReason).id(model.selectedReason)
                        } else {
                            Label(model.text("展示 5 分钟后允许熄屏", "Display may sleep after 5 minutes"), systemImage: "moon.zzz").font(.system(size: 13)).foregroundStyle(.secondary)
                            Spacer()
                        }
                    }.frame(height: 48).padding(.top, 12)
                    HStack {
                        if model.activeSession != nil {
                            Button(model.text("结束离席", "End away")) { model.endAway() }.buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.startAway() } label: {
                            Label(model.starting ? model.text("正在启动…", "Starting…") : model.text("开始离席并锁屏", "Start & lock"), systemImage: "lock.fill")
                                .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 17).padding(.vertical, 13)
                                .foregroundStyle(.white).background(accent).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).keyboardShortcut(.return, modifiers: .command).disabled(!model.canStart).opacity(model.canStart ? 1 : 0.45)
                    }.padding(.top, 15)
                }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white)
        }.foregroundStyle(ink).frame(minWidth: 1000, minHeight: 672)
            .alert("QScreen", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button(model.text("好", "OK")) { model.error = nil }
            } message: { Text(model.error ?? "") }
    }
}

struct SettingsView: View {
    @ObservedObject var model: QScreenModel
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack {
                Text(model.text("设置", "Settings")).font(.system(size: 24, weight: .semibold))
                Spacer()
                LanguageSwitch(model: model)
                if model.ready { Label(model.text("已就绪", "Ready"), systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(accent) }
            }
            VStack(spacing: 0) {
                setupRow(model.text("安装屏保", "Install screen saver"), done: model.installed) {
                    Button(model.installed ? model.text("更新", "Update") : model.text("安装", "Install")) { model.installSaver() }
                }
                Divider().padding(.leading, 35)
                setupRow(model.text("在系统中选择 QScreen", "Select QScreen in System Settings"), done: model.selectedInSystem) {
                    HStack(spacing: 10) {
                        Button(model.text("打开设置", "Open settings")) { model.openScreenSaverSettings() }
                        if !model.selectedInSystem { Button(model.text("已选好", "I've selected it")) { model.confirmSelection() } }
                    }
                }
                Divider().padding(.leading, 35)
                setupRow(model.text("退出屏保时立即要求密码", "Require password immediately"), done: model.lockPolicy == .immediate) {
                    HStack(spacing: 10) {
                        if model.lockPolicy != .immediate {
                            Button(model.text("重新检查", "Recheck")) { model.refreshLockPolicy() }
                        }
                        Button(model.text("打开锁屏设置", "Lock Screen settings")) { model.openLockSettings() }
                    }
                }
            }.padding(15).background(paper).clipShape(RoundedRectangle(cornerRadius: 16))
            Text(model.text("墙纸 → Screen Saver… → Custom → QScreen。选中后回到这里点「已选好」。系统锁屏设置中，启动屏保后要求密码须设为「立即」。", "Wallpaper → Screen Saver… → Custom → QScreen. Then confirm your selection here. In Lock Screen settings, require a password immediately after the screen saver starts."))
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                Text(model.text("屏幕展示", "Display")).font(.system(size: 14, weight: .semibold))
                HStack {
                    Text(model.text("倒计时结束后继续亮屏", "Keep display on after countdown")).font(.system(size: 13))
                    Spacer()
                    Picker(model.text("倒计时结束后继续亮屏", "Keep display on after countdown"), selection: Binding(get: { model.overtime }, set: { model.setOvertime($0) })) {
                        Text(model.text("立即允许熄屏", "Allow sleep immediately")).tag(0)
                        Text(model.minutesText(5)).tag(5)
                        Text(model.minutesText(15)).tag(15)
                        Text(model.minutesText(30)).tag(30)
                    }.labelsHidden().frame(width: model.language == "en" ? 185 : 145)
                }
                Text(model.text("下班状态展示 5 分钟；普通锁屏的「暂时离开」展示 15 分钟。之后由系统决定何时熄屏。", "Off for the day stays on for 5 minutes; a screen saver with no return time stays on for 15 minutes. The system then controls display sleep."))
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack {
                Text("QScreen " + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""))
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button(model.text("退出 QScreen", "Quit QScreen")) { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func setupRow<Content: View>(_ title: String, done: Bool, @ViewBuilder action: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle").foregroundStyle(done ? accent : .secondary).font(.system(size: 18))
            Text(title).font(.system(size: 13, weight: .medium))
            Spacer()
            action().controlSize(.small)
        }.frame(height: 58)
    }
}

struct QuickPicker: View {
    @ObservedObject var model: QScreenModel
    @State private var hoveredReason: String?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                ForEach(model.reasons, id: \.self) { reason in
                    HStack(spacing: 0) {
                        Button { model.chooseAndStart(reason) } label: {
                            HStack(spacing: 12) {
                                CharacterScene(session: QSSession(reason, 15, Date().timeIntervalSince1970) as NSDictionary, characterOnly: true, animated: false)
                                    .frame(width: 38, height: 38)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                Text(model.reasonTitle(reason))
                                    .font(.system(size: 13, weight: .medium))
                                Spacer(minLength: 8)
                            }
                            .frame(maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(model.text("选择并锁屏", "Select and lock"))
                        .disabled(model.starting)
                        if reason != "offwork" {
                            Menu {
                                ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) { value in
                                    Button {
                                        model.setDuration(value, reason: reason)
                                    } label: {
                                        if model.durations[reason] == value {
                                            Label(model.minutesText(value), systemImage: "checkmark")
                                        } else {
                                            Text(model.minutesText(value))
                                        }
                                    }
                                }
                            } label: {
                                Text(model.minutesText(model.durations[reason] ?? 15))
                                    .font(.system(size: 12)).monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                            .menuStyle(.borderlessButton)
                            .fixedSize().frame(width: 76, height: 36)
                            .accessibilityLabel(model.text("\(model.reasonTitle(reason))时长", "Duration for \(model.reasonTitle(reason))"))
                        } else {
                            Text(model.text("无倒计时", "No timer")).font(.system(size: 12)).foregroundStyle(.tertiary)
                                .frame(width: 76)
                        }
                    }
                    .padding(.horizontal, 9)
                    .frame(height: 52)
                    .background(hoveredReason == reason ? Color.primary.opacity(0.055) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .onHover { inside in hoveredReason = inside ? reason : nil }
                }
                Button { model.openCustomEditor() } label: {
                    HStack(spacing: 12) {
                        CharacterScene(session: model.customSceneSession, characterOnly: true, animated: false)
                            .frame(width: 38, height: 38).clipShape(RoundedRectangle(cornerRadius: 10))
                        Text(model.text("自定义…", "Custom…")).font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "square.and.pencil").foregroundStyle(.secondary).padding(.trailing, 10)
                    }
                    .padding(.horizontal, 9).frame(height: 52)
                    .background(hoveredReason == "custom" ? Color.primary.opacity(0.055) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 11))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(model.starting)
                .onHover { inside in hoveredReason = inside ? "custom" : nil }
            }
            .padding(8)
            Divider().padding(.horizontal, 17)
            HStack {
                Button {
                    if !model.ready { model.settingsVisible = true }
                    model.dismissPopover?()
                    model.showWindow?()
                } label: {
                    Label(model.ready ? "QScreen" : model.text("完成设置", "Finish setup"), systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.plain)
                Spacer()
                LanguageSwitch(model: model)
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .frame(height: 43)
        }
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct LanguageSwitch: View {
    @ObservedObject var model: QScreenModel

    var body: some View {
        Picker("Language / 语言", selection: Binding(get: { model.language }, set: { model.setLanguage($0) })) {
            Text("中文").tag("zh")
            Text("English").tag("en")
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(width: 126)
    }
}

struct DurationInput: View {
    @ObservedObject var model: QScreenModel
    let reason: String

    var body: some View {
        HStack(spacing: 6) {
            TextField(model.text("分钟", "Minutes"), value: Binding(get: { model.durations[reason] ?? QSDefaultMinutes(reason) }, set: { model.setDuration($0, reason: reason) }), format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .monospacedDigit().font(.system(size: 13))
                .frame(width: 48)
                .help(model.text("1–480 分钟", "1–480 minutes"))
                .accessibilityIdentifier("duration-input")
            Text(model.text("分钟", "min")).font(.system(size: 13)).foregroundStyle(.secondary)
            Stepper(model.text("分钟", "Minutes"), value: Binding(get: { model.durations[reason] ?? QSDefaultMinutes(reason) }, set: { model.setDuration($0, reason: reason) }), in: 1...480)
                .labelsHidden().fixedSize()
        }.fixedSize()
    }
}
