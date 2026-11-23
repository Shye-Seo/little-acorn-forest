import SwiftUI
import AcornForestCore

/// 동화책 표지.
struct TitleView: View {
    @EnvironmentObject private var store: GameStore
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            ParchmentBackground()

            VStack(spacing: 0) {
                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    Text("달빛 잼")
                        .font(.story(17, weight: .medium))
                        .tracking(3)
                        .foregroundStyle(ForestPalette.inkSoft)
                    Text("항아리")
                        .font(.story(40, weight: .bold))
                        .foregroundStyle(ForestPalette.ink)
                    Text("Moonlight Jam Jar")
                        .font(.label(11))
                        .tracking(2)
                        .foregroundStyle(ForestPalette.sage)
                    StitchedDivider()
                        .frame(width: 140)
                        .padding(.top, 6)
                }
                .padding(.top, 12)

                Spacer(minLength: 12)

                illustration
                    .frame(maxWidth: .infinity)
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(ForestPalette.pageEdge, lineWidth: 1)
                    )
                    .shadow(color: ForestPalette.ink.opacity(0.12), radius: 14, x: 0, y: 8)
                    .padding(.horizontal, 18)

                Spacer(minLength: 12)

                VStack(spacing: 10) {
                    Button("새 이야기 시작") {
                        if store.hasSave {
                            confirmReset = true
                        } else {
                            Haptics.tap()
                            store.newGame()
                        }
                    }
                    .buttonStyle(StorybookButtonStyle())

                    Button("이어하기") {
                        Haptics.tap()
                        store.continueGame()
                    }
                    .buttonStyle(StorybookButtonStyle(tint: ForestPalette.terracotta))
                    .disabled(!store.hasSave)
                    .opacity(store.hasSave ? 1 : 0.45)

                    HStack(spacing: 10) {
                        Button("숲 일기장") {
                            store.openDiary(from: .title)
                        }
                        .buttonStyle(QuietButtonStyle())

                        if store.hasSave {
                            Button("기록 지우기") {
                                confirmReset = true
                            }
                            .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
                        }
                    }
                    .padding(.top, 2)

                    Text("할머니의 오두막에서 시작하는, 아주 느린 모험")
                        .font(.story(12))
                        .foregroundStyle(ForestPalette.inkSoft)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 14)
            }
        }
        .alert("처음부터 다시 시작할까요?", isPresented: $confirmReset) {
            Button("취소", role: .cancel) {}
            Button("새로 시작", role: .destructive) {
                store.newGame()
            }
        } message: {
            Text("지금 저장된 바구니와 호감도가 사라지고 프롤로그부터 시작합니다.")
        }
    }

    private var illustration: some View {
        ZStack {
            ForestBackdrop()
            CabinView()
                .frame(width: 210, height: 190)
                .offset(y: 26)
            FirefliesView(count: 18)
                .offset(y: 10)
            WindLeavesView(count: 7)
        }
        .background(ForestPalette.parchmentDeep)
    }
}
