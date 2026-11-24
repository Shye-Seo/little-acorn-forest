import SwiftUI
import AcornForestCore

/// 지도·채집·부엌 위쪽에 붙는 달 위상 배지.
/// 길게 누르면 위상을 한 단계씩 고정해 볼 수 있다(디버그).
struct MoonBadgeView: View {
    @EnvironmentObject private var store: GameStore
    var showsDetail: Bool = true
    var tint: Color = ForestPalette.parchment

    var body: some View {
        HStack(spacing: 8) {
            Text(store.moonPhase.emoji)
                .font(.system(size: 15))

            VStack(alignment: .leading, spacing: 1) {
                Text(store.moonPhase.title)
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.ink)
                if showsDetail {
                    Text(store.moonDetailLine)
                        .font(.story(10))
                        .foregroundStyle(store.isMoonlitGardenOpen ? ForestPalette.sage : ForestPalette.inkSoft)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if store.isMoonlitGardenOpen {
                Text("정원 열림")
                    .font(.label(9))
                    .foregroundStyle(ForestPalette.parchment)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ForestPalette.sage))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(tint.opacity(0.92))
                .overlay(Capsule().stroke(ForestPalette.pageEdge, lineWidth: 1))
        )
        .onLongPressGesture(minimumDuration: 0.8) {
            store.cycleMoonOverride()
            Haptics.tap()
        }
    }
}

/// 잼 병 한 병을 코드로 그린 그림.
struct JarVisual: View {
    let jar: CustomJamJar
    var size: CGFloat = 78

    private var jamColor: Color {
        let recipe = RecipeBook.recipe(id: jar.recipeID)
        if let ingredient = recipe?.ingredients.first {
            return ingredient.tint
        }
        return ForestPalette.honey
    }

    var body: some View {
        VStack(spacing: 3) {
            ZStack(alignment: .top) {
                bottle
                jam
                capView
                ribbonView
            }
            .frame(width: size, height: size * 1.05)

            Text(jar.displayLabel)
                .font(.label(8))
                .foregroundStyle(ForestPalette.ink)
                .lineLimit(1)
                .frame(maxWidth: size * 1.1)
        }
    }

    @ViewBuilder
    private var bottle: some View {
        switch jar.bottle {
        case .roundGlass:
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(ForestPalette.parchment.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                        .stroke(ForestPalette.sage.opacity(0.5), lineWidth: 1.2)
                )
                .frame(width: size * 0.68, height: size * 0.78)
                .offset(y: size * 0.18)
        case .starVial:
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(ForestPalette.parchment.opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(ForestPalette.moonflake.opacity(0.85), lineWidth: 1.3)
                )
                .frame(width: size * 0.52, height: size * 0.7)
                .rotationEffect(.degrees(45))
                .offset(y: size * 0.2)
        case .gourd:
            VStack(spacing: -size * 0.1) {
                Circle()
                    .fill(ForestPalette.parchment.opacity(0.55))
                    .overlay(Circle().stroke(ForestPalette.chestnut.opacity(0.55), lineWidth: 1.2))
                    .frame(width: size * 0.36, height: size * 0.36)
                Circle()
                    .fill(ForestPalette.parchment.opacity(0.55))
                    .overlay(Circle().stroke(ForestPalette.chestnut.opacity(0.55), lineWidth: 1.2))
                    .frame(width: size * 0.62, height: size * 0.62)
            }
            .offset(y: size * 0.22)
        case .crystal:
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [ForestPalette.dew.opacity(0.35), ForestPalette.moonflake.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(ForestPalette.moonflake, lineWidth: 1.4)
                )
                .frame(width: size * 0.62, height: size * 0.76)
                .offset(y: size * 0.18)
        }
    }

    private var jam: some View {
        Capsule()
            .fill(jamColor.opacity(0.75))
            .frame(width: size * 0.42, height: size * 0.34)
            .offset(y: size * 0.46)
    }

    private var capView: some View {
        ZStack {
            switch jar.cap {
            case .cork:
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ForestPalette.chestnut)
            case .moonlightMetal:
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(ForestPalette.moonflake)
            case .checkCloth:
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(ForestPalette.berry.opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(ForestPalette.parchment.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    )
            case .starCap:
                Image(systemName: "star.fill")
                    .font(.system(size: size * 0.2))
                    .foregroundStyle(ForestPalette.butter)
            }
        }
        .frame(width: size * 0.28, height: size * 0.14)
        .offset(y: size * 0.03)
    }

    private var ribbonView: some View {
        Capsule()
            .fill(Color(hex: jar.ribbon.hex))
            .frame(width: size * 0.5, height: size * 0.07)
            .offset(y: size * 0.3)
    }
}

/// 병을 눌렀을 때 터지는 반짝임.
struct SparkleBurst: View {
    var isActive: Bool
    var tint: Color = ForestPalette.butter

    var body: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .offset(
                        x: isActive ? CGFloat(cos(Double(index) * Double.pi / 4)) * 34 : 0,
                        y: isActive ? CGFloat(sin(Double(index) * Double.pi / 4)) * 34 : 0
                    )
                    .opacity(isActive ? 0 : 0.9)
            }
        }
        .animation(.easeOut(duration: 0.75), value: isActive)
        .allowsHitTesting(false)
    }
}

/// 빗줄기 연출. 집중 타이머 배경에만 쓴다.
struct RainOverlay: View {
    var intensity: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<24 {
                    let seed = Double(index) * 0.137
                    let x = (seed.truncatingRemainder(dividingBy: 1)) * size.width
                    let speed = 190 + seed * 220
                    let span = max(1, size.height + 20)
                    let y = (time * speed + seed * 900).truncatingRemainder(dividingBy: span)
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: y))
                    path.addLine(to: CGPoint(x: x - 3, y: y + 15))
                    context.stroke(
                        path,
                        with: .color(ForestPalette.dew.opacity(0.38 * intensity)),
                        style: StrokeStyle(lineWidth: 1.3, lineCap: .round)
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 모닥불 불빛. 숨 쉬듯 밝아졌다 어두워진다.
struct FireGlow: View {
    var strength: Double = 1

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.75 + 0.25 * sin(time * 1.6)
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                ForestPalette.butter.opacity(0.55 * pulse * strength),
                                ForestPalette.terracotta.opacity(0.28 * pulse * strength),
                                ForestPalette.terracotta.opacity(0)
                            ],
                            center: .center,
                            startRadius: 6,
                            endRadius: 120
                        )
                    )
                Capsule()
                    .fill(ForestPalette.terracotta.opacity(0.85))
                    .frame(width: 26, height: 26 * pulse)
                    .offset(y: 10)
                Capsule()
                    .fill(ForestPalette.butter.opacity(0.9))
                    .frame(width: 12, height: 16 * pulse)
                    .offset(y: 12)
            }
            .frame(width: 240, height: 240)
        }
        .allowsHitTesting(false)
    }
}
