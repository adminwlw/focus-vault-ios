import Foundation
import UniformTypeIdentifiers

enum FocusPhase: String, Codable {
    case idle
    case running
    case paused
    case finished
}

struct FocusTimerState: Codable, Equatable {
    var taskName = "计时"
    var plannedSeconds = 25 * 60
    var remainingWhenPaused = 25 * 60
    var endDate: Date?
    var startedAt: Date?
    var phase: FocusPhase = .idle
    var sessionID: UUID?
}

struct FocusSession: Codable, Identifiable, Equatable {
    enum Outcome: String, Codable {
        case completed
        case endedEarly
    }

    let id: UUID
    let taskName: String
    let startedAt: Date
    let endedAt: Date
    let plannedSeconds: Int
    let focusedSeconds: Int
    let outcome: Outcome
}

enum VaultMediaKind: String, Codable {
    case photo
    case video
}

struct VaultItem: Codable, Identifiable, Hashable {
    var id: UUID
    var originalName: String
    var importedAt: Date
    var capturedAt: Date?
    var mediaKind: VaultMediaKind
    var byteCount: Int
    var albumName: String?
    var isFavorite: Bool
    var deletedAt: Date?
}

struct VaultBackupPayload: Codable {
    let version: Int
    let createdAt: Date
    let items: [VaultItem]
    let media: [String: Data]
    var albums: [String]? = nil
}

struct VaultIndex: Codable {
    var version = 2
    var items: [VaultItem]
    var albums: [String]
}

struct VaultBackupEnvelope: Codable {
    let format: String
    let version: Int
    let salt: Data
    let iterations: Int
    let encryptedPayload: Data
}

extension UTType {
    static let focusVaultBackup = UTType(exportedAs: "com.sim360.focusvault.backup")
}

