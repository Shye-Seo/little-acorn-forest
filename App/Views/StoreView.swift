import SwiftUI
import AcornForestCore

/// 확장팩 상점. StoreKit 2 상품 3종과, 시뮬레이터에서 확인할 수 있는 로컬 구매 토글.
struct StoreView: View {
    @EnvironmentObject private var store: GameStore
    @EnvironmentObject private var purchases: StoreManager

    @State private var pendingPack: ContentPack?

    var body: some View {
        VStack(spacing: 8) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    introCard
                    ForEach(StoreCatalog.all) { pack in
                        productCard(pack)
                    }
                    toolsCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .padding(.top, 6)
        .task {
            await store.prepareStore()
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
                Text("오두막 상점")
                    .font(.story(16, weight: .semibold))
                    .foregroundStyle(ForestPalette.ink)
                Text("이야기는 그대로, 숲이 조금 넓어집니다")
                    .font(.story(11))
                    .foregroundStyle(ForestPalette.inkSoft)
            }
            Spacer()
            if purchases.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "확장 콘텐츠")
            Text("프롤로그부터 에필로그까지의 무료 플레이는 그대로입니다. 아래 세 가지는 그 뒤에 숲에서 할 일을 늘리는 확장팩이에요.")
                .font(.story(13))
                .lineSpacing(4)
                .foregroundStyle(ForestPalette.ink)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ownedBadge("온실", owned: store.ownsGreenhouse)
                ownedBadge("병 공방", owned: store.ownsWorkshop)
                ownedBadge("ASMR", owned: store.ownsASMR)
                Spacer()
            }
        }
        .storybookCard()
    }

    private func ownedBadge(_ title: String, owned: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: owned ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 9))
            Text(title)
                .font(.label(9))
        }
        .foregroundStyle(owned ? ForestPalette.sage : ForestPalette.inkSoft)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(ForestPalette.parchmentDeep.opacity(0.55)))
    }

    private func productCard(_ pack: ContentPack) -> some View {
        let owned = store.owns(pack)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Text(pack.emoji)
                    .font(.system(size: 26))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(ForestPalette.parchmentDeep.opacity(0.6)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(pack.displayName)
                        .font(.story(16, weight: .semibold))
                        .foregroundStyle(ForestPalette.ink)
                    Text(pack.tagline)
                        .font(.story(11))
                        .foregroundStyle(ForestPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(pack.contents, id: \.self) { line in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(ForestPalette.sage)
                            .padding(.top, 4)
                        Text(line)
                            .font(.story(12))
                            .foregroundStyle(ForestPalette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }

            HStack(spacing: 10) {
                Text(purchases.isSimulated ? pack.priceLine : purchases.priceLine(for: pack))
                    .font(.label(14))
                    .foregroundStyle(ForestPalette.ink)

                Spacer()

                if owned {
                    Text("보유 중")
                        .font(.label(11))
                        .foregroundStyle(ForestPalette.parchment)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule().fill(ForestPalette.sage))
                } else {
                    Button {
                        pendingPack = pack
                    } label: {
                        Text("구매")
                            .font(.label(12))
                            .foregroundStyle(ForestPalette.parchment)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(ForestPalette.terracotta))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .storybookCard()
        .alert("「\(pack.displayName)」을(를) 열까요?", isPresented: Binding(
            get: { pendingPack == pack },
            set: { if !$0 { pendingPack = nil } }
        )) {
            Button("취소", role: .cancel) { pendingPack = nil }
            Button("구매") {
                pendingPack = nil
                Task { await store.buy(pack) }
            }
        } message: {
            Text("\(purchases.isSimulated ? pack.priceLine : purchases.priceLine(for: pack)) · 한 번 사면 계속 열려 있어요. 잼 스토리는 무료 그대로입니다.")
        }
    }

    private var toolsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "구매 관리")
            if let message = purchases.statusMessage {
                Text(message)
                    .font(.story(12))
                    .foregroundStyle(ForestPalette.terracotta)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Toggle(isOn: $purchases.isSimulated) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("로컬 구매 시뮬레이션")
                        .font(.story(13))
                        .foregroundStyle(ForestPalette.ink)
                    Text("시뮬레이터·테스트에서 결제 화면 없이 열어 봅니다. 실제 App Store 결제는 일어나지 않아요.")
                        .font(.story(10))
                        .foregroundStyle(ForestPalette.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .tint(ForestPalette.sage)

            HStack(spacing: 10) {
                Button("구매 복원") {
                    Task { await store.restorePurchases() }
                }
                .buttonStyle(QuietButtonStyle())

                Button("상품 새로고침") {
                    Task { await purchases.load() }
                }
                .buttonStyle(QuietButtonStyle(tint: ForestPalette.inkSoft))
                Spacer()
            }

            Text("상품 id · \(StoreCatalog.productIDs.joined(separator: ", "))")
                .font(.label(9))
                .foregroundStyle(ForestPalette.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .storybookCard()
    }
}
