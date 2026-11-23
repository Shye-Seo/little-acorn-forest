import Foundation
import AcornForestCore

/// 실제 앱에서 쓰는 저장소. UserDefaults에 JSON 한 덩어리로 보관한다.
final class UserDefaultsSaveStore: SaveStore {
    static let defaultKey = "little-acorn-forest.save.v1"

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = UserDefaultsSaveStore.defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    func load() throws -> SaveFile? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try SaveCodec.decode(data)
    }

    func save(_ file: SaveFile) throws {
        let data = try SaveCodec.encode(file)
        defaults.set(data, forKey: key)
    }

    func delete() throws {
        defaults.removeObject(forKey: key)
    }

    func hasSave() -> Bool {
        defaults.data(forKey: key) != nil
    }
}
