import SwiftUI
import AcornForestCore

/// 오두막 다락 선반. 담근 잼을 병에 담아 꾸미고 진열한다.
struct ShelfView: View {
    @EnvironmentObject private var store: GameStore

    @State private var pickedRecipeID: String = ""
    @State private var bottle: JarBottleStyle = .roundGlass
    @State private var cap: JarCapStyle = .cork
    @State private var ribbon: JarRibbonColor = .sage
    @State private var label: String = ""
    @State private var sparkleSlot: Int?
    @State private var openedJar: CustomJamJar?

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    cabinCard
                    shelfCard
                    decoratorCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
        .onAppear(perform: prepare)
        .sheet(item: $openedJar) { jar in
            JarDetailSheet(jar: jar)
        }
    }

    private func prepare() {
        if let preselect = store.shelfPreselect {
            pickedRecipeID = preselect
        } else if pickedRecipeID.isEmpty {
            pickedRecipeID = store.giftableRecipes().first?.recipeID ?? ""
        }
        if store.unlockedBottles.contains(bottle) == false {
            bottle = .roundGlass
        }
        if store.unlockedCaps.contains(cap) == false {
            cap = .cork
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
                Text("다락 선반")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("\(store.shelfJars.count) / \(JarShelf.capacity)병 · 병을 누르면 소리가 나요")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            Text(store.cabinStyle.title)
                .font(.label(10))
                .foregroundStyle(ForestPalette.sage)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(ForestPalette.sage.opacity(0.12)))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 오두막 스킨

    private var cabinCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "오두막 스킨")
                Spacer()
                if !store.ownsWorkshop {
                    Button("공방 스킨 보기") {
                        store.openStore()
                    }
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.terracotta)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.unlockedCabinStyles) { style in
                        Button {
                            store.setCabinStyle(style)
                        } label: {
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(style.wallColor)
                                    .frame(width: 54, height: 34)
                                    .overlay(
                                        Circle()
                                            .fill(style.lampColor)
                                            .frame(width: 12, height: 12)
                                    )
                                Text(style.title)
                                    .font(.label(9))
                                    .foregroundStyle(ForestPalette.ink)
                            }
                            .padding(7)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(store.cabinStyle == style ? ForestPalette.butter.opacity(0.5) : ForestPalette.parchmentDeep.opacity(0.4))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if !store.ownsWorkshop {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9))
                            Text("별빛 벽지 · 이끼 램프")
                                .font(.label(9))
                        }
                        .foregroundStyle(ForestPalette.inkSoft)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(ForestPalette.pageEdge, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        )
                    }
                }
            }
            Text(store.cabinStyle.note)
                .font(.story(11))
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .storybookCard()
    }

    // MARK: - 선반

    private var shelfCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "다락 선반")
                Spacer()
                Text(store.canDecorate ? "빈 칸 \(JarShelf.capacity - store.shelfJars.count)개" : "가득 찼어요")
                    .font(.label(10))
                    .foregroundStyle(store.canDecorate ? ForestPalette.sage : ForestPalette.berry)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(0..<JarShelf.capacity, id: \.self) { slot in
                    slotView(slot)
                }
            }

            if !store.orderTrophies.isEmpty {
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 6) {
                    Text("주문서로 받은 장식")
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                    HStack(spacing: 10) {
                        ForEach(store.orderTrophies) { trophy in
                            VStack(spacing: 2) {
                                Text(trophy.emoji)
                                    .font(.system(size: 20))
                                Text(trophy.title)
                                    .font(.label(8))
                                    .foregroundStyle(ForestPalette.inkSoft)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(ForestPalette.butter.opacity(0.4))
                            )
                        }
                    }
                }
            }
        }
        .storybookCard()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(store.cabinStyle.wallColor.opacity(0.35))
        )
    }

    @ViewBuilder
    private func slotView(_ slot: Int) -> some View {
        if let jar = store.shelfJars.first(where: { $0.slot == slot }) {
            Button {
                Haptics.tap()
                ForestAudio.shared.playJarPop()
                sparkleSlot = slot
                openedJar = jar
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 700_000_000)
                    sparkleSlot = nil
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(ForestPalette.parchment.opacity(0.75))
                    JarVisual(jar: jar, size: 66)
                    SparkleBurst(isActive: sparkleSlot == slot)
                }
                .frame(height: 108)
            }
            .buttonStyle(.plain)
        } else {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(ForestPalette.pageEdge, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
                .frame(height: 108)
                .overlay(
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                        .foregroundStyle(ForestPalette.inkSoft.opacity(0.4))
                )
        }
    }

    // MARK: - 병 꾸미기

    private var decoratorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "병 꾸미기")

            if store.giftableRecipes().isEmpty {
                Text("아직 담근 잼이 없어요. 부엌에서 잼을 먼저 담가 주세요.")
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.giftableRecipes()) { record in
                            recipeChip(record)
                        }
                    }
                }

                pickerRow(title: "병", options: store.unlockedBottles.map { $0.title }, selected: bottle.title) {
                    ForEach(store.unlockedBottles) { style in
                        chipButton(title: style.title, active: bottle == style) {
                            bottle = style
                            Haptics.tap()
                        }
                    }
                    if !store.ownsWorkshop {
                        chipButton(title: "크리스탈 병 🔒", active: false) {
                            store.openStore()
                        }
                    }
                }

                pickerRow(title: "마개", options: store.unlockedCaps.map { $0.title }, selected: cap.title) {
                    ForEach(store.unlockedCaps) { style in
                        chipButton(title: style.title, active: cap == style) {
                            cap = style
                            Haptics.tap()
                        }
                    }
                    if !store.ownsWorkshop {
                        chipButton(title: "별 모양 마개 🔒", active: false) {
                            store.openStore()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("리본")
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                    HStack(spacing: 8) {
                        ForEach(JarRibbonColor.allCases) { color in
                            Button {
                                ribbon = color
                                Haptics.tap()
                            } label: {
                                Circle()
                                    .fill(Color(hex: color.hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        Circle()
                                            .stroke(ribbon == color ? ForestPalette.ink : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(color.title))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("손글씨 라벨")
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                        Spacer()
                        Text("\(label.count)/\(JarShelf.labelLimit)")
                            .font(.label(9))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                    TextField("비워 두면 잼 이름이 붙어요", text: $label)
                        .font(.story(14))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(ForestPalette.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(ForestPalette.pageEdge, lineWidth: 1)
                                )
                        )
                        .onChange(of: label) { newValue in
                            if newValue.count > JarShelf.labelLimit {
                                label = String(newValue.prefix(JarShelf.labelLimit))
                            }
                        }
                }

                HStack(spacing: 12) {
                    JarVisual(
                        jar: CustomJamJar(
                            recipeID: pickedRecipeID.isEmpty ? "dawn-dew-jam" : pickedRecipeID,
                            bottle: bottle,
                            cap: cap,
                            ribbon: ribbon,
                            label: label,
                            moonPhase: store.moonPhase
                        ),
                        size: 74
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.moonPhase.badgeLine)
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                        Text(store.canDecorate ? "선반 \(store.shelfJars.count + 1)번 칸에 놓입니다" : "선반이 가득 찼어요")
                            .font(.story(11))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                    Spacer()
                }

                Button("병에 담아 선반에 올리기") {
                    let placed = store.decorateJar(
                        recipeID: pickedRecipeID,
                        bottle: bottle,
                        cap: cap,
                        ribbon: ribbon,
                        label: label
                    )
                    if placed {
                        label = ""
                        if let next = store.giftableRecipes().first?.recipeID {
                            pickedRecipeID = next
                        }
                    }
                }
                .buttonStyle(StorybookButtonStyle())
                .disabled(pickedRecipeID.isEmpty || !store.canDecorate)
                .opacity(pickedRecipeID.isEmpty || !store.canDecorate ? 0.45 : 1)
            }
        }
        .storybookCard()
    }

    private func recipeChip(_ record: CookedRecord) -> some View {
        let recipe = RecipeBook.recipe(id: record.recipeID)
        let active = pickedRecipeID == record.recipeID
        return Button {
            pickedRecipeID = record.recipeID
            Haptics.tap()
        } label: {
            VStack(spacing: 3) {
                Text(recipe?.ingredientEmojiLine ?? "🍯")
                    .font(.system(size: 16))
                Text(recipe?.name ?? record.recipeID)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.ink)
                Text("\(record.servings)접시")
                    .font(.label(9))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(active ? ForestPalette.butter.opacity(0.55) : ForestPalette.parchmentDeep.opacity(0.4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(active ? ForestPalette.terracotta : ForestPalette.pageEdge, lineWidth: active ? 1.6 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func pickerRow<Content: View>(title: String,
                                          options: [String],
                                          selected: String,
                                          @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
                Spacer()
                Text(selected)
                    .font(.label(9))
                    .foregroundStyle(ForestPalette.sage)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    content()
                }
            }
            .opacity(options.isEmpty ? 0.4 : 1)
        }
    }

    private func chipButton(title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.label(10))
                .foregroundStyle(active ? ForestPalette.parchment : ForestPalette.ink)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(active ? ForestPalette.sage : ForestPalette.parchmentDeep.opacity(0.5))
                )
                .overlay(
                    Capsule().stroke(active ? Color.clear : ForestPalette.pageEdge, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// 병 하나를 눌렀을 때 펼쳐지는 설명.
struct JarDetailSheet: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.dismiss) private var dismiss
    let jar: CustomJamJar

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                JarVisual(jar: jar, size: 130)
                    .padding(.top, 12)

                Text(jar.displayLabel)
                    .font(.story(20, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)

                Text(jar.detailLine)
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.inkSoft)

                Text(jar.moonLine)
                    .font(.story(12))
                    .foregroundStyle(ForestPalette.inkSoft)

                if let recipe = RecipeBook.recipe(id: jar.recipeID) {
                    Text(recipe.story)
                        .font(.story(13))
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(ForestPalette.ink)
                        .padding(.horizontal, 18)
                }

                Button("병 뚜껑 열어 보기") {
                    Haptics.tap()
                    ForestAudio.shared.playJarPop()
                }
                .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))

                Button("선반에서 내리기") {
                    store.removeJar(id: jar.id)
                    dismiss()
                }
                .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
            }
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ParchmentBackground())
            .navigationTitle("선반의 병")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
