import AVFoundation
import XCTest
@testable import GazeRow

/// CameraFrameProvider 단위 테스트.
///
/// deviceProvider 주입 seam을 이용해 실제 카메라 하드웨어나 권한 없이 capture session의
/// 오류 경로와 idle 동작을 검증한다. 장치가 없으면 cameraUnavailable을 던지고, 실행 중이
/// 아닐 때 stop()은 안전하게 무시되어야 한다.
///
/// @author suho.do
/// @since 2026-09-12
final class CameraFrameProviderTests: XCTestCase {

    func test_카메라_장치가_없으면_start는_cameraUnavailable을_던진다() {
        // given: deviceProvider가 nil을 반환(= 사용 가능한 카메라 없음)
        let sut = CameraFrameProvider(deviceProvider: { nil })

        // when & then
        XCTAssertThrowsError(try sut.start()) { error in
            XCTAssertEqual(
                error as? CameraFrameProvider.CameraFrameProviderError,
                .cameraUnavailable
            )
        }
    }

    func test_실행중이_아닐때_stop은_크래시없이_무시된다() {
        // given
        let sut = CameraFrameProvider(deviceProvider: { nil })

        // when: 한 번도 start하지 않은 상태에서 stop 호출
        sut.stop()

        // then: stop 이후에도 여전히 장치없음 경로를 유지한다(상태가 깨지지 않음)
        XCTAssertThrowsError(try sut.start()) { error in
            XCTAssertEqual(
                error as? CameraFrameProvider.CameraFrameProviderError,
                .cameraUnavailable
            )
        }
    }
}
