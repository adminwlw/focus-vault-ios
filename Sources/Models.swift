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

enum VaultMediaKind: String, Codable, Sendable {
    case photo
    case video
}

struct VaultItem: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var originalName: String
    var importedAt: Date
    var capturedAt: Date?
    var mediaKind: VaultMediaKind
    var byteCount: Int
    var albumName: String?
    var isFavorite: Bool
    var deletedAt: Date?
    var displayName: String? = nil
    var note: String? = nil
    var contentDigest: String? = nil
    var sourceIdentifier: String? = nil
    var originalState: OriginalState? = nil
    var originalCheckedAt: Date? = nil
    var videoDuration: Double? = nil
    var isChunked: Bool? = nil

    var title: String { displayName?.isEmpty == false ? displayName! : originalName }
    var originalStatus: String {
        switch originalState {
        case .kept: return "系统原件已保留（上次处理结果）"
        case .deletionSucceeded: return "系统删除请求已完成（上次处理结果）"
        case .notInLibrary: return "App 内拍摄，无系统照片原件"
        default: return "系统原件状态未确认"
        }
    }
    var remainingTrashDays: Int {
        guard let deletedAt else { return 30 }
        let days = ceil(deletedAt.addingTimeInterval(30 * 86_400).timeIntervalSinceNow / 86_400)
        return days.isFinite ? Int(max(0, min(30, days))) : 0
    }
}

enum OriginalState: String, Codable, Sendable {
    case kept, deletionSucceeded, notInLibrary, unknown
}

struct VaultImportResult {
    var importedIDs: [UUID] = []
    var duplicateIDs: [UUID] = []
    var failures: [String] = []
    var cancelled = false
}

struct VaultImportProgress {
    var total = 0
    var completed = 0
    var currentName = "准备导入"
    var cancelling = false
}

enum VaultDateScope: String, CaseIterable, Identifiable {
    case all = "全部日期", week = "最近 7 天", month = "最近 30 天", year = "今年"
    var id: Self { self }
}

extension VaultItem {
    func matches(query: String, dateScope: VaultDateScope, day: Date? = nil, now: Date = Date()) -> Bool {
        let date = capturedAt ?? importedAt
        let calendar = Calendar.current
        if let day, !calendar.isDate(date, inSameDayAs: day) { return false }
        switch dateScope {
        case .all: break
        case .week, .month:
            let days = dateScope == .week ? 7 : 30
            guard let cutoff = calendar.date(byAdding: .day, value: -days, to: now), date >= cutoff else { return false }
        case .year:
            guard calendar.component(.year, from: date) == calendar.component(.year, from: now) else { return false }
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return true }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return [title, originalName, note ?? "", albumName ?? "", formatter.string(from: date)]
            .contains { $0.localizedCaseInsensitiveContains(needle) }
    }
}

struct VaultBackupPayload: Codable {
    let version: Int
    let createdAt: Date
    let items: [VaultItem]
    let media: [String: Data]
    var albums: [String]? = nil
}

struct VaultIndex: Codable {
    var version = 3
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

