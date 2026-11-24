import SwiftUI
import AcornForestCore

/// 숲속 채집. 세 갈래 길로 떨어지는 재료를 도착 순간에 받아 낸다.
struct GatheringGameView: View {
    @EnvironmentObject private var store: GameStore
    @State private var summary: GatheringSummary?

    private let laneTints: [Color] = [ForestPalette.sage, ForestPalette.terracotta, ForestPalette.honey]

    var body: some View {
        VStack(spacing: 10) {
            header

            HStack {
                MoonBadgeView(showsDetail: false)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)

            if let summary {
                summaryCard(summary)
            } else if let session = store.gathering {
                hud(session)
                field(session)
                laneBar(session)
            } else {
                Spacer()
                ProgressView().tint(ForestPalette.sage)
                Spacer()
            }
        }
        .padding(.top, 6)
        .task(id: store.gathering != nil) {
            await gameLoop()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.leaveGathering()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.gathering?.location.title ?? "숲속 채집")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("떨어지는 재료를 바구니로 받아 보세요")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            Text("🌙 \(store.moonlightEnergy)/\(store.maxEnergy)")
                .font(.label(10))
                .foregroundStyle(ForestPalette.sage)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(ForestPalette.parchment.opacity(0.9)))
            if let session = store.gathering {
                Text(AppText.timer(session.remaining))
                    .font(.label(13))
                    .foregroundStyle(session.isAlmostOver ? ForestPalette.terracotta : ForestPalette.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(ForestPalette.parchment.opacity(0.9)))
            }
        }
        .padding(.horizontal, 16)
    }

    private func hud(_ session: GatheringSession) -> some View {
        VStack(spacing: 6) {
            HStack {
                Label("\(session.score)", systemImage: "star.fill")
                    .font(.label(13))
                    .foregroundStyle(ForestPalette.honey)
                Spacer()
                if session.streak > 1 {
                    Text("연속 \(session.streak)")
                        .font(.label(11))
                        .foregroundStyle(ForestPalette.terracotta)
                }
                Text("\(session.caughtCount)개 담음")
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            ProgressBar(value: session.progress, tint: ForestPalette.terracotta)
        }
        .padding(.horizontal, 18)
    }

    private func field(_ session: GatheringSession) -> some View {
        GeometryReader { geo in
            ZStack {
                HStack(spacing: 6) {
                    ForEach(0..<GatheringSession.laneCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(laneTints[index].opacity(0.10))
                    }
                }

                ForEach(session.items.filter { !$0.isResolved && session.fallProgress(of: $0) >= 0 }) { item in
                    FallingIngredientView(ingredient: item.ingredient, golden: item.isGolden)
                        .position(point(for: item, session: session, size: geo.size))
                }

                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<GatheringSession.laneCount, id: \.self) { index in
                            BasketView(tint: laneTints[index])
                                .frame(height: 42)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 6)
                }

                if session.isFinished {
                    finishedOverlay
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private var finishedOverlay: some View {
        VStack(spacing: 10) {
            Text("해가 저물었어요")
                .font(.story(19, weight: .semibold))
                .foregroundStyle(ForestPalette.ink)
            Text("바구니를 정리해 볼까요?")
                .font(.story(13))
                .foregroundStyle(ForestPalette.inkSoft)
            Button("바구니에 담기") {
                Haptics.success()
                summary = store.collectGathering()
            }
            .buttonStyle(StorybookButtonStyle())
            .padding(.horizontal, 40)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(ForestPalette.parchment.opacity(0.96))
                .shadow(color: ForestPalette.ink.opacity(0.18), radius: 18, x: 0, y: 8)
        )
        .padding(28)
    }

    private func laneBar(_ session: GatheringSession) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<GatheringSession.laneCount, id: \.self) { lane in
                Button {
                    store.tapLane(lane)
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "basket.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(laneTints[lane])
                        Text("\(lane + 1)번 길")
                            .font(.label(10))
                            .foregroundStyle(ForestPalette.inkSoft)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ForestPalette.parchment.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(laneTints[lane].opacity(0.35), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(session.isFinished)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
        .opacity(session.isFinished ? 0.4 : 1)
    }

    private func summaryCard(_ summary: GatheringSummary) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                Text(summary.headline)
                    .font(.story(21, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(ForestPalette.ink)
                Text(AppText.summaryLine(summary))
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)

                HStack(spacing: 18) {
                    statBlock(title: "점수", value: "\(summary.score)")
                    statBlock(title: "최고 연속", value: "\(summary.bestStreak)")
                    statBlock(title: "놓침", value: "\(summary.missedCount)")
                }

                if summary.harvest.isEmpty && summary.bonus.isEmpty {
                    Text("바구니가 비었어요. 다음엔 조금 더 천천히 와도 괜찮아요.")
                        .font(.story(13))
                        .foregroundStyle(ForestPalette.inkSoft)
                        .multilineTextAlignment(.center)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(text: "바구니")
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(summary.harvest) { stack in
                                ItemChip(stack: stack)
                            }
                        }
                        if !summary.bonus.isEmpty {
                            Text("보너스")
                                .font(.label(10))
                                .foregroundStyle(ForestPalette.terracotta)
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                                ForEach(summary.bonus) { stack in
                                    ItemChip(stack: stack)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("숲 지도로 돌아가기") {
                    store.leaveGathering()
                }
                .buttonStyle(StorybookButtonStyle())
                .padding(.top, 4)
            }
            .storybookCard(padding: 22)
            .padding(.horizontal, 18)
            .padding(.top, 20)
        }
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.story(20, weight: .semibold))
                .foregroundStyle(ForestPalette.sageDeep)
            Text(title)
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
        }
    }

    private func point(for item: GatherItem, session: GatheringSession, size: CGSize) -> CGPoint {
        let laneWidth = size.width / CGFloat(GatheringSession.laneCount)
        let x = laneWidth * (CGFloat(item.lane) + 0.5)
        let progress = CGFloat(max(0, min(1, session.fallProgress(of: item))))
        let y = (size.height - 56) * progress + 16
        return CGPoint(x: x, y: y)
    }

    @MainActor
    private func gameLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard let session = store.gathering else { return }
            if session.isFinished { return }
            store.tickGathering(1.0 / 60.0)
        }
    }
}
