import Foundation
import Combine
import StoreKit
import AcornForestCore

/// StoreKit 2 결제 창구. 게임 규칙은 `ContentPack`만 알고, 여기서는 상품 id만 다룬다.
/// 시뮬레이터에서 결제 화면을 거치지 않고 확인할 수 있도록 로컬 시뮬레이션 토글을 둔다.
@MainActor
final class StoreManager: ObservableObject {
    static let simulationKey = "little-acorn-forest.store.simulated"
    static let simulatedKey = "little-acorn-forest.store.simulated.ids"

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published var statusMessage: String?
    @Published var isSimulated: Bool {
        didSet {
            UserDefaults.standard.set(isSimulated, forKey: StoreManager.simulationKey)
        }
    }

    private var updatesTask: Task<Void, Never>?

    init() {
        self.isSimulated = UserDefaults.standard.bool(forKey: StoreManager.simulationKey)
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(update)
            }
        }
    }

    // MARK: - 상품

    func load() async {
        guard !isSimulated else {
            products = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: StoreCatalog.productIDs)
                .sorted { $0.price < $1.price }
            if products.isEmpty {
                statusMessage = "App Store에 등록된 상품을 찾지 못했어요. Products.storekit을 확인해 주세요."
            }
        } catch {
            statusMessage = "상점을 불러오지 못했어요. (\(error.localizedDescription))"
        }
    }

    func product(for pack: ContentPack) -> Product? {
        products.first { $0.id == pack.productID }
    }

    /// App Store 가격이 있으면 그 문구를, 없으면 카탈로그 가격을 쓴다.
    func priceLine(for pack: ContentPack) -> String {
        product(for: pack)?.displayPrice ?? pack.priceLine
    }

    // MARK: - 구매

    func purchase(_ pack: ContentPack) async -> Bool {
        statusMessage = nil
        if isSimulated {
            addSimulated(pack.productID)
            statusMessage = "로컬 시뮬레이션으로 「\(pack.displayName)」을(를) 열었어요."
            return true
        }

        var product = product(for: pack)
        if product == nil {
            product = try? await Product.products(for: [pack.productID]).first
            if let product {
                products.append(product)
            }
        }
        guard let product else {
            statusMessage = "이 상품이 아직 App Store에 없어요. (\(pack.productID))"
            return false
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    statusMessage = "구매 확인에 실패했어요. 잠시 뒤 다시 시도해 주세요."
                    return false
                }
                ownedProductIDs.insert(transaction.productID)
                await transaction.finish()
                return true
            case .pending:
                statusMessage = "구매가 승인 대기 중이에요. 승인되면 자동으로 열립니다."
                return false
            case .userCancelled:
                statusMessage = "구매를 취소했어요."
                return false
            @unknown default:
                statusMessage = "구매 결과를 확인하지 못했어요."
                return false
            }
        } catch {
            statusMessage = "구매를 마치지 못했어요. (\(error.localizedDescription))"
            return false
        }
    }

    // MARK: - 복원

    func currentEntitlements() async -> Set<String> {
        var owned = simulatedProductIDs()
        if !isSimulated {
            for await result in Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    owned.insert(transaction.productID)
                }
            }
        }
        ownedProductIDs = owned
        return owned
    }

    func restore() async -> Set<String> {
        if !isSimulated {
            do {
                try await AppStore.sync()
            } catch {
                statusMessage = "구매 복원에 실패했어요. (\(error.localizedDescription))"
            }
        }
        return await currentEntitlements()
    }

    // MARK: - 트랜잭션 감시

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        if transaction.revocationDate == nil {
            ownedProductIDs.insert(transaction.productID)
        } else {
            ownedProductIDs.remove(transaction.productID)
        }
        await transaction.finish()
    }

    // MARK: - 로컬 시뮬레이션

    func simulatedProductIDs() -> Set<String> {
        let stored = UserDefaults.standard.stringArray(forKey: StoreManager.simulatedKey) ?? []
        return Set(stored)
    }

    func addSimulated(_ productID: String) {
        var ids = simulatedProductIDs()
        ids.insert(productID)
        UserDefaults.standard.set(Array(ids), forKey: StoreManager.simulatedKey)
        ownedProductIDs.insert(productID)
    }

    func clearSimulation() {
        UserDefaults.standard.removeObject(forKey: StoreManager.simulatedKey)
        ownedProductIDs = []
    }
}
