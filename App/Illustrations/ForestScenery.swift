import SwiftUI
import AcornForestCore

/// 화면 아래쪽을 채우는 숲 풍경. 밤이면 색이 바뀐다.
struct ForestBackdrop: View {
    var night: Bool = false

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            let skyTop = night ? ForestPalette.night : ForestPalette.parchmentDeep
            let skyBottom = night ? ForestPalette.nightSage : ForestPalette.parchment
            context.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .linearGradient(
                    Gradient(colors: [skyTop, skyBottom]),
                    startPoint: CGPoint(x: w * 0.5, y: 0),
                    endPoint: CGPoint(x: w * 0.5, y: h)
                )
            )

            if night {
                for index in 0..<24 {
                    let x = w * (Double((index * 37) % 100) / 100.0)
                    let y = h * (Double((index * 53) % 55) / 100.0)
                    let radius = CGFloat(1 + index % 2)
                    context.fill(
                        Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                        with: .color(ForestPalette.moonlight.opacity(0.75))
                    )
                }
            }

            // 뒤쪽 언덕
            var farHill = Path()
            farHill.move(to: CGPoint(x: 0, y: h * 0.72))
            farHill.addQuadCurve(to: CGPoint(x: w, y: h * 0.70), control: CGPoint(x: w * 0.5, y: h * 0.58))
            farHill.addLine(to: CGPoint(x: w, y: h))
            farHill.addLine(to: CGPoint(x: 0, y: h))
            farHill.closeSubpath()
            context.fill(farHill, with: .color((night ? ForestPalette.nightSage : ForestPalette.sageLight).opacity(0.55)))

            // 앞쪽 땅
            var ground = Path()
            ground.move(to: CGPoint(x: 0, y: h * 0.82))
            ground.addQuadCurve(to: CGPoint(x: w, y: h * 0.80), control: CGPoint(x: w * 0.45, y: h * 0.74))
            ground.addLine(to: CGPoint(x: w, y: h))
            ground.addLine(to: CGPoint(x: 0, y: h))
            ground.closeSubpath()
            context.fill(ground, with: .color((night ? ForestPalette.nightSage : ForestPalette.sage).opacity(night ? 0.9 : 0.35)))

            // 양옆 나무
            drawTree(&context, x: w * 0.10, baseY: h * 0.86, height: h * 0.30, night: night)
            drawTree(&context, x: w * 0.90, baseY: h * 0.88, height: h * 0.34, night: night)
            drawTree(&context, x: w * 0.78, baseY: h * 0.84, height: h * 0.22, night: night)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func drawTree(_ context: inout GraphicsContext, x: CGFloat, baseY: CGFloat, height: CGFloat, night: Bool) {
        let trunk = CGRect(x: x - height * 0.03, y: baseY - height * 0.45, width: height * 0.06, height: height * 0.45)
        context.fill(Path(trunk), with: .color(ForestPalette.chestnut.opacity(night ? 0.8 : 0.5)))

        let canopy = night ? ForestPalette.nightSage : ForestPalette.sage
        context.fill(
            Path(ellipseIn: CGRect(x: x - height * 0.30, y: baseY - height * 0.95, width: height * 0.60, height: height * 0.62)),
            with: .color(canopy.opacity(0.85))
        )
        context.fill(
            Path(ellipseIn: CGRect(x: x - height * 0.18, y: baseY - height * 1.15, width: height * 0.42, height: height * 0.45)),
            with: .color(canopy.opacity(0.7))
        )
    }
}

/// 할머니의 오두막. 창문에 불이 켜져 있다.
struct CabinView: View {
    var glow: Bool = true
    var night: Bool = false

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // 굴뚝
            context.fill(Path(CGRect(x: w * 0.66, y: h * 0.10, width: w * 0.09, height: h * 0.26)),
                         with: .color(ForestPalette.terracottaDeep.opacity(0.8)))

