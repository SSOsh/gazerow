/// 런치 옵션 기반 overlay smoke 결과를 stdout에 남기기 위한 formatter.
///
/// @author suho.do
/// @since 2026-07-02
enum OverlayLaunchReporter {

    static func success(labelCount: Int) -> String {
        "GAZEROW_OVERLAY_RESULT success labels=\(labelCount)"
    }

    static func failure(logCode: String) -> String {
        "GAZEROW_OVERLAY_RESULT failure reason=\(logCode)"
    }
}
