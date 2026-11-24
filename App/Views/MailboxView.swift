import SwiftUI
import AcornForestCore

/// 현관 우체통. 날짜가 바뀌면 이웃이 편지와 선물을 두고 간다.
struct MailboxView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    introCard
                    if store.mailboxLetters.isEmpty {
                        emptyCard
                    } else {
                        ForEach(store.mailboxLetters) { letter in
                            letterCard(letter)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
        .onAppear {
            if store.mailboxLetters.isEmpty {
                store.checkMailbox()
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
                Text("현관 우체통")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text(store.mailBadgeCount > 0 ? "받지 않은 편지 \(store.mailBadgeCount)통" : "오늘은 조용해요")
                    .font(.story(11))
                    .foregroundStyle(store.mailBadgeCount > 0 ? ForestPalette.terracotta : ForestPalette.inkSoft)
            }
            Spacer()

            Button("새로 확인") {
                store.checkMailbox()
            }
            .buttonStyle(QuietButtonStyle())
        }
        .padding(.horizontal, 16)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionLabel(text: "밤사이 역선물")
                Spacer()
                Text(store.moonPhase.badgeLine)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Text("인사하는 사이(호감도 \(MailboxSystem.affinityThreshold))가 된 이웃은 밤사이 현관에 편지를 두고 갑니다. 가끔은 수첩에 없는 레시피 쪽지도 섞여 있어요.")
                .font(.story(12))
                .lineSpacing(4)
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text("배운 비밀 레시피 \(store.secretRecipeCount)/\(SecretRecipeBook.all.count)")
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.sage)
                Spacer()
                Button("하루 넘기기(테스트)") {
                    store.simulateNextDay()
                }
                .font(.label(10))
                .foregroundStyle(ForestPalette.inkSoft)
            }
        }
        .storybookCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Text("📮")
                .font(.system(size: 34))
            Text("아직 편지가 없어요")
                .font(.story(15, weight: .semibold))
                .foregroundStyle(ForestPalette.ink)
            Text("이웃과 인사하는 사이가 되면, 자는 사이에 현관에 뭔가를 두고 갑니다.")
                .font(.story(12))
                .multilineTextAlignment(.center)
                .foregroundStyle(ForestPalette.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .storybookCard(padding: 24)
    }

    private func letterCard(_ letter: MailboxLetter) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                CharacterPortrait(character: letter.sender, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(letter.title)
                        .font(.story(14, weight: .semibold))
                        .foregroundStyle(ForestPalette.ink)
                    Text(letter.isClaimed ? "받은 편지" : "아직 받지 않았어요")
                        .font(.label(9))
                        .foregroundStyle(letter.isClaimed ? ForestPalette.inkSoft : ForestPalette.terracotta)
                }
                Spacer()
                if letter.hasSecretRecipe {
                    Text("쪽지")
                        .font(.label(9))
                        .foregroundStyle(ForestPalette.parchment)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(ForestPalette.moonflake))
                }
            }

            Text(letter.note)
                .font(.story(13))
                .lineSpacing(4)
                .foregroundStyle(ForestPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(letter.previewLine)
                    .font(.label(10))
                    .foregroundStyle(ForestPalette.inkSoft)
                Spacer()
                if !letter.isClaimed {
                    Button("받기") {
                        store.claimLetter(id: letter.id)
                    }
                    .buttonStyle(QuietButtonStyle(tint: ForestPalette.terracotta))
                }
            }
        }
        .storybookCard()
    }
}
