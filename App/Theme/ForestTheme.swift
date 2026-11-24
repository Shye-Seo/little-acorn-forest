import SwiftUI
import AcornForestCore

#if canImport(UIKit)
import UIKit
#endif

/// 동화책 느낌을 만드는 색과 글꼴. 화면마다 색을 새로 만들지 않고 여기서만 꺼내 쓴다.
enum ForestPalette {
    static let parchment = Color(hex: 0xFDF8EE)
    static let parchmentDeep = Color(hex: 0xF3E7D3)
    static let pageEdge = Color(hex: 0xE7D9BF)
    static let sage = Color(hex: 0x5D7A58)
    static let sageDeep = Color(hex: 0x3F573D)
    static let sageLight = Color(hex: 0xA8BDA3)
    static let terracotta = Color(hex: 0xC97B5D)
    static let terracottaDeep = Color(hex: 0xA25C43)
    static let ink = Color(hex: 0x3B372E)
    static let inkSoft = Color(hex: 0x6E6555)
    static let butter = Color(hex: 0xF2DFAF)
    static let honey = Color(hex: 0xE0B15C)
    static let berry = Color(hex: 0xC96A78)
    static let chestnut = Color(hex: 0x8C5A3C)
    static let dew = Color(hex: 0x7FA6C9)
    static let starmoss = Color(hex: 0x8FBFA8)
    static let moonflake = Color(hex: 0xB3A3D4)
    static let night = Color(hex: 0x2B3247)
    static let moonlight = Color(hex: 0xF1E9C9)
    static let nightSage = Color(hex: 0x4A5F55)
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

extension Font {
    static func story(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    static func storyBody(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif)
    }

    static func label(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Ingredient {
    var tint: Color {
        switch self {
        case .dewberry: return ForestPalette.dew
        case .fireflyNectar: return ForestPalette.honey
        case .starMossShroom: return ForestPalette.starmoss
        case .moonflakeSpice: return ForestPalette.moonflake
        case .moonlitDew: return ForestPalette.moonlight
        case .cherryHoney: return ForestPalette.berry
        case .mapleSap: return ForestPalette.chestnut
        case .snowBlossom: return ForestPalette.dew
        }
    }
}

extension CharacterID {
    var tint: Color {
        switch self {
        case .tori: return ForestPalette.chestnut
        case .songi: return ForestPalette.sageDeep
        case .mong: return ForestPalette.honey
        case .rubi: return ForestPalette.terracotta
        case .luna: return ForestPalette.moonflake
        case .coco: return ForestPalette.dew
        }
    }
}

extension CabinStyle {
    var wallColor: Color { Color(hex: wallHex) }
    var lampColor: Color { Color(hex: lampHex) }
}

/// 양피지 질감의 배경. 위아래로 아주 옅은 그라데이션과 종이 알갱이를 얹는다.
struct ParchmentBackground: View {
    var warm: Bool = true

    var body: some View {
        ZStack {
            ForestPalette.parchment
            LinearGradient(
                colors: [
                    warm ? ForestPalette.parchment : ForestPalette.parchment.opacity(0.98),
                    ForestPalette.parchmentDeep
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Canvas { context, size in
                for index in 0..<64 {
                    let x = size.width * grain(index * 37 + 11)
                    let y = size.height * grain(index * 53 + 29)
                    let radius = CGFloat(0.8 + Double(index % 3) * 0.5)
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(Path(ellipseIn: rect), with: .color(ForestPalette.inkSoft.opacity(0.07)))
                }
            }
        }
        .ignoresSafeArea()
    }

    private func grain(_ seed: Int) -> CGFloat {
        let value = Double((seed % 101)) / 101.0
        return CGFloat(value)
    }
}

/// 페이지 한 장 같은 카드.
struct StorybookCard: ViewModifier {
    var padding: CGFloat = 18
    var corner: CGFloat = 24

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(ForestPalette.parchment.opacity(0.93))
                    .shadow(color: ForestPalette.ink.opacity(0.10), radius: 12, x: 0, y: 7)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(ForestPalette.pageEdge, lineWidth: 1)
            )
    }
}

extension View {
    func storybookCard(padding: CGFloat = 18, corner: CGFloat = 24) -> some View {
        modifier(StorybookCard(padding: padding, corner: corner))
    }
}

struct StorybookButtonStyle: ButtonStyle {
    var tint: Color = ForestPalette.sage

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.story(17, weight: .semibold))
            .foregroundStyle(ForestPalette.parchment)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tint.opacity(configuration.isPressed ? 0.78 : 1))
                    .shadow(color: tint.opacity(0.25), radius: 6, x: 0, y: 3)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct QuietButtonStyle: ButtonStyle {
    var tint: Color = ForestPalette.sage

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.story(15, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(ForestPalette.parchment.opacity(0.85))
                    .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// 손글씨 같은 구분선.
struct StitchedDivider: View {
    var color: Color = ForestPalette.pageEdge

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            var x: CGFloat = 0
            while x < size.width {
                path.addLine(to: CGPoint(x: x + 6, y: size.height / 2))
                x += 12
            }
            context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .frame(height: 1)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.label(11))
            .tracking(1.4)
            .foregroundStyle(ForestPalette.inkSoft)
            .textCase(.uppercase)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.story(14))
            .foregroundStyle(ForestPalette.parchment)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                Capsule().fill(ForestPalette.ink.opacity(0.92))
            )
            .padding(.horizontal, 24)
    }
}

enum Haptics {
    static func tap() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    static func success() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    static func warning() {
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        #endif
    }
}
