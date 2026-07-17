import Foundation

/// 로그/진단 파일이 저장될 디렉토리 경로를 resolve한다.
///
/// 기존 설치와의 호환성을 위해 기본 위치는 `~/Library/Application Support/GazeRow/`이다.
/// `FileManager`를 주입할 수 있어 테스트는 임시 디렉토리를 사용한다.
///
/// @author suho.do
/// @since 2026-07-02
struct LogDirectory {

    /// Application Support 하위 앱 폴더명.
    private static let appFolderName = "GazeRow"

    /// interaction 로그 파일명(JSON Lines).
    static let interactionLogFileName = "interaction.log.jsonl"

    /// AX debug export 파일명.
    static let debugExportFileName = "debug-export.txt"

    /// gaze calibration sample 저장 파일명(JSON).
    static let gazeCalibrationFileName = "gaze-calibration.json"

    /// 파일 시스템 접근에 사용할 FileManager.
    private let fileManager: FileManager

    /// base 디렉토리 override. 지정 시 Application Support 대신 이 경로를 쓴다.
    private let baseOverride: URL?

    /// - Parameters:
    ///   - fileManager: 파일 시스템 접근용. 기본값은 `.default`.
    ///   - baseOverride: 테스트용 base 디렉토리. 기본값 `nil`(Application Support 사용).
    init(fileManager: FileManager = .default, baseOverride: URL? = nil) {
        self.fileManager = fileManager
        self.baseOverride = baseOverride
    }

    /// 앱 전용 디렉토리 URL을 반환하고, 없으면 생성한다.
    ///
    /// - Returns: 호환성을 유지하는 `.../GazeRow/` 디렉토리 URL.
    /// - Throws: 디렉토리 생성 실패 시 에러.
    func resolveDirectory() throws -> URL {
        let base = try resolveBase()
        let directory = base.appendingPathComponent(Self.appFolderName, isDirectory: true)

        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        return directory
    }

    /// interaction 로그 파일 URL. 상위 디렉토리를 보장 생성한다.
    func interactionLogURL() throws -> URL {
        try resolveDirectory().appendingPathComponent(Self.interactionLogFileName)
    }

    /// debug export 파일 URL. 상위 디렉토리를 보장 생성한다.
    func debugExportURL() throws -> URL {
        try resolveDirectory().appendingPathComponent(Self.debugExportFileName)
    }

    /// gaze calibration 파일 URL. 상위 디렉토리를 보장 생성한다.
    func gazeCalibrationURL() throws -> URL {
        try resolveDirectory().appendingPathComponent(Self.gazeCalibrationFileName)
    }

    /// base 디렉토리(override 또는 Application Support)를 결정한다.
    private func resolveBase() throws -> URL {
        if let baseOverride {
            return baseOverride
        }
        return try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
    }
}
