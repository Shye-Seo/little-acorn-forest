import SwiftUI
import AcornForestCore

/// 솥단지 잼. 재료를 고르고, 은근한 불을 유지해 완성도를 올린다.
struct CookingView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selected: [Ingredient] = []
    @State private var outcome: CookingOutcome?

    var body: some View {
        VStack(spacing: 10) {
            header

            HStack {
                MoonBadgeView(showsDetail: false)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

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
                        Text("최대 3개")
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                        ForEach(store.visibleIngredients) { ingredient in
                            ingredientButton(ingredient)
                        }
                    }
                    if store.visibleIngredients.contains(where: { $0.isExpansionIngredient }) {
                        Text("🌕 달빛 비밀 정원과 사계절 온실에서만 나오는 재료가 섞여 있어요.")
                            .font(.story(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
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
                            ForEach(selectedGroups, id: \.ingredient) { group in
                                Button {
                                    removeOne(group.ingredient)
                                    Haptics.tap()
                                } label: {
                                    Text(group.label)
                                        .font(.label(11))
                                        .foregroundStyle(ForestPalette.ink)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Capsule().fill(group.ingredient.tint.opacity(0.16)))
                                }
                                .buttonStyle(.plain)
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
        let inPot = selected.filter { $0 == ingredient }.count
        let canAdd = count > inPot && selected.count < RecipeBook.maximumIngredientCount

        return Button {
            add(ingredient)
        } label: {
            VStack(spacing: 4) {
                Text(ingredient.emoji)
                    .font(.system(size: 22))
                Text(ingredient.title)
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.ink)
                Text(inPot > 0 ? "넣음 \(inPot) · 남음 \(count - inPot)" : "×\(count)")
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(inPot > 0 ? ingredient.tint.opacity(0.2) : ForestPalette.parchmentDeep.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(inPot > 0 ? ingredient.tint : ForestPalette.pageEdge, lineWidth: inPot > 0 ? 1.6 : 1)
            )
            .opacity(canAdd || inPot > 0 ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!canAdd)
    }

    /// 솥에 넣은 재료를 종류별로 묶어 보여 준다. (새벽이슬 잼처럼 같은 재료를 두 개 쓰는 조합이 있다)
    private var selectedGroups: [IngredientGroup] {
        var order: [Ingredient] = []
        var counts: [Ingredient: Int] = [:]
        for ingredient in selected {
            if counts[ingredient] == nil { order.append(ingredient) }
            counts[ingredient, default: 0] += 1
        }
        return order.map { IngredientGroup(ingredient: $0, count: counts[$0] ?? 0) }
    }

    private var selectedLine: String {
        selectedGroups.map { group in
            group.count > 1 ? "\(group.ingredient.title) ×\(group.count)" : group.ingredient.title
        }.joined(separator: " + ")
    }

    private var hintLine: String {
        if RecipeBook.recipe(for: selected) != nil {
            return "수첩에서 본 조합 같아요."
        }
        if selected.count < 2 {
            return "재료는 두 개부터. 같은 재료를 두 번 넣어도 괜찮아요."
        }
        return "수첩에 없는 조합이에요. 그래도 솥단지는 뭐든 품어 줍니다."
    }

    private func add(_ ingredient: Ingredient) {
        let inPot = selected.filter { $0 == ingredient }.count
        guard store.state.count(of: ingredient) > inPot,
              selected.count < RecipeBook.maximumIngredientCount else { return }
        selected.append(ingredient)
        Haptics.tap()
    }

    private func removeOne(_ ingredient: Ingredient) {
        if let index = selected.lastIndex(of: ingredient) {
            selected.remove(at: index)
        }
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
                Text(selectedLine)
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

                if let blessing = outcome.blessing, blessing.hasEffect {
                    VStack(spacing: 3) {
                        Text("\(blessing.phase.emoji) \(blessing.title)")
                            .font(.label(11))
                            .foregroundStyle(ForestPalette.terracotta)
                        Text(blessing.note)
                            .font(.story(11))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(ForestPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ForestPalette.butter.opacity(0.35))
                    )
                }

                if outcome.isNewRecipe {
                    Text("새 레시피를 일기장에 적었어요")
                        .font(.label(11))
                        .foregroundStyle(ForestPalette.terracotta)
                }

                VStack(spacing: 8) {
                    if outcome.recipe != nil {
                        Button("병에 담아 선반에 올리기") {
                            store.openShelf(preselect: outcome.recipe?.id)
                        }
                        .buttonStyle(StorybookButtonStyle(tint: ForestPalette.terracotta))
                        Button("이웃에게 선물하러 가기") {
                            store.openNeighbours()
                        }
                        .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))
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

/// 솥에 들어간 재료 묶음. 같은 재료를 두 개 넣은 조합을 한 칸으로 보여 준다.
struct IngredientGroup: Identifiable {
    let ingredient: Ingredient
    let count: Int

    var id: String { ingredient.rawValue }

    var label: String {
        count > 1 ? "\(ingredient.emoji) \(ingredient.title) ×\(count)" : "\(ingredient.emoji) \(ingredient.title)"
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
