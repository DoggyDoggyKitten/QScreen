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
                                Text(QSReasonTitle(reason)).font(.system(size: 14, weight: .semibold))
                                Text(reason == "offwork" ? "下次见" : "\(model.durations[reason] ?? 15) 分钟")
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
                Spacer(minLength: 18)
                Button {
                    model.settingsVisible.toggle()
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("设置")
                        Spacer()
                        if !model.ready { Circle().fill(Color.orange.opacity(0.8)).frame(width: 7, height: 7) }
                    }.font(.system(size: 13, weight: .medium)).padding(12)
                }.buttonStyle(.plain)
                Text(model.hotkeyAvailable ? "⌃ ⌥ Q  快速离席" : "快捷键已被占用，请使用菜单栏")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 12).padding(.top, 9)
            }.padding(22).frame(width: 248).background(paper)
            Rectangle().fill(ink.opacity(0.08)).frame(width: 1)
            VStack(spacing: 0) {
                if model.settingsVisible {
                    SettingsView(model: model)
                } else {
                    HStack {
                        Text(QSCharacterName(model.selectedReason)).font(.system(size: 14, weight: .medium))
                        Spacer()
                        Button { model.showPreview?() } label: { Label("全屏预览", systemImage: "arrow.up.left.and.arrow.down.right") }
                            .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
                    }.padding(.bottom, 17)
                    CharacterScene(session: model.sceneSession)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .overlay(RoundedRectangle(cornerRadius: 22).stroke(ink.opacity(0.06), lineWidth: 1))
                    HStack(spacing: 10) {
                        if model.selectedReason != "offwork" {
                            Text("返回时间").font(.system(size: 13)).foregroundStyle(.secondary)
                            Spacer()
                            ForEach([5, 15, 30, 60], id: \.self) { minutes in
                                Button { model.setDuration(minutes) } label: {
                                    Text("\(minutes)").font(.system(size: 13, weight: .medium, design: .rounded))
                                        .frame(width: 36, height: 30)
                                        .background(model.duration == minutes ? accent.opacity(0.12) : Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }.buttonStyle(.plain)
                            }
                            Stepper(value: Binding(get: { model.duration }, set: { model.setDuration($0) }), in: 1...480) {
                                Text("\(model.duration) 分钟").monospacedDigit().font(.system(size: 13)).frame(width: 70)
                            }.fixedSize()
                        } else {
                            Label("展示 5 分钟后允许熄屏", systemImage: "moon.zzz").font(.system(size: 13)).foregroundStyle(.secondary)
                            Spacer()
                        }
                    }.frame(height: 48).padding(.top, 12)
                    HStack {
                        if model.activeSession != nil {
                            Button("结束离席") { model.endAway() }.buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { model.startAway() } label: {
                            Label("开始离席并锁屏", systemImage: "lock.fill")
                                .font(.system(size: 14, weight: .semibold)).padding(.horizontal, 17).padding(.vertical, 13)
                                .foregroundStyle(.white).background(accent).clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain).keyboardShortcut(.return, modifiers: .command)
                    }.padding(.top, 15)
                }
            }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.white)
        }.foregroundStyle(ink).frame(minWidth: 1000, minHeight: 672)
            .alert("QScreen", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("好") { model.error = nil }
            } message: { Text(model.error ?? "") }
    }
}

struct SettingsView: View {
    @ObservedObject var model: QScreenModel
    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack {
                Text("设置").font(.system(size: 24, weight: .semibold))
                Spacer()
                if model.ready { Label("已就绪", systemImage: "checkmark.circle.fill").font(.system(size: 12)).foregroundStyle(accent) }
            }
            VStack(spacing: 0) {
                setupRow("安装屏保", done: model.installed) {
                    Button(model.installed ? "更新" : "安装") { model.installSaver() }
                }
                Divider().padding(.leading, 35)
                setupRow("在系统中选择 QScreen", done: model.selectedInSystem) {
                    HStack(spacing: 10) {
                        Button("打开设置") { model.openScreenSaverSettings() }
                        if !model.selectedInSystem { Button("已选好") { model.confirmSelection() } }
                    }
                }
                Divider().padding(.leading, 35)
                setupRow("允许一键锁屏", done: model.trusted) {
                    Button(model.trusted ? "已授权" : "授权") { model.requestAccessibility() }.disabled(model.trusted)
                }
            }.padding(15).background(paper).clipShape(RoundedRectangle(cornerRadius: 16))
            Text("在系统设置的「墙纸 → 屏幕保护程序」中选择 QScreen。辅助功能权限用于发送系统锁屏快捷键。")
                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                Text("屏幕展示").font(.system(size: 14, weight: .semibold))
                HStack {
                    Text("倒计时结束后继续亮屏").font(.system(size: 13))
                    Spacer()
                    Picker("倒计时结束后继续亮屏", selection: Binding(get: { model.overtime }, set: { model.setOvertime($0) })) {
                        Text("立即允许熄屏").tag(0)
                        Text("5 分钟").tag(5)
                        Text("15 分钟").tag(15)
                        Text("30 分钟").tag(30)
                    }.labelsHidden().frame(width: 145)
                }
                Text("下班状态展示 5 分钟；普通锁屏的「暂时离开」展示 15 分钟。之后由系统决定何时熄屏。")
                    .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack {
                Text("QScreen 0.1").font(.system(size: 11)).foregroundStyle(.tertiary)
                Spacer()
                Button("退出 QScreen") { NSApp.terminate(nil) }.buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(.secondary)
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
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("离席").font(.system(size: 18, weight: .semibold, design: .rounded))
                Spacer()
                Text("⌃ ⌥ Q").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(.bottom, 3)
            ForEach(model.reasons, id: \.self) { reason in
                HStack(spacing: 0) {
                    Button { model.chooseAndStart(reason) } label: {
                        HStack(spacing: 12) {
                            CharacterScene(session: QSSession(reason, 15, Date().timeIntervalSince1970) as NSDictionary, characterOnly: true, animated: false)
                                .frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 11))
                            Text(QSReasonTitle(reason)).font(.system(size: 13, weight: .medium))
                            Spacer()
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).help("选择并锁屏")
                    if reason != "offwork" {
                        Menu {
                            ForEach([5, 10, 15, 30, 45, 60, 90, 120], id: \.self) { value in
                                Button("\(value) 分钟") { model.setDuration(value, reason: reason) }
                            }
                        } label: {
                            Text("\(model.durations[reason] ?? 15) 分钟").font(.system(size: 12)).monospacedDigit()
                        }.menuStyle(.borderlessButton).fixedSize().frame(width: 85)
                    } else {
                        Text("下次见").font(.system(size: 12)).foregroundStyle(.secondary).padding(.trailing, 8)
                    }
                }.padding(8).background(Color.white.opacity(0.8)).clipShape(RoundedRectangle(cornerRadius: 13))
            }
            Divider().padding(.top, 2)
            HStack {
                Button { model.dismissPopover?(); model.showWindow?() } label: { Label("打开 QScreen", systemImage: "macwindow") }
                Spacer()
                if !model.ready {
                    Button("完成设置") { model.settingsVisible = true; model.dismissPopover?(); model.showWindow?() }
                } else {
                    Image(systemName: "lock.fill").foregroundStyle(accent)
                }
            }.font(.system(size: 11)).buttonStyle(.plain).padding(.top, 3)
        }.padding(18).frame(width: 356).background(paper).foregroundStyle(ink)
    }
}

