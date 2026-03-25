import SwiftUI

/// Floating panel showing a visual rhyme connection map
struct RhymeMapPanel: View {
    @ObservedObject var vm: LyricViewModel

    private let labelColors: [String: Color] = [
        "A": .orange, "B": .cyan, "C": .purple, "D": .pink,
        "E": .green, "F": .yellow, "G": .mint, "H": .indigo,
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Rhyme Map")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary.opacity(0.7))

            if vm.rhymeConnections.isEmpty {
                Text("Write at least 2 lines to see connections")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            } else {
                // Mini line map with connections
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // Connection arcs
                        Canvas { context, size in
                            let lineHeight: CGFloat = 24
                            let labelX: CGFloat = 12
                            let arcStartX: CGFloat = 28

                            for connection in vm.rhymeConnections {
                                let fromY = CGFloat(connection.from) * lineHeight + lineHeight / 2
                                let toY = CGFloat(connection.to) * lineHeight + lineHeight / 2
                                let color = labelColors[connection.label] ?? .gray

                                // Draw arc
                                let midY = (fromY + toY) / 2
                                let arcWidth = min(40, CGFloat(abs(connection.to - connection.from)) * 8 + 12)
                                var path = Path()
                                path.move(to: CGPoint(x: arcStartX, y: fromY))
                                path.addCurve(
                                    to: CGPoint(x: arcStartX, y: toY),
                                    control1: CGPoint(x: arcStartX + arcWidth, y: fromY + (midY - fromY) * 0.3),
                                    control2: CGPoint(x: arcStartX + arcWidth, y: toY - (toY - midY) * 0.3)
                                )

                                context.stroke(
                                    path,
                                    with: .color(color.opacity(0.5)),
                                    lineWidth: 1.5
                                )

                                // Dots at endpoints
                                let dotSize: CGFloat = 4
                                context.fill(
                                    Path(ellipseIn: CGRect(x: arcStartX - dotSize/2, y: fromY - dotSize/2, width: dotSize, height: dotSize)),
                                    with: .color(color.opacity(0.7))
                                )
                                context.fill(
                                    Path(ellipseIn: CGRect(x: arcStartX - dotSize/2, y: toY - dotSize/2, width: dotSize, height: dotSize)),
                                    with: .color(color.opacity(0.7))
                                )
                            }
                        }
                        .frame(width: 80)

                        // Line labels
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(vm.lines.enumerated()), id: \.1.id) { index, line in
                                let text = line.text.trimmingCharacters(in: .whitespaces)
                                if !text.isEmpty {
                                    HStack(spacing: 6) {
                                        if let label = vm.rhymeLabels[safe: index] ?? nil {
                                            Text(label)
                                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                                .foregroundColor(labelColors[label] ?? .gray)
                                                .frame(width: 12, alignment: .center)
                                        } else {
                                            Text(" ")
                                                .frame(width: 12)
                                        }

                                        // Mini spacer for arc area
                                        Color.clear.frame(width: 50, height: 1)

                                        Text(text.prefix(20) + (text.count > 20 ? "..." : ""))
                                            .font(.system(size: 10))
                                            .foregroundColor(.primary.opacity(0.5))
                                            .lineLimit(1)
                                    }
                                    .frame(height: 24)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.secondary.opacity(0.1))
                )
        )
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
    }
}