            // 벽
            let wall = Path(roundedRect: CGRect(x: w * 0.18, y: h * 0.34, width: w * 0.60, height: h * 0.44), cornerRadius: w * 0.03)
            context.fill(wall, with: .color(Color(hex: 0xE9D6B4)))
            context.stroke(wall, with: .color(ForestPalette.chestnut.opacity(0.35)), lineWidth: 1.5)

            // 지붕
            var roof = Path()
            roof.move(to: CGPoint(x: w * 0.10, y: h * 0.36))
            roof.addLine(to: CGPoint(x: w * 0.48, y: h * 0.08))
            roof.addLine(to: CGPoint(x: w * 0.86, y: h * 0.36))
            roof.closeSubpath()
            context.fill(roof, with: .color(ForestPalette.terracotta))
            context.stroke(roof, with: .color(ForestPalette.terracottaDeep.opacity(0.5)), lineWidth: 1.5)

            // 문
            let door = Path(roundedRect: CGRect(x: w * 0.42, y: h * 0.56, width: w * 0.16, height: h * 0.22), cornerRadius: w * 0.02)
            context.fill(door, with: .color(ForestPalette.chestnut.opacity(0.85)))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.545, y: h * 0.67, width: w * 0.012, height: w * 0.012)),
                         with: .color(ForestPalette.honey))

            // 창문
            let window = Path(roundedRect: CGRect(x: w * 0.24, y: h * 0.52, width: w * 0.13, height: h * 0.13), cornerRadius: w * 0.015)
            context.fill(window, with: .color(glow ? ForestPalette.butter : ForestPalette.sageLight.opacity(0.5)))
            if glow {
                context.fill(
                    Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.46, width: w * 0.26, height: h * 0.26)),
                    with: .color(ForestPalette.butter.opacity(0.16))
                )
            }
            var cross = Path()
            cross.move(to: CGPoint(x: w * 0.305, y: h * 0.52))
            cross.addLine(to: CGPoint(x: w * 0.305, y: h * 0.65))
            cross.move(to: CGPoint(x: w * 0.24, y: h * 0.585))
            cross.addLine(to: CGPoint(x: w * 0.37, y: h * 0.585))
            context.stroke(cross, with: .color(ForestPalette.chestnut.opacity(0.5)), lineWidth: 1)

            // 굴뚝 연기
            for index in 0..<3 {
                let offset = CGFloat(index) * h * 0.06
                let radius = w * (0.03 + CGFloat(index) * 0.015)
                let smoke = CGRect(x: w * 0.69 - radius / 2, y: h * 0.02 - offset, width: radius, height: radius)
                context.fill(Path(ellipseIn: smoke), with: .color(ForestPalette.inkSoft.opacity(0.12)))
            }

            // 화분
            let pot = Path(roundedRect: CGRect(x: w * 0.80, y: h * 0.72, width: w * 0.08, height: h * 0.07), cornerRadius: w * 0.012)
            context.fill(pot, with: .color(ForestPalette.terracotta))
            context.fill(Path(ellipseIn: CGRect(x: w * 0.805, y: h * 0.66, width: w * 0.07, height: h * 0.07)),
                         with: .color(ForestPalette.sageLight))
        }
        .accessibilityLabel(Text("할머니의 오두막"))
    }
}

