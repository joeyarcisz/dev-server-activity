import AppKit
import SwiftUI

enum ActivityTheme {
    static let canvas = adaptive(light: 0xFAF9F6, dark: 0x191A1C)
    static let well = adaptive(light: 0xF0EFEB, dark: 0x232427)
    static let accent = adaptive(light: 0xB53730, dark: 0xF4776A)
    static let stop = Color(red: 0.72, green: 0.20, blue: 0.17)
    static let rule = Color.primary.opacity(0.10)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let value = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((value >> 16) & 255) / 255,
                green: CGFloat((value >> 8) & 255) / 255,
                blue: CGFloat(value & 255) / 255,
                alpha: 1
            )
        })
    }
}
