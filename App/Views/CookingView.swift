import SwiftUI
import AcornForestCore

/// 솥단지 요리. 재료를 고르고, 은근한 불을 유지해 완성도를 올린다.
struct CookingView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selected: [Ingredient] = []
    @State private var outcome: CookingOutcome?

    var body: some View {
        VStack(spacing: 10) {
            header

            if let outcome {
                resultCard(outcome)
            } else if let cooking = store.cooking {
                playfield(cooking)
            } else {
                picker
            }
        }
        .padding(.top, 6)
        .task(id: store.cooking != nil) {
            await cookLoop()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.closeCooking()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("오두막 부엌")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text(store.cooking == nil ? "재료를 고르고 불을 피워 보세요" : "불은 재촉하지 않는다 — 할머니의 수첩")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            if let cooking = store.cooking {
                Text(AppText.timer(cooking.remaining))
                    .font(.label(13))
                    .foregroundStyle(cooking.burned ? ForestPalette.berry : ForestPalette.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ForestPalette.parchment.opacity(0.9)))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 재료 고르기

    private var picker: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                potPreview

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        SectionLabel(text: "바구니")
                        Spacer()
                        Text("최대 3가지")
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 8)], spacing: 8) {
                        ForEach(Ingredient.allCases) { ingredient in
                            ingredientButton(ingredient)
                        }
                    }
                }
                .storybookCard()

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "솥단지에 넣을 재료")
                    if selected.isEmpty {
                        Text("아직 아무것도 넣지 않았어요.")
                            .font(.story(13))
                            .foregroundStyle(ForestPalette.inkSoft)
                    } else {
                        HStack(spacing: 6) {
                            ForEach(Array(selected.enumerated()), id: \.offset) { _, ingredient in
                                Text("\(ingredient.emoji) \(ingredient.title)")
                                    .font(.label(11))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(ingredient.tint.opacity(0.16)))
                            }
                        }
                        Text(hintLine)
                            .font(.story(12))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                }
                .storybookCard()

                Button("불 피우기") {
                    guard !selected.isEmpty else { return }
                    if store.startCooking(ingredients: selected) {
                        Haptics.tap()
                    }
                }
                .buttonStyle(StorybookButtonStyle())
                .disabled(selected.isEmpty || !store.state.canAfford(selected))
                .opacity(selected.isEmpty || !store.state.canAfford(selected) ? 0.45 : 1)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 20)
        }
    }

    private var potPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ForestPalette.parchmentDeep.opacity(0.5))
            PotView(heat: 0.2, phase: .faint, isCooking: false)
                .frame(height: 170)
                .padding(.horizontal, 40)
        }
        .frame(height: 200)
    }

    private func ingredientButton(_ ingredient: Ingredient) -> some View {
        let count = store.state.count(of: ingredient)
        let isSelected = selected.contains(ingredient)
        let canSelect = count > 0 && (isSelected || selected.count < RecipeBook.maximumIngredientCount)

        return Button {
            toggle(ingredient)
        } label: {
            VStack(spacing: 4) {
                Text(ingredient.emoji)
                    .font(.system(size: 22))
                Text(ingredient.title)
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.ink)
                Text("×\(count)")
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? ingredient.tint.opacity(0.2) : ForestPalette.parchmentDeep.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? ingredient.tint : ForestPalette.pageEdge, lineWidth: isSelected ? 1.6 : 1)
            )
            .opacity(canSelect ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!canSelect && !isSelected)
    }

    private var hintLine: String {
        if RecipeBook.recipe(for: selected) != nil {
            return "수첩에서 본 조합 같아요."
        }
        if selected.count < 2 {
            return "두 가지는 있어야 요리다워요."
        }
        return "수첩에 없는 조합이에요. 그래도 솥단지는 뭐든 품어 줍니다."
    }

    private func toggle(_ ingredient: Ingredient) {
        if let index = selected.firstIndex(of: ingredient) {
            selected.remove(at: index)
            return
        }
        guard store.state.count(of: ingredient) > 0,
              selected.count < RecipeBook.maximumIngredientCount else { return }
        selected.append(ingredient)
    }

    // MARK: - 불 조절

    private func playfield(_ cooking: CookingSession) -> some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(ForestPalette.parchmentDeep.opacity(0.55))
                PotView(heat: cooking.heat, phase: cooking.phase, isCooking: true)
                    .frame(height: 220)
                    .padding(.horizontal, 30)
            }
            .frame(height: 250)

            VStack(spacing: 8) {
                HStack {
                    Text(cooking.phase.title)
                        .font(.story(15, weight: .semibold))
                        .foregroundStyle(cooking.phase.isIdeal ? ForestPalette.sage : ForestPalette.terracotta)
                    Spacer()
                    Text("젓기 \(cooking.stirs)번")
                        .font(.label(11))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                HeatGauge(heat: cooking.heat)
                HStack {
                    Text("옅은 불").font(.label(9)).foregroundStyle(ForestPalette.inkSoft)
                    Spacer()
                    Text("은근한 구간").font(.label(9)).foregroundStyle(ForestPalette.sage)
                    Spacer()
                    Text("센 불").font(.label(9)).foregroundStyle(ForestPalette.berry)
                }
            }
            .padding(.horizontal, 22)

            HStack(spacing: 10) {
                Text(selected.map(\.emoji).joined())
                    .font(.system(size: 22))
                Text(selected.map(\.title).joined(separator: " + "))
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)
                    .lineLimit(1)
            }

            Button {
                store.stirCooking()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 22))
                    Text("은근하게 젓기")
                        .font(.story(15, weight: .semibold))
                }
                .foregroundStyle(ForestPalette.parchment)
                .frame(width: 150, height: 76)
                .background(Circle().fill(ForestPalette.terracotta))
                .shadow(color: ForestPalette.terracotta.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)
            .disabled(cooking.isFinished)

            if cooking.isFinished {
                Button("완성하기") {
                    store.finishCooking()
                    outcome = store.lastCooking
                }
                .buttonStyle(StorybookButtonStyle())
                .padding(.horizontal, 40)
            } else {
                ProgressBar(value: cooking.progress, tint: ForestPalette.terracotta)
                    .padding(.horizontal, 30)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - 결과

    private func resultCard(_ outcome: CookingOutcome) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text(outcome.recipe?.name ?? "이름 붙일 수 없는 한 그릇")
                    .font(.story(22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ForestPalette.ink)
                Text(outcome.attempted.map(\.emoji).joined(separator: " "))
                    .font(.system(size: 22))

                Text(AppText.qualityLine(outcome.quality))
                    .font(.label(12))
                    .foregroundStyle(ForestPalette.parchment)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(outcome.quality == .perfect ? ForestPalette.sage : ForestPalette.terracotta))

                Text(outcome.message)
                    .font(.story(14))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ForestPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if outcome.isNewRecipe {
                    Text("새 레시피를 일기장에 적었어요")
                        .font(.label(11))
                        .foregroundStyle(ForestPalette.terracotta)
                }

                VStack(spacing: 8) {
                    if outcome.recipe != nil {
                        Button("이웃에게 선물하러 가기") {
                            store.openNeighbours()
                        }
                        .buttonStyle(StorybookButtonStyle(tint: ForestPalette.terracotta))
                    }
                    Button("한 번 더 만들기") {
                        self.outcome = nil
                        selected = []
                    }
                    .buttonStyle(QuietButtonStyle())
                    Button("숲 지도로") {
                        store.closeCooking()
                    }
                    .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
                }
                .padding(.top, 4)
            }
            .storybookCard(padding: 22)
            .padding(.horizontal, 18)
            .padding(.top, 24)
        }
    }

    @MainActor
    private func cookLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 33_000_000)
            guard let cooking = store.cooking else { return }
            if cooking.isFinished { return }
            store.tickCooking(1.0 / 30.0)
        }
    }
}

struct HeatGauge: View {
    var heat: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ForestPalette.pageEdge)

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(ForestPalette.sage.opacity(0.25))
                    .frame(width: geo.size.width * CGFloat(CookingSession.idealBand.upperBound - CookingSession.idealBand.lowerBound))
                    .offset(x: geo.size.width * CGFloat(CookingSession.idealBand.lowerBound))

                Circle()
                    .fill(ForestPalette.terracotta)
                    .frame(width: 16, height: 16)
                    .offset(x: max(0, min(geo.size.width - 16, geo.size.width * CGFloat(min(1, max(0, heat))) - 8)))
            }
        }
        .frame(height: 16)
    }
}
