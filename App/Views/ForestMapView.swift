import SwiftUI
import AcornForestCore

/// 숲 지도. 장소를 눌러 채집하거나 부엌으로 들어간다.
struct ForestMapView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            header
            moonRow
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    storyCard
                    energyCard
                    mapCard
                    goalsCard
                    statsCard
                    expansionCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            bottomBar
        }
        .padding(.top, 6)
        .onAppear {
            store.refreshChapterAvailability()
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                store.goToTitle()
            } label: {
                Image(systemName: "book.closed")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(store.chapterTitle)
                    .font(.story(17, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                    .lineLimit(1)
                Text(store.chapterSubtitle)
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
                    .lineLimit(1)
            }

            Spacer()

            Text(AppText.percent(store.completionRatio))
                .font(.label(12))
                .foregroundStyle(ForestPalette.sage)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(ForestPalette.sage.opacity(0.12)))
        }
        .padding(.horizontal, 16)
    }

    private var moonRow: some View {
        HStack(spacing: 8) {
            MoonBadgeView()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
    }

    /// 오늘 남은 달빛 기운. 채집을 누르기 전에 한눈에 보인다.
    private var energyCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    SectionLabel(text: "달빛 기운")
                    Text(store.energyStars)
                        .font(.system(size: 10))
                        .foregroundStyle(ForestPalette.sage)
                        .tracking(1)
                }
                Text(store.energyHint)
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Text("\(store.moonlightEnergy)/\(store.maxEnergy)")
                .font(.label(12))
                .foregroundStyle(store.canGather ? ForestPalette.sage : ForestPalette.terracotta)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(ForestPalette.parchment.opacity(0.9)))
        }
        .storybookCard(padding: 14)
    }

    private var storyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "이야기")
                Spacer()
                if let chapter = store.engine.currentChapter {
                    Text(AppText.statusLabel(store.engine.status(of: chapter)))
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
            }
            Text(store.nextGoalLine)
                .font(.story(15))
                .foregroundStyle(ForestPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                PlayerPortrait(size: 58)
                VStack(alignment: .leading, spacing: 3) {
                    Text("보리")
                        .font(.story(15, weight: .semibold))
                        .foregroundStyle(ForestPalette.ink)
                    Text("할머니의 오두막을 물려받은 사람")
                        .font(.story(11))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Spacer()
            }

            Button(store.storyButtonTitle) {
                Haptics.tap()
                store.startOrResumeStory()
            }
            .buttonStyle(StorybookButtonStyle())
            .disabled(!store.canContinueStory)
            .opacity(store.canContinueStory ? 1 : 0.5)
        }
        .storybookCard()
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                SectionLabel(text: "숲 지도")
                Spacer()
                Text("장소를 누르면 움직여요")
                    .font(.story(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            GeometryReader { geo in
                ZStack {
                    ForestMapCanvas(unlocked: unlockedSet)
                    ForEach(ForestLocation.allCases) { location in
                        Button {
                            visit(location)
                        } label: {
                            LocationNode(
                                location: location,
                                locked: !store.isLocationUnlocked(location),
                                highlighted: highlighted(location)
                            )
                        }
                        .buttonStyle(.plain)
                        .position(
                            x: geo.size.width * CGFloat(location.mapAnchor.x),
                            y: geo.size.height * CGFloat(location.mapAnchor.y)
                        )
                    }
                }
            }
            .frame(height: 340)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ForestPalette.parchmentDeep.opacity(0.55))
            )

            if !store.isMoonlitGardenOpen {
                Text(store.moonGardenLine)
                    .font(.story(10))
                    .foregroundStyle(ForestPalette.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .storybookCard(padding: 14)
    }

    private var goalsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "이번 장에서 할 일")
            if let chapter = store.engine.currentChapter {
                ForEach(store.engine.goals(for: chapter)) { goal in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: goal.isMet ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 13))
                            .foregroundStyle(goal.isMet ? ForestPalette.sage : ForestPalette.inkSoft.opacity(0.5))
                            .padding(.top, 1)
                        Text(goal.text)
                            .font(.story(13))
                            .foregroundStyle(goal.isMet ? ForestPalette.inkSoft : ForestPalette.ink)
                        Spacer(minLength: 0)
                    }
                }
            } else {
                Text("이야기가 모두 끝났어요. 숲 일기장을 펼쳐 보세요.")
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .storybookCard()
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "숲의 기록")
            Text(store.progressLine)
                .font(.story(13))
                .foregroundStyle(ForestPalette.ink)
            Text(store.state.stats.summaryLine)
                .font(.story(12))
                .foregroundStyle(ForestPalette.inkSoft)
            ProgressBar(
                value: Double(store.diaryEntriesUnlocked) / Double(max(1, ForestDiary.totalCount)),
                tint: ForestPalette.terracotta
            )
            Text("일기장 \(store.diaryEntriesUnlocked)/\(ForestDiary.totalCount) 칸 · 선반 \(store.shelfJars.count)/\(JarShelf.capacity)병")
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .storybookCard()
    }

    private var expansionCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                SectionLabel(text: "오늘의 오두막")
                Spacer()
                Text("🪶 \(store.fireflyDust)")
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.sage)
            }
            HStack(spacing: 8) {
                shortcut(title: "우체통", detail: store.mailBadgeCount > 0 ? "\(store.mailBadgeCount)통" : "조용", icon: "envelope") {
                    store.openMailbox()
                }
                shortcut(title: "선반", detail: "\(store.shelfJars.count)병", icon: "square.grid.3x3") {
                    store.openShelf()
                }
                shortcut(title: "모닥불", detail: store.focusSession == nil ? "집중" : "진행 중", icon: "flame") {
                    store.openFocus()
                }
                shortcut(title: "상점", detail: store.state.purchasedPacks.isEmpty ? "확장팩" : "\(store.state.purchasedPacks.count)팩", icon: "bag") {
                    store.openStore()
                }
            }
            if store.isLocationUnlocked(.greenhouse) {
                Button {
                    store.openGreenhouse()
                } label: {
                    Label("사계절 온실로", systemImage: "leaf.circle")
                }
                .buttonStyle(QuietButtonStyle(tint: ForestPalette.sage))
            } else if store.ownsGreenhouse {
                Text("온실 문은 에필로그를 마친 다음 날 열립니다.")
                    .font(.story(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            } else {
                Text("에필로그 뒤에 열리는 사계절 온실은 상점에서 열 수 있어요.")
                    .font(.story(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            if store.orderBoardUnlocked {
                Button {
                    store.openOrders()
                } label: {
                    HStack(spacing: 6) {
                        Text("📜 오늘의 주문서")
                        if let record = store.todaysOrderRecord {
                            Text(record.matched ? "맞힘" : "마침")
                                .font(.label(9))
                                .foregroundStyle(ForestPalette.parchment)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ForestPalette.sage))
                        } else {
                            Text("새 주문")
                                .font(.label(9))
                                .foregroundStyle(ForestPalette.parchment)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(ForestPalette.terracotta))
                        }
                        Spacer()
                        Text("\(store.orderPoints)점")
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                }
                .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))
            }
        }
        .storybookCard()
    }

    private func shortcut(title: String, detail: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(ForestPalette.sage)
                Text(title)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.ink)
                Text(detail)
                    .font(.label(8))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(ForestPalette.parchmentDeep.opacity(0.45))
            )
        }
        .buttonStyle(.plain)
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            Button {
                store.openNeighbours()
            } label: {
                Label("이웃", systemImage: "heart")
            }
            .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))

            Button {
                store.openDiary(from: .map)
            } label: {
                Label("일기장", systemImage: "book")
            }
            .buttonStyle(QuietButtonStyle())

            Button {
                store.openMailbox()
            } label: {
                Label(store.mailBadgeCount > 0 ? "우체통 \(store.mailBadgeCount)" : "우체통", systemImage: "envelope")
            }
            .buttonStyle(QuietButtonStyle(tint: store.mailBadgeCount > 0 ? ForestPalette.terracotta : ForestPalette.sage))

            Spacer()

            Button {
                store.saveNow()
            } label: {
                Label("저장", systemImage: "leaf")
            }
            .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var unlockedSet: Set<ForestLocation> {
        Set(ForestLocation.allCases.filter { store.isLocationUnlocked($0) })
    }

    private func highlighted(_ location: ForestLocation) -> Bool {
        switch location {
        case .festivalGlade:
            return store.state.status(of: .epilogue) != .locked
        case .moonlitGarden:
            return store.isMoonlitGardenOpen
        case .greenhouse:
            return store.isLocationUnlocked(.greenhouse)
        default:
            return false
        }
    }

    private func visit(_ location: ForestLocation) {
        guard store.isLocationUnlocked(location) else {
            Haptics.warning()
            store.showToast(store.lockMessage(for: location))
            return
        }
        Haptics.tap()
        switch location {
        case .cabinKitchen:
            store.openCooking()
        case .greenhouse:
            store.openGreenhouse()
        default:
            store.openGathering(at: location)
        }
    }
}

