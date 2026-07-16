import Foundation

/// 앱 내부 표시 언어.
///
/// @author suho.do
/// @since 2026-07-03
enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case korean

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .english:
            "English"
        case .korean:
            "한국어"
        }
    }
}

/// 사용자 선택 언어 저장소.
///
/// macOS 시스템 언어와 독립적으로 gazerow 설명/설정 문구 언어만 제어한다.
///
/// @author suho.do
/// @since 2026-07-03
struct AppLanguageSettings {
    static let selectedLanguageKey = "app.language.selected"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedLanguage: AppLanguage {
        get {
            guard let rawValue = defaults.string(forKey: Self.selectedLanguageKey),
                  let language = AppLanguage(rawValue: rawValue) else {
                return .english
            }

            return language
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.selectedLanguageKey)
        }
    }
}
