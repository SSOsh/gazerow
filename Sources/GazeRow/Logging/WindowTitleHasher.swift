import Foundation
import CryptoKit

/// window title을 원문 저장 없이 hash로 변환한다.
///
/// `SHA256(salt + title)`을 hex 문자열로 반환한다. raw title은 저장/반환하지 않는다.
/// salt가 다르면 같은 title이라도 hash가 달라진다.
///
/// @author suho.do
/// @since 2026-07-02
struct WindowTitleHasher {

    /// 세션 salt. hash 입력에 접두로 결합한다.
    private let salt: SessionSalt

    init(salt: SessionSalt) {
        self.salt = salt
    }

    /// title을 `SHA256(salt + title)` hex로 변환한다.
    ///
    /// - Parameter title: window title 원문. `nil`이거나 비어 있으면 `nil` 반환.
    /// - Returns: 소문자 hex hash 문자열. 입력이 없으면 `nil`.
    func hash(_ title: String?) -> String? {
        guard let title, !title.isEmpty else {
            return nil
        }

        let input = Data((salt.value + title).utf8)
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