struct LocationNode: View {
    let location: ForestLocation
    let locked: Bool
    var highlighted: Bool = false

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .fill(locked ? ForestPalette.pageEdge.opacity(0.7) : ForestPalette.parchment)
                    .shadow(color: ForestPalette.ink.opacity(locked ? 0 : 0.14), radius: 6, x: 0, y: 3)
                Circle()
                    .stroke(highlighted ? ForestPalette.terracotta : ForestPalette.sage.opacity(locked ? 0.25 : 0.55), lineWidth: highlighted ? 2 : 1.2)
                Image(systemName: location.symbolName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(locked ? ForestPalette.inkSoft.opacity(0.45) : ForestPalette.sageDeep)
            }
            .frame(width: 48, height: 48)

            Text(location.title)
                .font(.label(9))
                .foregroundStyle(locked ? ForestPalette.inkSoft.opacity(0.55) : ForestPalette.ink)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Capsule().fill(ForestPalette.parchment.opacity(0.8)))
        }
        .opacity(locked ? 0.85 : 1)
    }
}

struct ProgressBar: View {
    var value: Double
    var tint: Color = ForestPalette.sage

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(ForestPalette.pageEdge)
                Capsule()
                    .fill(tint)
                    .frame(width: max(4, geo.size.width * CGFloat(min(1, max(0, value)))))
            }
        }
        .frame(height: 7)
    }
}

extension ForestLocation {
    var symbolName: String {
        switch self {
        case .cabinKitchen: return "house.fill"
        case .berryPatch: return "leaf.fill"
        case .fireflyPond: return "drop.fill"
        case .owlLibrary: return "book.fill"
        case .festivalGlade: return "sparkles"
        case .moonlitGarden: return "moon.stars.fill"
        case .greenhouse: return "leaf.circle.fill"
        }
    }
}
