import Foundation

/// AX debug export를 수동 생성/삭제한다.
///
/// 현재 시점의 진단 정보를 사람이 읽을 수 있는 텍스트로 저장한다.
/// Scanning 결과 등 외부 의존부는 주입형 클로저로 받아 코덱스 파일과 결합하지 않는다.
///
/// - Important: 진단 텍스트는 raw window title/ text value 등 민감정보를 담지 않는다.
///   창 정보가 필요하면 호출 측에서 hash 등 비민감 요약만 넣어야 한다.
///
/// @author suho.do
/// @since 2026-07-02
final class DebugExportManager {

    /// export 파일 경로 resolver.
    private let logDirectory: LogDirectory

    /// 파일 쓰기/삭제용 FileManager.
    private let fileManager: FileManager

    /// 현재 시각 제공자(테스트 고정용).
    private let now: () -> Date

    /// 진단 요약 본문을 만드는 클로저.
    /// Scanning 결과 등 외부 상태는 이 클로저를 통해서만 반영한다.
    private let diagnosticsProvider: () -> String

    /// export 시각 포맷터를 만든다.
    ///
    /// `ISO8601DateFormatter`는 non-Sendable이라 static 공유 대신 매 생성마다 만든다.
    private static func makeTimestampFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    /// - Parameters:
    ///   - logDirectory: export 경로 resolver. 기본값 `LogDirectory()`.
    ///   - fileManager: 파일 접근용. 기본값 `.default`.
    ///   - now: 현재 시각 제공자. 기본값 `Date.init`.
    ///   - diagnosticsProvider: 진단 요약 본문 제공 클로저. 기본값은 빈 문자열.
    init(
        logDirectory: LogDirectory = LogDirectory(),
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        diagnosticsProvider: @escaping () -> String = { "" }
    ) {
        self.logDirectory = logDirectory
        self.fileManager = fileManager
        self.now = now
        self.diagnosticsProvider = diagnosticsProvider
    }

    /// 현재 시점 진단 정보를 텍스트 파일로 생성한다.
    ///
    /// - Returns: 생성된 export 파일 URL.
    /// - Throws: 경로 resolve 또는 파일 쓰기 실패 시 에러.
    @discardableResult
    func createExport() throws -> URL {
        let url = try logDirectory.debugExportURL()
        let content = makeContent()
        try Data(content.utf8).write(to: url, options: .atomic)
        return url
    }

    /// export 파일을 삭제한다. 파일이 없으면 아무 것도 하지 않는다.
    func deleteAll() {
        guard let url = try? logDirectory.debugExportURL() else {
            return
        }
        if fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }
    }

    /// export 텍스트 본문을 구성한다.
    private func makeContent() -> String {
        let header = "gazerow Debug Export"
        let generatedAt = "Generated: \(Self.makeTimestampFormatter().string(from: now()))"
        let diagnostics = diagnosticsProvider()

        return """
        \(header)
        \(generatedAt)

        \(diagnostics)
        """
    }
}
