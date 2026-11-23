import SwiftUI
import AcornForestCore

/// 숲속 이웃들. 호감도와 소원을 확인하고 요리를 선물한다.
struct NeighboursView: View {
    @EnvironmentObject private var store: GameStore
    @State private var giftingTo: CharacterID?

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(CharacterID.allCases) { character in
                        card(for: character)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
        .sheet(item: $giftingTo) { character in
            GiftSheet(character: character)
                .environmentObject(store)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.openMap()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text("숲속 이웃")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("요리를 건네면 이야기가 조금씩 열려요")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func card(for character: CharacterID) -> some View {
        let affinity = store.engine.affinityState(for: character)
        let level = affinity.level
        let knowsWish = level >= .close
        let knowsTaste = level >= .greeting

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                CharacterPortrait(character: character, size: 76)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(character.name)
                            .font(.story(17, weight: .semibold))
                            .foregroundStyle(ForestPalette.ink)
                        Text(character.species)
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                    Text(AppText.hearts(for: level))
                        .font(.system(size: 12))
                        .foregroundStyle(ForestPalette.terracotta)
                        .tracking(2)
                    Text(AppText.affinityLine(name: level.title, points: affinity.points, level: level))
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                    ProgressBar(value: Double(affinity.points) / Double(AffinitySystem.maximum), tint: ForestPalette.terracotta)
                        .padding(.top, 3)
                }
            }

            Text(level.note)
                .font(.story(12))
                .foregroundStyle(ForestPalette.inkSoft)

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(ForestPalette.honey)
                Text(knowsWish ? "소원 · \(character.wish)" : "소원은 아직 말해 주지 않았어요.")
                    .font(.story(12))
                    .foregroundStyle(ForestPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 11))
                    .foregroundStyle(ForestPalette.sage)
                Text(tasteLine(for: character, knowsTaste: knowsTaste))
                    .font(.story(12))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            Button {
                giftingTo = character
            } label: {
                Text("선물하기")
            }
            .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))
            .disabled(store.giftableRecipes().isEmpty)
            .opacity(store.giftableRecipes().isEmpty ? 0.45 : 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storybookCard()
    }

    private func tasteLine(for character: CharacterID, knowsTaste: Bool) -> String {
        guard knowsTaste else { return "좋아하는 요리는 아직 모릅니다." }
        guard let favorite = RecipeBook.recipe(id: character.favoriteRecipeID) else {
            return "아직 잘 모릅니다."
        }
        return "최애 요리 · \(favorite.name) (\(favorite.ingredientLine))"
    }
}

struct GiftSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let character: CharacterID

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        CharacterPortrait(character: character, size: 70)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(character.name)에게 선물")
                                .font(.story(17, weight: .semibold))
                            Text(AppText.hearts(for: store.engine.affinityLevel(for: character)))
                                .font(.system(size: 12))
                                .foregroundStyle(ForestPalette.terracotta)
                                .tracking(2)
                        }
                        Spacer()
                    }
                    .padding(.top, 6)

                    if store.giftableRecipes().isEmpty {
                        Text("아직 만든 요리가 없어요. 부엌에서 먼저 요리해 주세요.")
                            .font(.story(13))
                            .foregroundStyle(ForestPalette.inkSoft)
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)
                    } else {
                        ForEach(store.giftableRecipes()) { record in
                            dishRow(record)
                        }
                    }
                }
                .padding(18)
            }
            .background(ParchmentBackground())
            .navigationTitle("선물하기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func dishRow(_ record: CookedRecord) -> some View {
        let recipe = RecipeBook.recipe(id: record.recipeID)
        let favorite = record.recipeID == character.favoriteRecipeID

        return Button {
            store.gift(recipeID: record.recipeID, to: character)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text(recipe?.ingredientEmojiLine ?? "🍲")
                    .font(.system(size: 18))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ForestPalette.parchmentDeep))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(recipe?.name ?? record.recipeID)
                            .font(.story(15, weight: .semibold))
                            .foregroundStyle(ForestPalette.ink)
                        if favorite {
                            Text("최애")
                                .font(.label(9))
                                .foregroundStyle(ForestPalette.parchment)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ForestPalette.terracotta))
                        }
                    }
                    Text("\(AppText.qualityLine(record.bestQuality)) · \(record.servings)접시 남음")
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Spacer()
                Image(systemName: "gift")
                    .foregroundStyle(ForestPalette.sage)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(ForestPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(ForestPalette.pageEdge, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
