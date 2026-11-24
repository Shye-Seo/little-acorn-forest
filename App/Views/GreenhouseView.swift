import SwiftUI
import AcornForestCore

/// 사계절 온실. 확장팩을 사면 에필로그 뒤에 열리는 유리 지붕 아래.
struct GreenhouseView: View {
    @EnvironmentObject private var store: GameStore

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            VStack(spacing: 8) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        glassCard
                        seasonsCard
                        neighboursCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .padding(.top, 6)

            if let outcome = store.dialogue {
                DialogueOverlay(outcome: outcome)
            }
        }
        .onAppear {
            if !store.state.hasFlag("greenhouse.opened") {
                store.openGreenhouseWelcome()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("사계절 온실")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("봄·여름·가을·겨울이 네 칸에 나란히")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            Text("🌿 \(store.state.purchasedPacks.count)팩")
                .font(.label(10))
                .foregroundStyle(ForestPalette.sage)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(ForestPalette.sage.opacity(0.12)))
        }
        .padding(.horizontal, 16)
    }

    private var glassCard: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ForestPalette.sageLight.opacity(0.35), ForestPalette.dew.opacity(0.25)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(GreenhouseRecipes.Season.allCases) { season in
                        VStack(spacing: 4) {
                            Text(season.emoji)
                                .font(.system(size: 20))
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(season.ingredient.tint.opacity(0.35))
                                .frame(height: 46)
                            Text(season.title)
                                .font(.label(8))
                                .foregroundStyle(ForestPalette.inkSoft)
                        }
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(height: 150)
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(ForestPalette.sage.opacity(0.35), lineWidth: 1)
            )

            Text("온실에서는 사계절 재료가 계절과 상관없이 떨어집니다. 겨울 눈꽃 잼에는 보름달 밤의 월광 이슬도 필요해요.")
                .font(.story(12))
                .lineSpacing(4)
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("온실에서 채집하기") {
                    store.openGathering(at: .greenhouse)
                }
                .buttonStyle(StorybookButtonStyle())

                Button("선반 보기") {
                    store.openShelf()
                }
                .buttonStyle(QuietButtonStyle())
            }
        }
        .storybookCard(padding: 14)
    }

    private var seasonsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "네 칸의 계절")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(GreenhouseRecipes.Season.allCases) { season in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(season.emoji)
                                .font(.system(size: 15))
                            Text(season.title)
                                .font(.story(13, weight: .semibold))
                                .foregroundStyle(ForestPalette.ink)
                        }
                        Text(season.note)
                            .font(.story(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(season.ingredient.emoji) \(season.ingredient.title)")
                            .font(.label(9))
                            .foregroundStyle(season.ingredient.tint)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ForestPalette.parchmentDeep.opacity(0.45))
                    )
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                SectionLabel(text: "온실 레시피")
                ForEach(GreenhouseRecipes.all) { recipe in
                    HStack(spacing: 8) {
                        Text(recipe.ingredientEmojiLine)
                            .font(.system(size: 13))
                        Text(recipe.name)
                            .font(.story(12))
                            .foregroundStyle(ForestPalette.ink)
                        Spacer()
                        if store.state.record(for: recipe.id) != nil {
                            Text("담가 봄")
                                .font(.label(9))
                                .foregroundStyle(ForestPalette.sage)
                        }
                    }
                }
            }
        }
        .storybookCard()
    }

    private var neighboursCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "온실지기")
            ForEach(store.engine.greenhouseNeighbours) { character in
                let affinity = store.engine.affinityState(for: character)
                HStack(spacing: 10) {
                    CharacterPortrait(character: character, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(character.name)
                                .font(.story(14, weight: .semibold))
                                .foregroundStyle(ForestPalette.ink)
                            Text(character.species)
                                .font(.label(9))
                                .foregroundStyle(ForestPalette.inkSoft)
                        }
                        Text(AppText.hearts(for: affinity.level))
                            .font(.system(size: 10))
                            .foregroundStyle(ForestPalette.terracotta)
                            .tracking(2)
                        Text(affinity.level == .shy ? character.portraitNote : character.wish)
                            .font(.story(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button("대화") {
                        store.openDialogue(with: character)
                    }
                    .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))
                }
            }
        }
        .storybookCard()
    }
}

/// 대화 한 장면을 화면 위에 펼쳐 보여 준다.
struct DialogueOverlay: View {
    @EnvironmentObject private var store: GameStore
    let outcome: DialogueOutcome

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { store.closeDialogue() }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionLabel(text: outcome.scene.title)
                    Spacer()
                    if outcome.gain > 0 {
                        Text("호감도 +\(outcome.gain)")
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.terracotta)
                    }
                }

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(outcome.scene.lines) { line in
                            if line.speaker.isNarration {
                                Text(line.text)
                                    .font(.story(13))
                                    .lineSpacing(5)
                                    .foregroundStyle(ForestPalette.inkSoft)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(line.speaker.displayName)
                                        .font(.label(10))
                                        .foregroundStyle(ForestPalette.sage)
                                    Text(line.text)
                                        .font(.story(13))
                                        .lineSpacing(5)
                                        .foregroundStyle(ForestPalette.ink)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(ForestPalette.parchmentDeep.opacity(0.45))
                                )
                            }
                        }

                        Text(outcome.scene.closingThought)
                            .font(.story(12))
                            .italic()
                            .foregroundStyle(ForestPalette.inkSoft)
                            .padding(.top, 4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxHeight: 320)

                Button("닫기") {
                    store.closeDialogue()
                }
                .buttonStyle(StorybookButtonStyle())
            }
            .storybookCard(padding: 18)
            .padding(.horizontal, 20)
        }
    }
}
