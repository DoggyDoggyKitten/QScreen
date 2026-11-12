import SwiftUI

// Every scene uses this one artboard, window frame and typography. Only its content changes.
enum SetupGuideFocus: Int, CaseIterable {
    case wallpaper, custom, qscreen, done, password
}

struct SetupIllustration: NSViewRepresentable {
    let focus: SetupGuideFocus
    func makeNSView(context: Context) -> SetupIllustrationView { SetupIllustrationView(frame: .zero) }
    func updateNSView(_ view: SetupIllustrationView, context: Context) {
        view.focus = focus
        view.needsDisplay = true
    }
}

final class SetupIllustrationView: NSView {
    static let artboard = NSSize(width: 680, height: 328)
    var focus: SetupGuideFocus = .wallpaper
    override var isFlipped: Bool { true }
    private let ink = NSColor(srgbRed: 0.23, green: 0.28, blue: 0.25, alpha: 1)
    private let muted = NSColor(srgbRed: 0.53, green: 0.57, blue: 0.54, alpha: 1)
    private let line = NSColor(srgbRed: 0.85, green: 0.87, blue: 0.83, alpha: 1)
    private let green = NSColor(srgbRed: 0.34, green: 0.46, blue: 0.36, alpha: 1)
    private let pale = NSColor(srgbRed: 0.93, green: 0.96, blue: 0.90, alpha: 1)
    private let paper = NSColor(srgbRed: 0.98, green: 0.98, blue: 0.96, alpha: 1)
    private let windowFrame = NSRect(x: 18, y: 14, width: 584, height: 300)
    private var isSheet: Bool { focus == .custom || focus == .qscreen || focus == .done }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else { return }
        let scale = min(bounds.width / Self.artboard.width, bounds.height / Self.artboard.height)
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: (bounds.width-Self.artboard.width*scale)/2, yBy: (bounds.height-Self.artboard.height*scale)/2)
        transform.scale(by: scale)
        transform.concat()
        box(NSRect(x: 0, y: 0, width: 680, height: 328), radius: 20, fill: paper)
        drawWindow()
        if focus == .password { drawPassword() }
        else { drawWallpaper() }
        if isSheet { drawScreenSaver() }
        drawGuide()
        NSGraphicsContext.restoreGraphicsState()
    }

    private func box(_ rect: NSRect, radius: CGFloat = 8, fill: NSColor, border: NSColor? = nil, width: CGFloat = 1) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        fill.setFill(); path.fill()
        if let border { border.setStroke(); path.lineWidth = width; path.stroke() }
    }

    private func label(_ text: String, _ rect: NSRect, size: CGFloat = 11, weight: NSFont.Weight = .regular,
                       color: NSColor? = nil, centered: Bool = false) {
        let style = NSMutableParagraphStyle()
        style.alignment = centered ? .center : .left
        style.lineBreakMode = .byWordWrapping
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let descriptor = base.fontDescriptor.withDesign(.rounded)
        let font = descriptor.flatMap { NSFont(descriptor: $0, size: size) } ?? base
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color ?? ink, .paragraphStyle: style])
    }

    private func rule(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat) {
        let path = NSBezierPath(); path.move(to: NSPoint(x: x, y: y)); path.line(to: NSPoint(x: x+width, y: y))
        path.lineWidth = 0.7; line.setStroke(); path.stroke()
    }

    private func symbol(_ name: String, _ rect: NSRect, color: NSColor? = nil) {
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil) else { return }
        let tinted = NSImage(size: rect.size, flipped: true) { destination in
            image.draw(in: destination)
            (color ?? self.muted).setFill(); destination.fill(using: .sourceIn)
            return true
        }
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func control(_ text: String, _ rect: NSRect, selected: Bool = false, blue: Bool = false) {
        box(rect, radius: 6, fill: blue ? green : selected ? pale : paper,
            border: selected ? green : line, width: selected ? 1.7 : 0.8)
        label(text, NSRect(x: rect.minX+3, y: rect.midY-7, width: rect.width-6, height: 16),
              weight: selected || blue ? .medium : .regular, color: blue ? .white : ink, centered: true)
    }

    private func highlight(_ rect: NSRect) {
        box(rect.insetBy(dx: -4, dy: -4), radius: 9, fill: .clear, border: green, width: 2)
    }

    private func drawWindow() {
        box(windowFrame.offsetBy(dx: 0, dy: 3), radius: 14, fill: line.withAlphaComponent(0.30))
        box(windowFrame, radius: 14, fill: .white, border: line, width: 1.2)
        box(NSRect(x: 19, y: 15, width: 120, height: 298), radius: 13, fill: paper)
        NSColor.white.setFill(); NSRect(x: 127, y: 15, width: 13, height: 298).fill()
        for (index, color) in [NSColor(srgbRed: 0.90, green: 0.55, blue: 0.48, alpha: 1),
                               NSColor(srgbRed: 0.92, green: 0.77, blue: 0.46, alpha: 1),
                               NSColor(srgbRed: 0.63, green: 0.76, blue: 0.57, alpha: 1)].enumerated() {
            box(NSRect(x: 30+CGFloat(index)*14, y: 27, width: 8, height: 8), radius: 4, fill: color)
        }
        box(NSRect(x: 27, y: 49, width: 103, height: 23), radius: 7, fill: .white, border: line, width: 0.7)
        symbol("magnifyingglass", NSRect(x: 34, y: 55, width: 10, height: 10))
        label("Search", NSRect(x: 48, y: 53, width: 75, height: 17), size: 10, color: muted)
        let rows: [(String, String)] = [("wifi", "Wi-Fi"), ("gearshape", "General"), ("figure.arms.open", "Accessibility"),
            ("circle.lefthalf.filled", "Appearance"), ("menubar.dock.rectangle", "Desktop & Dock"),
            ("display", "Displays"), ("lock", "Lock Screen"), ("photo", "Wallpaper")]
        for (index, row) in rows.enumerated() {
            let y = 83+CGFloat(index)*27
            let selected = row.1 == (focus == .password ? "Lock Screen" : "Wallpaper")
            if selected { box(NSRect(x: 25, y: y-3, width: 108, height: 25), radius: 6, fill: pale) }
            box(NSRect(x: 32, y: y+1, width: 16, height: 16), radius: 5, fill: selected ? green : muted.withAlphaComponent(0.64))
            symbol(row.0, NSRect(x: 35, y: y+4, width: 10, height: 10), color: .white)
            label(row.1, NSRect(x: 54, y: y+1, width: 77, height: 17), size: 9.5, weight: selected ? .semibold : .regular)
        }
        symbol("chevron.left", NSRect(x: 153, y: 29, width: 9, height: 12))
        symbol("chevron.right", NSRect(x: 175, y: 29, width: 9, height: 12), color: line)
        label(focus == .password ? "Lock Screen" : "Wallpaper", NSRect(x: 200, y: 26, width: 300, height: 24), size: 15, weight: .semibold)
        rule(140, 56, 461)
    }

    // A drawn Golden Gate scene keeps the real preview's proportions without mixing photo scales.
    private func landscape(_ rect: NSRect, variant: Int = 0) {
        let sky = NSColor(srgbRed: variant == 0 ? 0.92 : 0.78, green: variant == 0 ? 0.81 : 0.86, blue: variant == 0 ? 0.65 : 0.88, alpha: 1)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).addClip()
        sky.setFill(); rect.fill()
        let water = NSRect(x: rect.minX, y: rect.minY+rect.height*0.62, width: rect.width, height: rect.height*0.38)
        NSColor(srgbRed: 0.66, green: 0.76, blue: 0.73, alpha: 1).setFill(); water.fill()
        let hill = NSBezierPath(); hill.move(to: NSPoint(x: rect.minX, y: rect.maxY))
        hill.line(to: NSPoint(x: rect.minX, y: rect.minY+rect.height*0.62))
        hill.curve(to: NSPoint(x: rect.maxX, y: rect.maxY), controlPoint1: NSPoint(x: rect.midX, y: rect.minY+rect.height*0.3), controlPoint2: NSPoint(x: rect.midX, y: rect.maxY))
        NSColor(srgbRed: 0.48, green: 0.60, blue: 0.47, alpha: 1).setFill(); hill.fill()
        if variant == 0 {
            let bridge = NSColor(srgbRed: 0.72, green: 0.42, blue: 0.29, alpha: 1)
            for x in [rect.minX+rect.width*0.65, rect.minX+rect.width*0.87] {
                box(NSRect(x: x, y: rect.minY+rect.height*0.16, width: 3, height: rect.height*0.62), radius: 1, fill: bridge)
            }
            let cable = NSBezierPath(); cable.move(to: NSPoint(x: rect.minX+rect.width*0.5, y: rect.minY+rect.height*0.5))
            cable.curve(to: NSPoint(x: rect.maxX+8, y: rect.minY+rect.height*0.43), controlPoint1: NSPoint(x: rect.midX, y: rect.minY), controlPoint2: NSPoint(x: rect.maxX, y: rect.minY))
            cable.lineWidth = 1.5; bridge.setStroke(); cable.stroke()
            box(NSRect(x: rect.minX+rect.width*0.5, y: rect.minY+rect.height*0.55, width: rect.width*0.55, height: 3), radius: 1, fill: bridge)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    private func toggle(_ x: CGFloat, _ y: CGFloat, on: Bool) {
        box(NSRect(x: x, y: y, width: 28, height: 16), radius: 8, fill: on ? green : line)
        box(NSRect(x: x+(on ? 13 : 2), y: y+2, width: 12, height: 12), radius: 6, fill: .white)
    }

    private func drawWallpaper() {
        landscape(NSRect(x: 153, y: 72, width: 126, height: 78))
        box(NSRect(x: 289, y: 72, width: 299, height: 78), fill: paper)
        label("Golden Gate Sunset", NSRect(x: 301, y: 83, width: 250, height: 20), size: 12, weight: .medium)
        rule(301, 110, 275)
        label("Show on all Spaces", NSRect(x: 301, y: 121, width: 225, height: 18))
        toggle(548, 120, on: true)
        control("Screen Saver…", NSRect(x: 341, y: 160, width: 107, height: 25), selected: focus == .wallpaper)
        control("Clock Appearance…", NSRect(x: 457, y: 160, width: 131, height: 25))
        rule(153, 199, 435)
        label("Dynamic Wallpapers", NSRect(x: 153, y: 211, width: 240, height: 18), weight: .semibold)
        label("Show All (35)", NSRect(x: 501, y: 212, width: 87, height: 17), size: 9, color: muted)
        for (index, name) in ["Golden Gate", "Tahoe", "Sequoia", "Macintosh"].enumerated() {
            let x = 153+CGFloat(index)*111
            landscape(NSRect(x: x, y: 236, width: 101, height: 48), variant: index % 2)
            label(name, NSRect(x: x, y: 289, width: 101, height: 15), size: 9, centered: true)
        }
    }

    private func drawScreenSaver() {
        box(windowFrame, radius: 14, fill: ink.withAlphaComponent(0.13))
        let sheet = NSRect(x: 194, y: 25, width: 340, height: 281)
        box(sheet.offsetBy(dx: 0, dy: 3), radius: 13, fill: ink.withAlphaComponent(0.08))
        box(sheet, radius: 13, fill: .white, border: line)
        box(NSRect(x: 322, y: 37, width: 84, height: 48), radius: 5, fill: pale)
        // Reuse the same vector frog in the native screen saver preview thumbnail.
        let scene = QSSceneView(frame: NSRect(x: 0, y: 0, width: 84, height: 48))
        scene.characterOnly = true
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform(); transform.translateX(by: 322, yBy: 37); transform.concat()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 84, height: 48), xRadius: 5, yRadius: 5).addClip()
        scene.draw(scene.bounds)
        NSGraphicsContext.restoreGraphicsState()
        box(NSRect(x: 206, y: 96, width: 316, height: 78), radius: 8, fill: paper)
        label("Start Screen Saver…", NSRect(x: 215, y: 106, width: 168, height: 17), size: 10)
        label("After 20 minutes  ⌃", NSRect(x: 405, y: 106, width: 108, height: 17), size: 10)
        rule(215, 132, 298)
        label("Use Screen Saver", NSRect(x: 215, y: 146, width: 128, height: 16), size: 10)
        radio("Automatic", NSPoint(x: 365, y: 152), selected: false)
        radio("Custom", NSPoint(x: 453, y: 152), selected: true)
        rule(194, 184, 340)
        label("Other", NSRect(x: 210, y: 194, width: 150, height: 18), size: 11, weight: .semibold)
        box(NSRect(x: 211, y: 216, width: 70, height: 40), radius: 5, fill: pale, border: green)
        label("Q", NSRect(x: 211, y: 220, width: 70, height: 30), size: 22, weight: .semibold, color: green, centered: true)
        label("QScreen", NSRect(x: 211, y: 259, width: 70, height: 15), size: 9, centered: true)
        box(NSRect(x: 525, y: 191, width: 4, height: 50), radius: 2, fill: line)
        rule(194, 278, 340)
        control("Done", NSRect(x: 470, y: 284, width: 52, height: 17), blue: true)
    }

    private func radio(_ title: String, _ center: NSPoint, selected: Bool) {
        box(NSRect(x: center.x-5, y: center.y-5, width: 10, height: 10), radius: 5, fill: selected ? green : line)
        if selected { box(NSRect(x: center.x-2, y: center.y-2, width: 4, height: 4), radius: 2, fill: .white) }
        label(title, NSRect(x: center.x+10, y: center.y-7, width: 65, height: 17), size: 10)
    }

    private func drawPassword() {
        box(NSRect(x: 153, y: 72, width: 435, height: 91), fill: paper)
        label("Turn display off when inactive", NSRect(x: 165, y: 84, width: 278, height: 18))
        label("For 10 minutes", NSRect(x: 462, y: 84, width: 100, height: 18), size: 10)
        symbol("chevron.up.chevron.down", NSRect(x: 569, y: 86, width: 7, height: 10))
        rule(165, 108, 411)
        label("Require password after screen saver begins\nor display is turned off", NSRect(x: 165, y: 119, width: 282, height: 34), size: 10.5)
        label("Immediately", NSRect(x: 467, y: 127, width: 100, height: 18), size: 11, weight: .medium, color: green)
        symbol("chevron.up.chevron.down", NSRect(x: 569, y: 130, width: 7, height: 10), color: green)
        box(NSRect(x: 153, y: 177, width: 435, height: 95), fill: paper)
        for (index, title) in ["Show your user name and photo", "Show password hints", "Show message when locked"].enumerated() {
            let y = 187+CGFloat(index)*29
            label(title, NSRect(x: 165, y: y, width: 300, height: 18))
            toggle(548, y, on: false)
            if index < 2 { rule(165, y+23, 411) }
        }
        label("When Switching User", NSRect(x: 153, y: 286, width: 300, height: 18), weight: .semibold)
    }

    private func drawGuide() {
        let target: NSPoint, character: String, rect: NSRect
        switch focus {
        case .wallpaper:
            rect = NSRect(x: 341, y: 160, width: 107, height: 25)
            target = NSPoint(x: 447, y: 178); character = "lunch"
        case .custom:
            rect = NSRect(x: 443, y: 140, width: 72, height: 23)
            target = NSPoint(x: 515, y: 153); character = "coffee"
        case .qscreen:
            rect = NSRect(x: 208, y: 213, width: 76, height: 59)
            target = NSPoint(x: 285, y: 234); character = "coffee"
        case .done:
            rect = NSRect(x: 467, y: 282, width: 58, height: 21)
            target = NSPoint(x: 528, y: 291); character = "coffee"
        case .password:
            rect = NSRect(x: 457, y: 118, width: 123, height: 33)
            target = NSPoint(x: 580, y: 140); character = "away"
        }
        highlight(rect)
        // Move the whole character next to the control; keep its pointing arm short.
        let origin = NSPoint(x: target.x+57, y: min(target.y-14, 265))
        QSSceneView.drawGuideCharacter(character, at: origin, pointingTo: target)
    }
}
