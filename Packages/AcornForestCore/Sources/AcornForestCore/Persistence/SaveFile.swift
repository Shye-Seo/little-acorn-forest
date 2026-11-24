import Foundation

/// 저장 파일 한 덩어리. 상태와 저장 시각만 담는다.
public struct SaveFile: Codable, Sendable, Equatable {
    public var formatVersion: Int
    public var state: GameState
    public var savedAt: Date

    public init(state: GameState, savedAt: Date = Date()) {
        self.formatVersion = GameState.currentFormatVersion
        self.state = state
        self.savedAt = savedAt
    }
}

/// 저장소 인터페이스. 앱은 UserDefaults, 테스트는 메모리를 쓴다.
public protocol SaveStore: AnyObject {
    func load() throws -> SaveFile?
    func save(_ file: SaveFile) throws
    func delete() throws
    func hasSave() -> Bool
}

public enum SaveError: Error, Equatable {
    case corrupted
    case unsupportedVersion(Int)

    public var message: String {
        switch self {
        case .corrupted:
            return "저장 파일을 읽지 못했어요. 새 이야기로 시작할 수 있습니다."
        case .unsupportedVersion(let version):
            return "이 저장 파일은 더 새로운 버전(\(version))이에요. 앱을 업데이트해 주세요."
        }
    }
}

public enum SaveCodec {
    public static let dateStrategy: JSONEncoder.DateEncodingStrategy = .iso8601
    public static let decodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601

    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = dateStrategy
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = decodingStrategy
        return decoder
    }

    public static func encode(_ file: SaveFile) throws -> Data {
        try makeEncoder().encode(file)
    }

    public static func decode(_ data: Data) throws -> SaveFile {
        do {
            let file = try makeDecoder().decode(SaveFile.self, from: data)
            guard file.formatVersion <= SaveFile(state: GameState()).formatVersion else {
                throw SaveError.unsupportedVersion(file.formatVersion)
            }
            var restored = file
            restored.state.normalize()
            return restored
        } catch let error as SaveError {
            throw error
        } catch {
            throw SaveError.corrupted
        }
    }
}

/// 테스트용 저장소. 저장 횟수까지 세어 자동 저장을 검증한다.
public final class InMemorySaveStore: SaveStore {
    public private(set) var file: SaveFile?
    public private(set) var saveCount: Int = 0
    public private(set) var deleteCount: Int = 0

    public init(file: SaveFile? = nil) {
        self.file = file
    }

    public func load() throws -> SaveFile? {
        file
    }

    public func save(_ file: SaveFile) throws {
        self.file = file
        saveCount += 1
    }

    public func delete() throws {
        file = nil
        deleteCount += 1
    }

    public func hasSave() -> Bool {
        file != nil
    }
}
