import SwiftUI
import AcornForestCore

/// 일러스트 대화창 + 선택지.
struct StoryView: View {
    @EnvironmentObject private var store: GameStore
    @State private var revealed: Int = 0

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    if let summary = store.sceneSummary {
                        sceneEndCard(summary)
                    } else if let completion = store.completion {
                        completionCard(completion)
                    } else if let beat = store.storyStep?.beat {
                        beatView(beat)
                        choicesView
                    } else {
                        ProgressView()
                            .tint(ForestPalette.sage)
                            .padding(.top, 60)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                store.leaveStory()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ForestPalette.sage)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(ForestPalette.parchment.opacity(0.9)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(store.storyStep?.beat?.chapter.shortTitle ?? store.chapterTitle)
                    .font(.story(15, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text(store.storyStep?.beat?.sceneTitle ?? "이야기")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            if let beat = store.storyStep?.beat {
                Text(beat.progressLabel)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .padding(.horizontal, 16)
    }

    private func beatView(_ beat: StoryBeat) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                speakerPortrait(beat)
                VStack(alignment: .leading, spacing: 2) {
                    Text(beat.line.speaker.isNarration ? "이야기" : beat.line.speaker.displayName)
                        .font(.story(15, weight: .semibold))
                        .foregroundStyle(ForestPalette.ink)
                    Text(beat.line.speaker.isNarration ? "조용히 흐르는 장면" : speakerNote(beat))
                        .font(.story(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(displayText(for: beat))
                    .font(.story(17))
                    .lineSpacing(7)
                    .foregroundStyle(ForestPalette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(nil, value: revealed)

                HStack {
                    Spacer()
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 15))
                        .foregroundStyle(ForestPalette.sage.opacity(0.55))
                }
            }
            .storybookCard(padding: 20)
            .onTapGesture { advance() }
        }
        .task(id: beat.line.id) {
            await typeOut(beat)
        }
    }

    @ViewBuilder
    private func speakerPortrait(_ beat: StoryBeat) -> some View {
        if let character = beat.line.speaker.character {
            CharacterPortrait(character: character, size: 62)
        } else if beat.line.speaker == .bori {
            PlayerPortrait(size: 62)
        } else {
            ZStack {
                Circle().fill(ForestPalette.sage.opacity(0.12))
                Image(systemName: "leaf")
                    .font(.system(size: 18))
                    .foregroundStyle(ForestPalette.sage)
            }
            .frame(width: 48, height: 48)
        }
    }

    private func speakerNote(_ beat: StoryBeat) -> String {
        guard let character = beat.line.speaker.character else { return "" }
        return character.species
    }

    @ViewBuilder
    private var choicesView: some View {
        if store.isAwaitingChoice {
            VStack(spacing: 8) {
                SectionLabel(text: "어떻게 말할까요")
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(Array(store.storyChoices.enumerated()), id: \.offset) { index, choice in
                    Button {
                        guard revealed >= (store.storyStep?.beat?.line.text.count ?? 0) else {
                            revealed = store.storyStep?.beat?.line.text.count ?? 0
                            return
                        }
                        store.chooseStoryOption(at: index)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.label(11))
                                .foregroundStyle(ForestPalette.sage)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(ForestPalette.sage.opacity(0.14)))
                            Text(choice.text)
                                .font(.story(15))
                                .foregroundStyle(ForestPalette.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(ForestPalette.parchment)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(ForestPalette.sageLight.opacity(0.7), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 2)
        }
    }

    private func sceneEndCard(_ summary: SceneSummary) -> some View {
        VStack(spacing: 12) {
            Text("한 장면을 마쳤어요")
                .font(.story(20, weight: .semibold))
                .foregroundStyle(ForestPalette.ink)
            StitchedDivider()
            Text(summary.thought)
                .font(.story(15))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(ForestPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !summary.gained.isEmpty {
                HStack(spacing: 6) {
                    ForEach(summary.gained) { stack in
                        ItemChip(stack: stack)
                    }
                }
            }
            if !summary.unlockedDiary.isEmpty {
                Text("일기장에 \(summary.unlockedDiary.count)칸이 채워졌어요")
                    .font(.label(11))
                    .foregroundStyle(ForestPalette.terracotta)
            }

            Button("계속") {
                store.continueAfterScene()
            }
            .buttonStyle(StorybookButtonStyle())
            .padding(.top, 4)
        }
        .storybookCard(padding: 22)
        .padding(.top, 30)
    }

    private func completionCard(_ completion: ChapterCompletion) -> some View {
        VStack(spacing: 12) {
            Text(completion.chapter == .epilogue ? "이야기의 끝" : "\(completion.chapter.shortTitle) 완료")
                .font(.label(11))
                .tracking(1.6)
                .foregroundStyle(ForestPalette.terracotta)
            Text(completion.message)
                .font(.story(17))
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(ForestPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
            StitchedDivider()
            HStack(spacing: 10) {
                ForEach(CharacterID.allCases) { character in
                    VStack(spacing: 2) {
                        CharacterPortrait(character: character, size: 44)
                        Text(character.name).font(.label(9)).foregroundStyle(ForestPalette.inkSoft)
                    }
                }
            }
            if let next = completion.nextChapter {
                Text("다음은 \(next.title)")
                    .font(.story(13))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Button("숲 지도로") {
                store.closeCompletion()
            }
            .buttonStyle(StorybookButtonStyle())
            .padding(.top, 4)
        }
        .storybookCard(padding: 22)
        .padding(.top, 30)
    }

    private func displayText(for beat: StoryBeat) -> String {
        let text = beat.line.text
        guard revealed < text.count else { return text }
        return String(text.prefix(revealed))
    }

    private func advance() {
        guard let beat = store.storyStep?.beat else { return }
        if revealed < beat.line.text.count {
            revealed = beat.line.text.count
            return
        }
        store.advanceStory()
    }

    @MainActor
    private func typeOut(_ beat: StoryBeat) async {
        revealed = 0
        let count = beat.line.text.count
        var index = 0
        while index < count {
            try? await Task.sleep(nanoseconds: 14_000_000)
            if Task.isCancelled { return }
            index += 1
            revealed = index
        }
    }
}

struct ItemChip: View {
    let stack: ItemStack

    var body: some View {
        Text("\(stack.ingredient.emoji) \(stack.ingredient.title) \(stack.count)")
            .font(.label(11))
            .foregroundStyle(ForestPalette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(stack.ingredient.tint.opacity(0.16)))
    }
}
