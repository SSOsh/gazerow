import Foundation

/// gaze calibration sample을 JSON 파일로 저장/로드/삭제한다.
///
/// 기존 설치와의 호환성을 위해 저장 위치는 `~/Library/Application Support/GazeRow/gaze-calibration.json`이며,
/// 비식별 eye feature와 화면 좌표만 담는다. raw camera frame은 저장하지 않는다.
///
/// @author suho.do
/// @since 2026-07-03
struct GazeCalibrationStore {

    private let directory: LogDirectory
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        directory: LogDirectory = LogDirectory(),
        fileManager: FileManager = .default
    ) {
        self.directory = directory
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// 저장된 calibration sample을 로드한다.
    ///
    /// 파일이 없거나 손상된 경우 빈 배열을 반환한다(캘리브레이션 미완료로 취급).
    func load() -> [GazeCalibrationSample] {
        guard let url = try? directory.gazeCalibrationURL(),
              fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let samples = try? decoder.decode([GazeCalibrationSample].self, from: data) else {
            return []
        }
        return samples
    }

    /// calibration sample을 파일에 저장한다(atomic).
    func save(_ samples: [GazeCalibrationSample]) throws {
        let url = try directory.gazeCalibrationURL()
        let data = try encoder.encode(samples)
        try data.write(to: url, options: .atomic)
    }

    /// 저장된 calibration 파일을 삭제한다. 파일이 없으면 아무것도 하지 않는다.
    func clear() throws {
        let url = try directory.gazeCalibrationURL()
        guard fileManager.fileExists(atPath: url.path) else {
            return
        }
        try fileManager.removeItem(at: url)
    }
}
