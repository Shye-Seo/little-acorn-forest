import SwiftUI
import AcornForestCore

/// 숲속 이웃의 초상. 이미지 파일 없이 Canvas로 직접 그린다.
struct CharacterPortrait: View {
    let character: CharacterID
    var size: CGFloat = 120
    var dimmed: Bool = false

    var body: some View {
        Canvas { context, canvasSize in
            CharacterArt.draw(character, in: context, size: canvasSize)
        }
        .frame(width: size, height: size)
        .opacity(dimmed ? 0.4 : 1)
        .accessibilityLabel(Text(character.name))
    }
}

/// 주인공 보리.
struct PlayerPortrait: View {
    var size: CGFloat = 120

    var body: some View {
        Canvas { context, canvasSize in
            CharacterArt.drawBori(in: context, size: canvasSize)
        }
        .frame(width: size, height: size)
        .accessibilityLabel(Text("보리"))
    }
}

enum CharacterArt {
    // MARK: - 공통

    private static func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x, y: y, width: width, height: height))
    }

    private static func triangle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Path {
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        path.addLine(to: c)
        path.closeSubpath()
        return path
    }

    private static func shadow(in context: GraphicsContext, w: CGFloat, h: CGFloat) {
        let rect = CGRect(x: w * 0.18, y: h * 0.85, width: w * 0.64, height: h * 0.06)
        context.fill(Path(ellipseIn: rect), with: .color(ForestPalette.sage.opacity(0.16)))
    }

    private static func eye(_ context: GraphicsContext, at point: CGPoint, radius: CGFloat, color: Color) {
        let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: rect), with: .color(color))
    }

    // MARK: - 이웃

    static func draw(_ character: CharacterID, in context: GraphicsContext, size: CGSize) {
        shadow(in: context, w: size.width, h: size.height)
        switch character {
        case .tori: drawTori(in: context, size: size)
        case .songi: drawSongi(in: context, size: size)
        case .mong: drawMong(in: context, size: size)
        case .rubi: drawRubi(in: context, size: size)
        case .luna: drawLuna(in: context, size: size)
        case .coco: drawCoco(in: context, size: size)
        }
    }

    private static func drawTori(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height

        // 꼬리
        context.fill(ellipse(w * 0.02, h * 0.28, w * 0.5, h * 0.5), with: .color(ForestPalette.chestnut.opacity(0.9)))
        context.fill(ellipse(w * 0.10, h * 0.36, w * 0.32, h * 0.3), with: .color(ForestPalette.butter.opacity(0.55)))

        // 몸통
        context.fill(ellipse(w * 0.24, h * 0.48, w * 0.54, h * 0.42), with: .color(ForestPalette.chestnut))
        context.fill(ellipse(w * 0.35, h * 0.58, w * 0.32, h * 0.26), with: .color(ForestPalette.butter.opacity(0.8)))

        // 귀
        context.fill(triangle(CGPoint(x: w * 0.31, y: h * 0.24),
                              CGPoint(x: w * 0.36, y: h * 0.08),
                              CGPoint(x: w * 0.44, y: h * 0.22)), with: .color(ForestPalette.chestnut))
        context.fill(triangle(CGPoint(x: w * 0.58, y: h * 0.22),
                              CGPoint(x: w * 0.66, y: h * 0.08),
                              CGPoint(x: w * 0.71, y: h * 0.25)), with: .color(ForestPalette.chestnut))

        // 머리
        context.fill(ellipse(w * 0.28, h * 0.16, w * 0.46, h * 0.36), with: .color(ForestPalette.chestnut))
        context.fill(ellipse(w * 0.38, h * 0.32, w * 0.26, h * 0.18), with: .color(ForestPalette.butter))

        eye(context, at: CGPoint(x: w * 0.41, y: h * 0.29), radius: w * 0.028, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.60, y: h * 0.29), radius: w * 0.028, color: ForestPalette.ink)
        // 볼
        context.fill(ellipse(w * 0.33, h * 0.33, w * 0.09, h * 0.05), with: .color(ForestPalette.berry.opacity(0.4)))
        context.fill(ellipse(w * 0.62, h * 0.33, w * 0.09, h * 0.05), with: .color(ForestPalette.berry.opacity(0.4)))
        // 코
        eye(context, at: CGPoint(x: w * 0.51, y: h * 0.37), radius: w * 0.022, color: ForestPalette.terracottaDeep)
    }

    private static func drawSongi(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let spikeColor = Color(hex: 0x7C6B53)

        // 가시
        for index in 0..<9 {
            let t = CGFloat(index) / 8.0
            let wave = CGFloat(sin(Double(t) * Double.pi))
            let baseX = w * (0.20 + 0.60 * t)
            let baseY = h * (0.52 - 0.10 * wave)
            context.fill(triangle(CGPoint(x: baseX - w * 0.06, y: baseY + h * 0.06),
                                  CGPoint(x: baseX, y: baseY - h * 0.12),
                                  CGPoint(x: baseX + w * 0.06, y: baseY + h * 0.06)),
                         with: .color(spikeColor))
        }

        // 몸통
        context.fill(ellipse(w * 0.18, h * 0.44, w * 0.64, h * 0.44), with: .color(spikeColor))
        // 얼굴
        context.fill(ellipse(w * 0.32, h * 0.50, w * 0.36, h * 0.30), with: .color(ForestPalette.butter))
        eye(context, at: CGPoint(x: w * 0.43, y: h * 0.61), radius: w * 0.022, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.57, y: h * 0.61), radius: w * 0.022, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.50, y: h * 0.67), radius: w * 0.018, color: ForestPalette.terracottaDeep)
        context.fill(ellipse(w * 0.37, h * 0.68, w * 0.08, h * 0.04), with: .color(ForestPalette.berry.opacity(0.35)))
        context.fill(ellipse(w * 0.55, h * 0.68, w * 0.08, h * 0.04), with: .color(ForestPalette.berry.opacity(0.35)))

        // 등에 걸린 잎
        var leaf = Path()
        leaf.move(to: CGPoint(x: w * 0.64, y: h * 0.46))
        leaf.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.36),
                          control: CGPoint(x: w * 0.76, y: h * 0.48))
        leaf.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.46),
                          control: CGPoint(x: w * 0.71, y: h * 0.38))
        context.fill(leaf, with: .color(ForestPalette.sage))
    }

    private static func drawMong(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let feather = Color(hex: 0xE7D9B6)

        // 날개
        context.fill(ellipse(w * 0.12, h * 0.38, w * 0.24, h * 0.42), with: .color(ForestPalette.sageLight))
        context.fill(ellipse(w * 0.64, h * 0.38, w * 0.24, h * 0.42), with: .color(ForestPalette.sageLight))

        // 몸통
        context.fill(ellipse(w * 0.22, h * 0.26, w * 0.56, h * 0.62), with: .color(feather))

        // 귀깃
        context.fill(triangle(CGPoint(x: w * 0.28, y: h * 0.30),
                              CGPoint(x: w * 0.26, y: h * 0.10),
                              CGPoint(x: w * 0.44, y: h * 0.24)), with: .color(ForestPalette.honey.opacity(0.8)))
        context.fill(triangle(CGPoint(x: w * 0.56, y: h * 0.24),
                              CGPoint(x: w * 0.74, y: h * 0.10),
                              CGPoint(x: w * 0.72, y: h * 0.30)), with: .color(ForestPalette.honey.opacity(0.8)))

        // 눈
        context.fill(ellipse(w * 0.33, h * 0.40, w * 0.15, h * 0.17), with: .color(ForestPalette.moonlight))
        context.fill(ellipse(w * 0.52, h * 0.40, w * 0.15, h * 0.17), with: .color(ForestPalette.moonlight))
        eye(context, at: CGPoint(x: w * 0.405, y: h * 0.485), radius: w * 0.032, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.595, y: h * 0.485), radius: w * 0.032, color: ForestPalette.ink)

        // 부리
        context.fill(triangle(CGPoint(x: w * 0.47, y: h * 0.55),
                              CGPoint(x: w * 0.53, y: h * 0.55),
                              CGPoint(x: w * 0.50, y: h * 0.61)), with: .color(ForestPalette.honey))

        // 목도리
        let scarf = Path(roundedRect: CGRect(x: w * 0.28, y: h * 0.68, width: w * 0.44, height: h * 0.10), cornerRadius: h * 0.05)
        context.fill(scarf, with: .color(ForestPalette.terracotta))
        context.fill(ellipse(w * 0.30, h * 0.80, w * 0.12, h * 0.08), with: .color(ForestPalette.terracotta))
    }

    private static func drawRubi(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let fur = Color(hex: 0xD98B5E)
        let cream = Color(hex: 0xF6E7CF)

        // 꼬리
        var tail = Path()
        tail.move(to: CGPoint(x: w * 0.70, y: h * 0.66))
        tail.addQuadCurve(to: CGPoint(x: w * 0.94, y: h * 0.40),
                          control: CGPoint(x: w * 0.98, y: h * 0.76))
        tail.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.56),
                          control: CGPoint(x: w * 0.86, y: h * 0.44))
        context.fill(tail, with: .color(fur))
        context.fill(ellipse(w * 0.84, h * 0.44, w * 0.10, h * 0.14), with: .color(cream.opacity(0.9)))

        // 몸통
        context.fill(ellipse(w * 0.24, h * 0.50, w * 0.52, h * 0.40), with: .color(fur))
        context.fill(ellipse(w * 0.36, h * 0.60, w * 0.28, h * 0.24), with: .color(cream.opacity(0.9)))

        // 귀
        context.fill(triangle(CGPoint(x: w * 0.30, y: h * 0.28),
                              CGPoint(x: w * 0.34, y: h * 0.08),
                              CGPoint(x: w * 0.46, y: h * 0.22)), with: .color(fur))
        context.fill(triangle(CGPoint(x: w * 0.56, y: h * 0.22),
                              CGPoint(x: w * 0.68, y: h * 0.08),
                              CGPoint(x: w * 0.72, y: h * 0.28)), with: .color(fur))

        // 머리
        context.fill(ellipse(w * 0.28, h * 0.18, w * 0.46, h * 0.36), with: .color(fur))
        // 주둥이
        context.fill(ellipse(w * 0.36, h * 0.34, w * 0.30, h * 0.20), with: .color(cream))
        eye(context, at: CGPoint(x: w * 0.41, y: h * 0.31), radius: w * 0.026, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.60, y: h * 0.31), radius: w * 0.026, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.505, y: h * 0.38), radius: w * 0.02, color: ForestPalette.ink)
    }

    private static func drawLuna(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let fur = Color(hex: 0xBFA98E)
        let cream = Color(hex: 0xF6EBDD)

        // 뿔
        for sign in [CGFloat(-1), CGFloat(1)] {
            let baseX = w * (0.5 + sign * 0.10)
            context.fill(triangle(CGPoint(x: baseX, y: h * 0.24),
                                  CGPoint(x: baseX + sign * w * 0.14, y: h * 0.04),
                                  CGPoint(x: baseX + sign * w * 0.03, y: h * 0.22)),
                         with: .color(ForestPalette.chestnut))
            context.fill(ellipse(baseX + sign * w * 0.11, h * 0.05, w * 0.07, h * 0.06),
                         with: .color(ForestPalette.moonlight))
        }

        // 몸통
        context.fill(ellipse(w * 0.22, h * 0.46, w * 0.56, h * 0.42), with: .color(fur))
        context.fill(ellipse(w * 0.34, h * 0.56, w * 0.32, h * 0.26), with: .color(cream.opacity(0.85)))

        // 귀
        context.fill(ellipse(w * 0.22, h * 0.22, w * 0.18, h * 0.16), with: .color(fur))
        context.fill(ellipse(w * 0.60, h * 0.22, w * 0.18, h * 0.16), with: .color(fur))

        // 머리
        context.fill(ellipse(w * 0.30, h * 0.20, w * 0.42, h * 0.34), with: .color(fur))
        context.fill(ellipse(w * 0.38, h * 0.36, w * 0.26, h * 0.16), with: .color(cream))
        eye(context, at: CGPoint(x: w * 0.42, y: h * 0.32), radius: w * 0.024, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.60, y: h * 0.32), radius: w * 0.024, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.51, y: h * 0.40), radius: w * 0.018, color: ForestPalette.ink)

        // 뿔에 쌓인 눈
        context.fill(ellipse(w * 0.30, h * 0.12, w * 0.16, h * 0.05), with: .color(.white.opacity(0.9)))
        context.fill(ellipse(w * 0.56, h * 0.10, w * 0.14, h * 0.045), with: .color(.white.opacity(0.85)))
    }

    private static func drawCoco(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let fur = Color(hex: 0x8A6A52)
        let belly = Color(hex: 0xE7CBAF)

        // 꼬리
        var tail = Path()
        tail.move(to: CGPoint(x: w * 0.66, y: h * 0.72))
        tail.addQuadCurve(to: CGPoint(x: w * 0.94, y: h * 0.60),
                          control: CGPoint(x: w * 0.90, y: h * 0.86))
        tail.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.64),
                          control: CGPoint(x: w * 0.86, y: h * 0.66))
        context.fill(tail, with: .color(fur))

        // 몸통
        context.fill(ellipse(w * 0.24, h * 0.48, w * 0.50, h * 0.40), with: .color(fur))
        context.fill(ellipse(w * 0.34, h * 0.58, w * 0.30, h * 0.24), with: .color(belly))

        // 귀
        context.fill(ellipse(w * 0.28, h * 0.22, w * 0.14, h * 0.12), with: .color(fur))
        context.fill(ellipse(w * 0.58, h * 0.22, w * 0.14, h * 0.12), with: .color(fur))

        // 머리
        context.fill(ellipse(w * 0.30, h * 0.20, w * 0.40, h * 0.32), with: .color(fur))
        context.fill(ellipse(w * 0.36, h * 0.34, w * 0.28, h * 0.18), with: .color(belly))
        eye(context, at: CGPoint(x: w * 0.41, y: h * 0.30), radius: w * 0.024, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.59, y: h * 0.30), radius: w * 0.024, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.50, y: h * 0.38), radius: w * 0.02, color: ForestPalette.ink)

        // 손에 쥔 조약돌
        context.fill(ellipse(w * 0.46, h * 0.66, w * 0.12, h * 0.10), with: .color(ForestPalette.sageLight))
    }

    // MARK: - 보리

    static func drawBori(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let skin = Color(hex: 0xF0CFB2)
        let hair = Color(hex: 0x4A3728)
        let coat = ForestPalette.sage

        shadow(in: context, w: w, h: h)

        // 코트
        let coatPath = Path(roundedRect: CGRect(x: w * 0.22, y: h * 0.52, width: w * 0.56, height: h * 0.38), cornerRadius: w * 0.14)
        context.fill(coatPath, with: .color(coat))
        // 목도리
        context.fill(ellipse(w * 0.30, h * 0.48, w * 0.40, h * 0.12), with: .color(ForestPalette.terracotta.opacity(0.9)))

        // 얼굴
        context.fill(ellipse(w * 0.30, h * 0.20, w * 0.40, h * 0.36), with: .color(skin))

        // 머리카락
        var hairPath = Path()
        hairPath.move(to: CGPoint(x: w * 0.26, y: h * 0.34))
        hairPath.addQuadCurve(to: CGPoint(x: w * 0.74, y: h * 0.34),
                              control: CGPoint(x: w * 0.50, y: h * 0.02))
        hairPath.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.24),
                              control: CGPoint(x: w * 0.70, y: h * 0.20))
        hairPath.addQuadCurve(to: CGPoint(x: w * 0.30, y: h * 0.24),
                              control: CGPoint(x: w * 0.50, y: h * 0.16))
        hairPath.closeSubpath()
        context.fill(hairPath, with: .color(hair))
        context.fill(ellipse(w * 0.24, h * 0.30, w * 0.10, h * 0.22), with: .color(hair))
        context.fill(ellipse(w * 0.66, h * 0.30, w * 0.10, h * 0.22), with: .color(hair))

        // 눈과 입
        eye(context, at: CGPoint(x: w * 0.42, y: h * 0.38), radius: w * 0.024, color: ForestPalette.ink)
        eye(context, at: CGPoint(x: w * 0.58, y: h * 0.38), radius: w * 0.024, color: ForestPalette.ink)
        context.fill(ellipse(w * 0.34, h * 0.42, w * 0.08, h * 0.04), with: .color(ForestPalette.berry.opacity(0.35)))
        context.fill(ellipse(w * 0.58, h * 0.42, w * 0.08, h * 0.04), with: .color(ForestPalette.berry.opacity(0.35)))
        var smile = Path()
        smile.move(to: CGPoint(x: w * 0.46, y: h * 0.46))
        smile.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.46), control: CGPoint(x: w * 0.50, y: h * 0.49))
        context.stroke(smile, with: .color(ForestPalette.terracottaDeep), lineWidth: max(1, w * 0.008))

        // 나뭇잎 머리핀
        var pin = Path()
        pin.move(to: CGPoint(x: w * 0.70, y: h * 0.24))
        pin.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.18), control: CGPoint(x: w * 0.80, y: h * 0.26))
        pin.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.24), control: CGPoint(x: w * 1.0, y: h * 0.14))
        context.fill(pin, with: .color(ForestPalette.sageLight))
    }
}
