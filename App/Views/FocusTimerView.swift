import SwiftUI
import AcornForestCore

/// 오두막 모닥불 집중 타이머. 5·15·25분 동안 배경 소리를 틀어 두고, 끝나면 반딧불이 가루를 받는다.
struct FocusTimerView: View {
    @EnvironmentObject private var store: GameStore

    @State private var duration: FocusDuration = .fifteen
    @State private var track: AmbientTrack = .hearth
    @State private var muted = false

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let reward = store.lastReward {
                        rewardCard(reward)
                    } else if let session = store.focusSession {
                        runningCard(session)
                    } else {
                        setupCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
        .task(id: store.focusSession != nil) {
            await focusLoop()
        }
        .onDisappear {
            store.stopFocusAudio()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.stopFocusAudio()
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
                Text("모닥불 집중 타이머")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("불은 재촉하지 않는다 — 할머니의 수첩")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            Text("🪶 \(store.fireflyDust)")
                .font(.label(11))
                .foregroundStyle(ForestPalette.sage)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Capsule().fill(ForestPalette.sage.opacity(0.12)))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 설정

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                SectionLabel(text: "얼마나 앉아 있을까요")
                HStack(spacing: 8) {
                    ForEach(FocusDuration.allCases) { option in
                        Button {
                            duration = option
                            Haptics.tap()
                        } label: {
                            VStack(spacing: 3) {
                                Text(option.emoji)
                                    .font(.system(size: 18))
                                Text(option.title)
                                    .font(.label(11))
                                    .foregroundStyle(duration == option ? ForestPalette.parchment : ForestPalette.ink)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    .fill(duration == option ? ForestPalette.sage : ForestPalette.parchmentDeep.opacity(0.45))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text(duration.note)
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SectionLabel(text: "배경 소리")
                    Spacer()
                    if !store.ownsASMR {
                        Button("트랙 팩 보기") {
                            store.openStore()
                        }
                        .font(.label(10))
                        .foregroundStyle(ForestPalette.terracotta)
                    }
                }
                FlowChips(tracks: store.unlockedTracks, selected: track) { picked in
                    track = picked
                    Haptics.tap()
                }
                if !store.ownsASMR {
                    Text("밤벌레·풍경소리는 「모닥불 ASMR 트랙 팩」에서 열려요.")
                        .font(.story(11))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Text(track.note)
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(ForestPalette.honey)
                Text(rewardPreview.message)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
                Spacer()
            }

            Button("불을 피우고 앉기") {
                store.startFocus(duration, track: track)
            }
            .buttonStyle(StorybookButtonStyle())
        }
        .storybookCard()
    }

    private var rewardPreview: FocusReward {
        if let live = store.focusRewardPreview { return live }
        return FocusRules.reward(
            for: duration,
            track: track,
            ownsASMRPack: store.ownsASMR,
            isFullMoon: store.moonPhase.isFullMoon
        )
    }

    // MARK: - 진행 중

    private func runningCard(_ session: FocusSession) -> some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(store.cabinStyle.wallColor.opacity(0.55))
                FireGlow(strength: 1 - session.progress * 0.35)
                    .offset(y: 26)
                if session.track == .rain {
                    RainOverlay(intensity: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                VStack(spacing: 4) {
                    Text(session.timeLabel)
                        .font(.system(size: 44, weight: .light, design: .rounded))
                        .foregroundStyle(ForestPalette.ink)
                    Text("\(session.track.emoji) \(session.track.title)")
                        .font(.label(11))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                .offset(y: -30)
            }
            .frame(height: 260)

            ProgressBar(value: session.progress, tint: ForestPalette.terracotta)
                .padding(.horizontal, 22)

            HStack(spacing: 10) {
                Text(session.duration.title)
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.inkSoft)

                Button {
                    muted.toggle()
                    if muted {
                        ForestAudio.shared.stopAmbient()
                    } else {
                        ForestAudio.shared.playAmbient(session.track)
                    }
                    Haptics.tap()
                } label: {
                    Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(muted ? ForestPalette.inkSoft : ForestPalette.sage)
                        .frame(width: 30, height: 26)
                        .background(Capsule().fill(ForestPalette.parchmentDeep.opacity(0.6)))
                }
                .buttonStyle(.plain)

                Spacer()
                Text(session.isAlmostDone ? "거의 다 왔어요" : "숨을 고르세요")
                    .font(.story(12))
                    .foregroundStyle(session.isAlmostDone ? ForestPalette.terracotta : ForestPalette.inkSoft)
            }
            .padding(.horizontal, 22)

            Button("그만두기") {
                store.cancelFocus()
            }
            .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
        }
        .storybookCard(padding: 14)
    }

    // MARK: - 보상

    private func rewardCard(_ reward: FocusReward) -> some View {
        VStack(spacing: 12) {
            Text("🔥")
                .font(.system(size: 40))
            Text("\(reward.duration.title)을 채웠어요")
                .font(.story(20, weight: .semibold))
                .foregroundStyle(ForestPalette.ink)
            Text(reward.message)
                .font(.story(13))
                .multilineTextAlignment(.center)
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                statChip(title: "반딧불이 가루", value: "+\(reward.fireflyDust)")
                statChip(title: "총 세션", value: "\(store.focusSessions)")
            }

            Button("한 번 더 앉기") {
                store.clearFocusReward()
            }
            .buttonStyle(StorybookButtonStyle())
            Button("숲 지도로") {
                store.clearFocusReward()
                store.back()
            }
            .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
        }
        .storybookCard(padding: 22)
    }

    private func statChip(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.label(14))
                .foregroundStyle(ForestPalette.sage)
            Text(title)
                .font(.label(9))
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(ForestPalette.parchmentDeep.opacity(0.5))
        )
    }

    // MARK: - 타이머 루프

    @MainActor
    private func focusLoop() async {
        muted = false
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard let session = store.focusSession else { return }
            if session.isFinished {
                store.finishFocus()
                return
            }
            store.tickFocus(1)
            if let updated = store.focusSession, updated.isFinished {
                store.finishFocus()
                return
            }
        }
    }
}

/// 배경 소리 칩 묶음. 좁은 화면에서도 두 줄로 접힌다.
struct FlowChips: View {
    let tracks: [AmbientTrack]
    let selected: AmbientTrack
    var onPick: (AmbientTrack) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(0..<rowCount, id: \.self) { row in
                HStack(spacing: 7) {
                    ForEach(chunk(row)) { track in
                        Button {
                            onPick(track)
                        } label: {
                            Text("\(track.emoji) \(track.title)")
                                .font(.label(10))
                                .foregroundStyle(selected == track ? ForestPalette.parchment : ForestPalette.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(selected == track ? ForestPalette.terracotta : ForestPalette.parchmentDeep.opacity(0.55))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var rowCount: Int {
        (tracks.count + 2) / 3
    }

    private func chunk(_ row: Int) -> [AmbientTrack] {
        let start = row * 3
        guard start < tracks.count else { return [] }
        let end = min(start + 3, tracks.count)
        return Array(tracks[start..<end])
    }
}
