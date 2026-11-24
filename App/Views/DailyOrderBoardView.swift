import SwiftUI
import AcornForestCore

/// 「이웃의 오늘의 비밀 주문서」. 취향 단서를 읽고 맞는 잼을 골라 건넨다.
struct DailyOrderBoardView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    titleCard
                    if store.orderBoardUnlocked {
                        orderCard
                        if let record = store.todaysOrderRecord {
                            doneCard(record)
                        } else {
                            deliverCard
                        }
                    } else {
                        lockedCard
                    }
                    trophyCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
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
                Text("이웃의 비밀 주문서")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("취향 단서를 읽고 오늘의 잼 한 병을 골라 주세요")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            Text("🌙 \(store.moonlightEnergy)/\(store.maxEnergy)")
                .font(.label(11))
                .foregroundStyle(ForestPalette.sage)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(ForestPalette.sage.opacity(0.12)))
        }
        .padding(.horizontal, 16)
    }

    private var titleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "나의 이름")
                Spacer()
                Text(store.orderTitle.title)
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.parchment)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ForestPalette.terracotta))
            }
            Text(store.orderTitle.note)
                .font(.story(12))
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 14) {
                statBlock(title: "주문 점수", value: "\(store.orderPoints)")
                statBlock(title: "연속", value: "\(store.orderStreak)")
                statBlock(title: "장식", value: "\(store.orderTrophies.count)/\(OrderTrophy.allCases.count)")
            }
        }
        .storybookCard()
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.story(18, weight: .semibold))
                .foregroundStyle(ForestPalette.sageDeep)
            Text(title)
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
        }
    }

    @ViewBuilder
    private var orderCard: some View {
        if let order = store.todaysOrder {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    CharacterPortrait(character: order.character, size: 66)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("\(order.character.name)의 오늘의 주문")
                            .font(.story(15, weight: .semibold))
                            .foregroundStyle(ForestPalette.ink)
                        Text(order.character.species)
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                        if store.todaysOrderRecord == nil {
                            Text("답이 될 수 있는 잼 \(store.orderNumberOfAnswers())가지")
                                .font(.label(9))
                                .foregroundStyle(ForestPalette.sage)
                        }
                    }
                    Spacer()
                }

                Text(order.clueLine)
                    .font(.story(14))
                    .lineSpacing(4)
                    .foregroundStyle(ForestPalette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ForestPalette.butter.opacity(0.4))
                    )

                Text(order.note)
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .storybookCard()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                SectionLabel(text: "오늘의 주문")
                Text("오늘은 주문서가 비어 있어요. 이웃과 인사하는 사이가 되면 주문이 걸립니다.")
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            .storybookCard()
        }
    }

    private func doneCard(_ record: OrderRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "오늘 마친 주문")
            Text(record.matched ? "✅ 단서에 맞는 잼을 건넸어요" : "🍯 잼은 잘 먹었지만 단서와는 조금 달랐어요")
                .font(.story(14, weight: .medium))
                .foregroundStyle(record.matched ? ForestPalette.sage : ForestPalette.terracotta)
            Text("\(RecipeBook.recipe(id: record.recipeID)?.name ?? record.recipeID) · 주문 점수 +\(record.points)")
                .font(.story(12))
                .foregroundStyle(ForestPalette.inkSoft)
            Text("내일 아침에 새 주문서가 걸립니다.")
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .storybookCard()
    }

    private var deliverCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "건넬 잼 고르기")
            if store.orderCandidates.isEmpty {
                Text("담가 둔 잼이 없어요. 부엌에서 먼저 잼을 담가 주세요.")
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)
            } else {
                ForEach(store.orderCandidates) { record in
                    dishRow(record)
                }
                Text("단서에 맞지 않는 잼을 건네면 그 잼은 그대로 먹히고, 점수는 조금만 쌓여요.")
                    .font(.story(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .storybookCard()
    }

    private func dishRow(_ record: CookedRecord) -> some View {
        let recipe = RecipeBook.recipe(id: record.recipeID)
        return Button {
            store.deliverOrder(recipeID: record.recipeID)
        } label: {
            HStack(spacing: 10) {
                Text(recipe?.ingredientEmojiLine ?? "🍲")
                    .font(.system(size: 16))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ForestPalette.parchmentDeep))
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe?.name ?? record.recipeID)
                        .font(.story(14, weight: .semibold))
                        .foregroundStyle(ForestPalette.ink)
                    Text("온기 \(recipe?.warmth ?? 0) · \(record.servings)접시 남음")
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Spacer()
                Image(systemName: "paperplane")
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

    private var lockedCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                Text("아직 주문서가 걸리지 않았어요")
                    .font(.story(14, weight: .semibold))
            }
            .foregroundStyle(ForestPalette.inkSoft)
            Text("3장을 마치고 잼을 두 가지 이상 담그면, 이웃이 취향 단서를 적어 주문서를 걸어 둡니다.")
                .font(.story(12))
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .storybookCard()
    }

    private var trophyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "다락 선반 장식")
            ForEach(OrderTrophy.allCases) { trophy in
                let unlocked = store.orderTrophies.contains(trophy)
                HStack(alignment: .top, spacing: 8) {
                    Text(unlocked ? trophy.emoji : "🔒")
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(trophy.title)
                            .font(.story(13, weight: unlocked ? .semibold : .regular))
                            .foregroundStyle(unlocked ? ForestPalette.ink : ForestPalette.inkSoft)
                        Text(trophy.note)
                            .font(.story(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Text("\(trophy.threshold)점")
                        .font(.label(10))
                        .foregroundStyle(unlocked ? ForestPalette.sage : ForestPalette.inkSoft)
                }
                .padding(.vertical, 2)
            }
        }
        .storybookCard()
    }
}
