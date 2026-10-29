import Foundation
import AppKit

enum AppResources {
    static let bundle: Bundle = {
        // SwiftPM's generated accessor looks beside the executable or in the
        // checkout. Native .app builds keep their resources in Contents/Resources.
        if let url = Bundle.main.url(forResource: "GuitarJim_GuitarPractice", withExtension: "bundle"),
           let packaged = Bundle(url: url) {
            return packaged
        }
        return Bundle.module
    }()
    static let logo: NSImage = {
        if let url = bundle.url(forResource: "jimmy-page-logo", withExtension: "png"),
           let image = NSImage(contentsOf: url) { return image }
        return NSImage(systemSymbolName: "guitars", accessibilityDescription: "Guitar Jim") ?? NSImage()
    }()
    static let appIcon: NSImage = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: url) { return icon }
        return logo
    }()
    static let menuBarIcon = makeMenuBarIcon(recording: false)
    static let recordingMenuBarIcon = makeMenuBarIcon(recording: true)

    private static func makeMenuBarIcon(recording: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 20), flipped: false) { rect in
            logo.draw(in: rect)
            if recording {
                let badge = NSBezierPath(ovalIn: NSRect(x: 13, y: 0, width: 7, height: 7))
                NSColor.systemRed.setFill(); badge.fill()
                NSColor.windowBackgroundColor.setStroke(); badge.lineWidth = 1; badge.stroke()
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
