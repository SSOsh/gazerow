import Foundation

/// interaction 이벤트를 opt-in일 때만 파일로 기록하는 저장소.
///
/// opt-in 플래그는 `UserDefaults`(주입 가능)에 저장하며 기본값은 false다.
/// opt-in이 꺼져 있으면 `record(_:)`는 아무 것도 쓰지 않는다(no-op).
///
/// `OnboardingState`의 UserDefaults 주입 패턴을 준용한다.
///
/// - Important: 프라이버시 기준상 기본 상태에서는 어떤 interaction 파일도 만들지 않는다.
///
/// @author suho.do
/// @since 2026-07-02
final class InteractionLogStore {

    /// interaction 저장 opt-in 여부를 저장하는 UserDefaults 키.
    static let optInKey = "logging.interaction.optIn"

    /// opt-in 여부 저장소.
    private let defaults: UserDefaults

    /// 로그 파일 경로 resolver.
    private let logDirectory: LogDirectory

    /// 파일 append/삭제에 쓰는 FileManager.
    private let fileManager: FileManager

    /// record를 JSON으로 인코딩하는 인코더.
    private let encoder: JSONEncoder

    /// - Parameters:
    ///   - defaults: opt-in 플래그 저장소. 기본값 `.standard`.
    ///   - logDirectory: 로그 경로 resolver. 기본값 `LogDirectory()`.
    ///   - fileManager: 파일 접근용. 기본값 `.default`.
    init(
        defaults: UserDefaults = .standard,
        logDirectory: LogDirectory = LogDirectory(),
        fileManager: FileManager = .default
    ) {
        self.defaults = defaults
        self.logDirectory = logDirectory
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    }

    /// interaction 저장 opt-in 여부. 기본값 false.
    var isOptInEnabled: Bool {
        get { defaults.bool(forKey: Self.optInKey) }
        set { defaults.set(newValue, forKey: Self.optInKey) }
    }

    /// 이벤트를 JSON Lines 한 줄로 append한다.
    ///
    /// opt-in이 꺼져 있으면 아무 것도 하지 않는다. 인코딩/쓰기 실패는 조용히 무시한다
    /// (로깅 실패가 앱 흐름을 막지 않도록).
    ///
    /// - Parameter event: 기록할 interaction 이벤트.
    func record(_ event: InteractionEvent) {
        guard isOptInEnabled else {
            return
        }

        let record = InteractionLogRecord(event: event)
        guard let data = try? encoder.encode(record) else {
            return
        }

        var line = data
        line.append(0x0A) // newline

        try? append(line)
    }

    /// interaction 로그 파일을 삭제한다. 파일이 없으면 아무 것도 하지 않는다.
    func deleteAll() {
        guard let url = try? logDirectory.interactionLogURL() else {
            return
        }
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// 로그 파일에 한 줄을 append한다. 파일이 없으면 새로 만든다.
    private func append(_ line: Data) throws {
        let url = try logDirectory.interactionLogURL()

        if fileManager.fileExists(atPath: url.path) {
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: line)
        } else {
            try line.write(to: url, options: .atomic)
        }
    }
}