/// 반딧불이. 시간에 따라 천천히 떠다닌다.
struct FirefliesView: View {
    var count: Int = 16
    var tint: Color = ForestPalette.butter

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0..<count {
                    let seed = Double(index) * 1.73
                    let x = size.width * CGFloat(0.5 + 0.46 * sin(time * 0.32 + seed))
                    let y = size.height * CGFloat(0.5 + 0.42 * cos(time * 0.26 + seed * 1.31))
                    let pulse = 0.30 + 0.55 * (0.5 + 0.5 * sin(time * 1.6 + seed))
                    let radius = CGFloat(1.6 + Double(index % 3) * 0.7)

                    let halo = CGRect(x: x - radius * 3, y: y - radius * 3, width: radius * 6, height: radius * 6)
                    context.fill(Path(ellipseIn: halo), with: .color(tint.opacity(pulse * 0.16)))
                    let core = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
                    context.fill(Path(ellipseIn: core), with: .color(tint.opacity(pulse)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 바람에 흔들리는 나뭇잎 가루.
struct WindLeavesView: View {
    var count: Int = 10

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for index in 0..<count {
                    let speed = 0.06 + Double(index % 4) * 0.02
                    let drift = time * speed + Double(index) * 0.37
                    let x = size.width * CGFloat(drift.truncatingRemainder(dividingBy: 1.0))
                    let y = size.height * CGFloat(0.2 + 0.6 * (0.5 + 0.5 * sin(drift * 3.1 + Double(index))))
                    let sizeFactor = CGFloat(4 + index % 3)
                    var leaf = Path()
                    leaf.move(to: CGPoint(x: x, y: y))
                    leaf.addQuadCurve(to: CGPoint(x: x + sizeFactor, y: y + sizeFactor * 0.4),
                                      control: CGPoint(x: x + sizeFactor * 0.2, y: y - sizeFactor * 0.5))
                    leaf.addQuadCurve(to: CGPoint(x: x, y: y),
                                      control: CGPoint(x: x + sizeFactor * 0.6, y: y + sizeFactor * 0.7))
                    context.fill(leaf, with: .color(ForestPalette.sageLight.opacity(0.55)))
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 숲 지도 그림. 점선 길과 연못, 나무를 깐다.
struct ForestMapCanvas: View {
    let unlocked: Set<ForestLocation>

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height

            // 연못
            context.fill(
                Path(ellipseIn: CGRect(x: w * 0.60, y: h * 0.50, width: w * 0.30, height: h * 0.20)),
                with: .color(ForestPalette.sageLight.opacity(0.55))
            )
            context.stroke(
                Path(ellipseIn: CGRect(x: w * 0.60, y: h * 0.50, width: w * 0.30, height: h * 0.20)),
                with: .color(ForestPalette.sage.opacity(0.4)),
                lineWidth: 1
            )

            // 길
            let anchors = ForestLocation.allCases.map { $0.mapAnchor }
            var path = Path()
            if let first = anchors.first {
                path.move(to: CGPoint(x: w * CGFloat(first.x), y: h * CGFloat(first.y)))
                for anchor in anchors.dropFirst() {
                    path.addLine(to: CGPoint(x: w * CGFloat(anchor.x), y: h * CGFloat(anchor.y)))
                }
            }
            context.stroke(
                path,
                with: .color(ForestPalette.inkSoft.opacity(0.35)),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 8])
            )

            // 나무 몇 그루
            let trees: [(CGFloat, CGFloat, CGFloat)] = [
                (0.12, 0.62, 0.10), (0.86, 0.34, 0.08), (0.16, 0.14, 0.07), (0.62, 0.14, 0.06), (0.90, 0.88, 0.09)
            ]
            for tree in trees {
                let center = CGPoint(x: w * tree.0, y: h * tree.1)
                context.fill(
                    Path(ellipseIn: CGRect(x: center.x - w * tree.2 / 2, y: center.y - w * tree.2 / 2, width: w * tree.2, height: w * tree.2)),
                    with: .color(ForestPalette.sage.opacity(0.35))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// 솥단지. 불 조절 정도에 따라 색과 기포가 달라진다.
struct PotView: View {
    var heat: Double
    var phase: CookingHeatPhase
    var isCooking: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let w = size.width
                let h = size.height

                // 화덕
                context.fill(Path(ellipseIn: CGRect(x: w * 0.14, y: h * 0.72, width: w * 0.72, height: h * 0.16)),
                             with: .color(ForestPalette.chestnut.opacity(0.35)))

                // 불꽃
                let flameColor: Color
                switch phase {
                case .faint: flameColor = ForestPalette.honey.opacity(0.35)
                case .low: flameColor = ForestPalette.honey.opacity(0.6)
                case .ideal: flameColor = ForestPalette.terracotta
                case .high: flameColor = ForestPalette.terracottaDeep
                case .scorching: flameColor = ForestPalette.berry
                }
                for index in 0..<5 {
                    let offset = CGFloat(index) * w * 0.09
                    let flicker = CGFloat(0.6 + 0.4 * sin(time * 6 + Double(index)))
                    let flame = CGRect(x: w * 0.30 + offset, y: h * 0.70 - h * 0.10 * flicker,
                                       width: w * 0.07, height: h * 0.12 * flicker)
                    context.fill(Path(ellipseIn: flame), with: .color(flameColor.opacity(0.75)))
                }

                // 냄비
                let potBody = Path(roundedRect: CGRect(x: w * 0.20, y: h * 0.42, width: w * 0.60, height: h * 0.30), cornerRadius: w * 0.08)
                context.fill(potBody, with: .color(Color(hex: 0x5A5048)))
                context.fill(Path(ellipseIn: CGRect(x: w * 0.18, y: h * 0.38, width: w * 0.64, height: h * 0.12)),
                             with: .color(Color(hex: 0x6B6055)))
                context.fill(Path(ellipseIn: CGRect(x: w * 0.22, y: h * 0.40, width: w * 0.56, height: h * 0.08)),
                             with: .color(Color(hex: 0xD9A46B).opacity(0.9)))

                // 기포
                if isCooking {
                    for index in 0..<4 {
                        let bubbleTime = time * (1.0 + heat) + Double(index) * 1.4
                        let rise = CGFloat(bubbleTime.truncatingRemainder(dividingBy: 1.0))
                        let x = w * (0.34 + 0.09 * CGFloat(index))
                        let y = h * (0.45 - 0.04 * rise)
                        let radius = CGFloat(2 + 3 * (1 - rise))
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                                     with: .color(ForestPalette.butter.opacity(0.85)))
                    }
                }

                // 손잡이
                var handle = Path()
                handle.move(to: CGPoint(x: w * 0.18, y: h * 0.48))
                handle.addQuadCurve(to: CGPoint(x: w * 0.12, y: h * 0.56), control: CGPoint(x: w * 0.10, y: h * 0.48))
                context.stroke(handle, with: .color(Color(hex: 0x4A423C)), lineWidth: max(2, w * 0.02))
            }
        }
    }
}

/// 떨어지는 재료 하나.
struct FallingIngredientView: View {
    let ingredient: Ingredient
    let golden: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(ingredient.tint.opacity(0.92))
                .frame(width: 38, height: 38)
            Circle()
                .stroke(golden ? ForestPalette.moonlight : ForestPalette.parchment.opacity(0.8), lineWidth: 2)
                .frame(width: 38, height: 38)
            Text(ingredient.emoji)
                .font(.system(size: 19))
        }
        .shadow(color: golden ? ForestPalette.honey.opacity(0.7) : ForestPalette.ink.opacity(0.15), radius: golden ? 8 : 3)
    }
}

/// 바구니. 채집 화면 아래쪽에 놓인다.
struct BasketView: View {
    var tint: Color = ForestPalette.sage

    var body: some View {
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let body = Path(roundedRect: CGRect(x: w * 0.10, y: h * 0.30, width: w * 0.80, height: h * 0.62), cornerRadius: w * 0.16)
            context.fill(body, with: .color(tint.opacity(0.85)))
            context.stroke(body, with: .color(ForestPalette.chestnut.opacity(0.5)), lineWidth: 1.5)

            var weave = Path()
            for index in 1..<4 {
                let y = h * (0.30 + 0.16 * CGFloat(index))
                weave.move(to: CGPoint(x: w * 0.12, y: y))
                weave.addLine(to: CGPoint(x: w * 0.88, y: y))
            }
            context.stroke(weave, with: .color(ForestPalette.parchment.opacity(0.4)), lineWidth: 1)

            var handle = Path()
            handle.move(to: CGPoint(x: w * 0.24, y: h * 0.34))
            handle.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.34), control: CGPoint(x: w * 0.5, y: h * -0.10))
            context.stroke(handle, with: .color(ForestPalette.chestnut.opacity(0.7)), lineWidth: max(2, w * 0.035))
        }
    }
}
