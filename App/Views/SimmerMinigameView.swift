import SwiftUI
import AcornForestCore

/// 솥단지 마무리. 온도 바 위의 바늘을 황금 구간에 맞춰 두 가지 손짓으로 잡는다.
struct SimmerPhaseView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 12) {
            if let game = store.simmer {
                playfield(game)
            } else if let result = store.lastSimmer {
                resultCard(result)
            }
        }
    }

    // MARK: - 플레이

    private func playfield(_ game: SimmerMinigame) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("마무리 불 조절")
                    .font(.story(15, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Spacer()
                Text(AppText.timer(game.remaining))
                    .font(.label(12))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            VStack(spacing: 6) {
                Text(requestLine(game))
                    .font(.story(14, weight: .medium))
                    .foregroundStyle(ForestPalette.ink)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(ForestPalette.butter.opacity(0.45))
                    )
                Text("바늘이 초록 구간에 올 때, 부탁에 맞는 손짓을 눌러 주세요.")
                    .font(.story(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            SimmerGauge(game: game)
                .frame(height: 54)
                .padding(.horizontal, 2)

            HStack(spacing: 8) {
                requestBadge(game)
                Spacer()
                Label("\(game.score)", systemImage: "sparkles")
                    .font(.label(12))
                    .foregroundStyle(ForestPalette.honey)
            }

            HStack(spacing: 10) {
                ForEach(SimmerAction.allCases) { action in
                    actionButton(action, game: game)
                }
            }

            ProgressBar(value: game.progress, tint: ForestPalette.terracotta)
                .padding(.horizontal, 2)

            Text("부탁 \(min(game.index + 1, SimmerMinigame.requestCount))/\(SimmerMinigame.requestCount) · 놓침 \(game.misses) · 헛손 \(game.fumbles)")
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(ForestPalette.parchmentDeep.opacity(0.45))
        )
        .task {
            await simmerLoop()
        }
    }

    private func requestLine(_ game: SimmerMinigame) -> String {
        guard let request = game.currentRequest else { return "솥이 조용해요. 마지막 숨을 고르세요." }
        guard game.isAwaitingPress else { return "곧 부탁이 와요. 바늘을 지켜보세요." }
        return request.action.hint
    }

    private func requestBadge(_ game: SimmerMinigame) -> some View {
        HStack(spacing: 4) {
            Text(game.currentRequest?.action.emoji ?? "🍯")
                .font(.system(size: 12))
            Text(game.currentRequest?.action.title ?? "잠깐 쉬기")
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Capsule().fill(ForestPalette.parchment.opacity(0.9)))
    }

    private func actionButton(_ action: SimmerAction, game: SimmerMinigame) -> some View {
        let wanted = game.currentRequest?.action == action && game.isAwaitingPress
        return Button {
            store.pressSimmer(action)
        } label: {
            VStack(spacing: 4) {
                Text(action.emoji)
                    .font(.system(size: 20))
                Text(action.title)
                    .font(.story(13, weight: .semibold))
            }
            .foregroundStyle(wanted ? ForestPalette.parchment : ForestPalette.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(wanted ? ForestPalette.terracotta : ForestPalette.parchment)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(wanted ? ForestPalette.terracotta : ForestPalette.pageEdge, lineWidth: 1)
                    )
            )
            .shadow(color: wanted ? ForestPalette.terracotta.opacity(0.3) : .clear, radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .disabled(game.isFinished)
    }

    // MARK: - 결과

    private func resultCard(_ result: SimmerOutcome) -> some View {
        VStack(spacing: 10) {
            Text("\(result.grade.emoji) \(result.grade.title)")
                .font(.story(19, weight: .semibold))
                .foregroundStyle(result.grade == .golden ? ForestPalette.sage : ForestPalette.ink)
            Text(result.grade.note)
                .font(.story(12))
                .multilineTextAlignment(.center)
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Text(result.summaryLine)
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
            Text("마무리 점수 \(result.score)/\(result.maxScore)")
                .font(.label(11))
                .foregroundStyle(ForestPalette.terracotta)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(result.grade == .golden ? ForestPalette.butter.opacity(0.45) : ForestPalette.parchmentDeep.opacity(0.45))
        )
    }

    @MainActor
    private func simmerLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 33_000_000)
            guard let game = store.simmer else { return }
            if game.isFinished {
                store.finishSimmer()
                return
            }
            store.tickSimmer(1.0 / 30.0)
        }
    }
}

/// 황금 구간이 표시된 온도 바와 바늘.
struct SimmerGauge: View {
    let game: SimmerMinigame

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ForestPalette.dew.opacity(0.55),
                                     ForestPalette.butter.opacity(0.8),
                                     ForestPalette.terracotta.opacity(0.75)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                if let request = game.currentRequest {
                    let start = width * CGFloat(request.bandStart)
                    let bandWidth = width * CGFloat(request.bandEnd - request.bandStart)
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(ForestPalette.sage.opacity(game.isAwaitingPress ? 0.55 : 0.22))
                        .frame(width: bandWidth, height: height)
                        .offset(x: start)

                    let goldenWidth = width * CGFloat(request.goldenBand.upperBound - request.goldenBand.lowerBound)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(ForestPalette.sage.opacity(game.isAwaitingPress ? 0.95 : 0.45))
                        .frame(width: goldenWidth, height: height * 0.55)
                        .offset(x: width * CGFloat(request.goldenBand.lowerBound),
                                y: height * 0.22)
                }

                Capsule()
                    .fill(ForestPalette.ink)
                    .frame(width: 3, height: height + 6)
                    .offset(x: max(0, min(width - 3, width * CGFloat(game.needle))), y: -3)
                    .shadow(color: ForestPalette.ink.opacity(0.25), radius: 3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
