import Foundation

/// 앱 실행 세션마다 고정되는 랜덤 salt.
///
/// window title hash가 세션마다 달라지도록 해, 서로 다른 세션의 로그를
/// 원문 없이도 상호 연결하기 어렵게 만든다.
///
/// 값을 주입할 수 있어 테스트는 고정 salt를 사용한다.
///
/// @author suho.do
/// @since 2026-07-02
struct SessionSalt: Equatable {

    /// salt 원문(hash 입력에 접두로 결합).
    let value: String

    /// - Parameter value: salt 값. 기본값은 실행 시 랜덤 UUID.
    init(value: String = UUID().uuidString) {
        self.value = value
    }
}
