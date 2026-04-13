import SwiftUI

/// Shared rhyme-label color generator used across all views.
/// Uses an autumn palette — warm oranges, reds, golds, rusts, and
/// deep greens — with golden-angle spacing to keep adjacent labels distinct.
enum RhymeLabelColors {
    /// Curated autumn hues (HSB hue values):
    /// burnt orange, crimson, gold, rust, olive, burgundy,
    /// amber, sienna, sage, copper, maroon, mustard
    private static let palette: [Color] = [
        Color(hue: 0.07, saturation: 0.85, brightness: 0.85),  // burnt orange
        Color(hue: 0.97, saturation: 0.75, brightness: 0.75),  // crimson
        Color(hue: 0.13, saturation: 0.80, brightness: 0.90),  // gold
        Color(hue: 0.04, saturation: 0.80, brightness: 0.65),  // rust
        Color(hue: 0.22, saturation: 0.55, brightness: 0.55),  // olive
        Color(hue: 0.95, saturation: 0.70, brightness: 0.55),  // burgundy
        Color(hue: 0.10, saturation: 0.90, brightness: 0.95),  // amber
        Color(hue: 0.05, saturation: 0.65, brightness: 0.55),  // sienna
        Color(hue: 0.28, saturation: 0.40, brightness: 0.60),  // sage
        Color(hue: 0.06, saturation: 0.75, brightness: 0.75),  // copper
        Color(hue: 0.96, saturation: 0.80, brightness: 0.45),  // maroon
        Color(hue: 0.12, saturation: 0.85, brightness: 0.80),  // mustard
    ]

    /// Golden angle for index spacing — ensures consecutive labels
    /// pick from well-separated positions in the palette.
    private static let goldenAngle = 0.381966011250105

    /// Return a deterministic, well-spaced autumn color for a given rhyme label.
    static func color(for label: String) -> Color {
        guard let scalar = label.unicodeScalars.first,
              scalar.value >= 65 /* A */ else { return .gray }

        let index = Int(scalar.value - 65)  // A=0, B=1, …

        // Golden-angle jump through the palette so A/B/C are never neighbours
        let paletteIndex = Int((Double(index) * goldenAngle * Double(palette.count))
            .truncatingRemainder(dividingBy: Double(palette.count)))

        return palette[abs(paletteIndex) % palette.count]
    }
}
