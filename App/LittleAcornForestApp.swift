import SwiftUI
import AcornForestCore

@main
struct LittleAcornForestApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(store.purchases)
                .preferredColorScheme(.light)
                .tint(ForestPalette.sage)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack(alignment: .top) {
            ParchmentBackground()

            Group {
                switch store.screen {
                case .title: TitleView()
                case .map: ForestMapView()
                case .story: StoryView()
                case .gathering: GatheringGameView()
                case .cooking: CookingView()
                case .diary: DiaryView()
                case .neighbours: NeighboursView()
                case .shelf: ShelfView()
                case .mailbox: MailboxView()
                case .focus: FocusTimerView()
                case .store: StoreView()
                case .greenhouse: GreenhouseView()
                case .orders: DailyOrderBoardView()
                }
            }
            .transition(.opacity)

            if let toast = store.toast {
                ToastView(message: toast)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.26), value: store.screen)
        .animation(.easeInOut(duration: 0.22), value: store.toast)
        .task {
            await store.prepareStore()
        }
    }
}
