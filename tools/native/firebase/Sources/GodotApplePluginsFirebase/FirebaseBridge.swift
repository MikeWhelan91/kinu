import SwiftGodotRuntime
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

final class FirebaseBridge: Object {
    override class var godotClassName: StringName {
        StringName("FirebaseBridge")
    }

    private static func swiftValue(from variant: Variant?) -> Any {
        guard let variant, !variant.isNull else { return NSNull() }
        switch variant.gtype {
        case .int:
            return (try? Int64.fromVariantOrThrow(variant)) ?? 0
        case .float:
            return (try? Double.fromVariantOrThrow(variant)) ?? 0.0
        case .bool:
            return (try? Bool.fromVariantOrThrow(variant)) ?? false
        default:
            return (try? String.fromVariantOrThrow(variant)) ?? variant.description
        }
    }

    private static func swiftDictionary(from dictionary: VariantDictionary?) -> [String: Any] {
        guard let dictionary else { return [:] }
        var result: [String: Any] = [:]
        for keyVariant in dictionary.keys() {
            guard let keyString = try? String.fromVariantOrThrow(keyVariant ?? Variant("")) else { continue }
            result[keyString] = swiftValue(from: dictionary.get(key: keyVariant, default: nil))
        }
        return result
    }

    func configure() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    func logEvent(name: String, params: VariantDictionary?) {
        Analytics.logEvent(name, parameters: Self.swiftDictionary(from: params))
    }

    func setUserProperty(name: String, value: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func setUserId(_ userId: String) {
        Analytics.setUserID(userId.isEmpty ? nil : userId)
    }

    func setAnalyticsCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }

    func setScreenName(_ screenName: String, screenClass: String) {
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: screenName,
            AnalyticsParameterScreenClass: screenClass,
        ])
    }

    func crashlyticsLog(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    func crashlyticsSetCustomValue(key: String, value: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }

    func crashlyticsSetUserId(_ userId: String) {
        Crashlytics.crashlytics().setUserID(userId)
    }

    func crashlyticsRecordError(domain: String, code: Int64, message: String) {
        let error = NSError(domain: domain, code: Int(code), userInfo: [NSLocalizedDescriptionKey: message])
        Crashlytics.crashlytics().record(error: error)
    }

    func crashlyticsSetCrashlyticsCollectionEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }
}

func registerFirebaseBridge() {
    let info = ClassInfo<FirebaseBridge>(name: "FirebaseBridge")

    info.registerMethod(
        name: "configure",
        flags: .default,
        returnValue: nil,
        arguments: [],
        function: { instance in { _ in
            instance.configure()
            return nil
        } }
    )

    info.registerMethod(
        name: "log_event",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "name", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
            PropInfo(propertyType: .dictionary, propertyName: "params", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let name = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            let params = try? args.argument(ofType: VariantDictionary.self, at: 1)
            instance.logEvent(name: name, params: params)
            return nil
        } }
    )

    info.registerMethod(
        name: "set_user_property",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "name", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
            PropInfo(propertyType: .string, propertyName: "value", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let name = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            let value = (try? args.argument(ofType: String.self, at: 1)) ?? ""
            instance.setUserProperty(name: name, value: value)
            return nil
        } }
    )

    info.registerMethod(
        name: "set_user_id",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "user_id", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let userId = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            instance.setUserId(userId)
            return nil
        } }
    )

    info.registerMethod(
        name: "set_analytics_collection_enabled",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .bool, propertyName: "enabled", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let enabled = (try? args.argument(ofType: Bool.self, at: 0)) ?? true
            instance.setAnalyticsCollectionEnabled(enabled)
            return nil
        } }
    )

    info.registerMethod(
        name: "set_screen_name",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "screen_name", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
            PropInfo(propertyType: .string, propertyName: "screen_class", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let screenName = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            let screenClass = (try? args.argument(ofType: String.self, at: 1)) ?? ""
            instance.setScreenName(screenName, screenClass: screenClass)
            return nil
        } }
    )

    info.registerMethod(
        name: "crashlytics_log",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "message", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let message = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            instance.crashlyticsLog(message)
            return nil
        } }
    )

    info.registerMethod(
        name: "crashlytics_set_custom_value",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "key", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
            PropInfo(propertyType: .string, propertyName: "value", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let key = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            let value = (try? args.argument(ofType: String.self, at: 1)) ?? ""
            instance.crashlyticsSetCustomValue(key: key, value: value)
            return nil
        } }
    )

    info.registerMethod(
        name: "crashlytics_set_user_id",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "user_id", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let userId = (try? args.argument(ofType: String.self, at: 0)) ?? ""
            instance.crashlyticsSetUserId(userId)
            return nil
        } }
    )

    info.registerMethod(
        name: "crashlytics_record_error",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .string, propertyName: "domain", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
            PropInfo(propertyType: .int, propertyName: "code", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
            PropInfo(propertyType: .string, propertyName: "message", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let domain = (try? args.argument(ofType: String.self, at: 0)) ?? "FirebaseBridge"
            let code = (try? args.argument(ofType: Int64.self, at: 1)) ?? 0
            let message = (try? args.argument(ofType: String.self, at: 2)) ?? ""
            instance.crashlyticsRecordError(domain: domain, code: code, message: message)
            return nil
        } }
    )

    info.registerMethod(
        name: "crashlytics_set_collection_enabled",
        flags: .default,
        returnValue: nil,
        arguments: [
            PropInfo(propertyType: .bool, propertyName: "enabled", className: "FirebaseBridge", hint: .none, hintStr: "", usage: .default),
        ],
        function: { instance in { args in
            let enabled = (try? args.argument(ofType: Bool.self, at: 0)) ?? true
            instance.crashlyticsSetCrashlyticsCollectionEnabled(enabled)
            return nil
        } }
    )
}

@_cdecl("godot_apple_plugins_firebase_start")
public func godot_apple_plugins_firebase_start(
    _ getProcAddress: UnsafeMutableRawPointer?,
    _ library: UnsafeMutableRawPointer?,
    _ initialization: UnsafeMutableRawPointer?
) -> UInt8 {
    guard let getProcAddress, let library, let initialization else { return 0 }
    initializeSwiftModule(
        OpaquePointer(getProcAddress),
        OpaquePointer(library),
        OpaquePointer(initialization),
        initHook: { level in
            if level == .scene {
                if FirebaseApp.app() == nil {
                    FirebaseApp.configure()
                }
                registerFirebaseBridge()
            }
        },
        deInitHook: { _ in },
        minimumInitializationLevel: .scene
    )
    return 1
}
