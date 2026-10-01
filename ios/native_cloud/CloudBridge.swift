import Foundation
import UIKit
import Security

// Godot's iOS export compiles dummy.swift into the app. patch_export.py appends
// this bridge and calls it before GDScript starts. Game data stays in Godot's
// Documents directory; the native side only moves validated snapshots to iCloud.
@_cdecl("kinu_cloud_bridge_start")
public func kinu_cloud_bridge_start() {
    DispatchQueue.main.async { KinuCloudBridge.shared.start() }
}

private final class KinuCloudBridge: NSObject {
    static let shared = KinuCloudBridge()
    private let store = NSUbiquitousKeyValueStore.default
    private let slotPrefix = "kinu.save.v1."
    private let slotCount = 8
    private var timer: Timer?
    private var lastInbox = Data()
    private var lastStatus = Data()
    private var lastSentAt = 0.0
    private var available = false
    private let rewardService = "com.kinutumble.reward-session.v1"
    private let rewardAccount = "anonymous-supabase-account"
    private var rewardSession = Data()

    private var documents: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    func start() {
        guard timer == nil else { return }
        restoreRewardSession()
        available = store.synchronize()
        NotificationCenter.default.addObserver(self, selector: #selector(cloudChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: store)
        NotificationCenter.default.addObserver(self, selector: #selector(becameActive),
            name: UIApplication.didBecomeActiveNotification, object: nil)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        tick()
    }

    @objc private func cloudChanged() { publishInbox() }

    @objc private func becameActive() {
        available = store.synchronize()
        tick()
    }

    private func tick() {
        preserveRewardSession()
        publishInbox()
        uploadOutbox()
        publishStatus()
    }

    // The save snapshot deliberately excludes login credentials. Keep the anonymous
    // reward account in Keychain so reinstalling cannot create a fresh daily allowance.
    private func rewardQuery(_ synced: Bool) -> [String: Any] {
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: rewardService,
                kSecAttrAccount as String: rewardAccount,
                kSecAttrSynchronizable as String: synced ? kCFBooleanTrue! : kCFBooleanFalse!]
    }

    private func validRewardSession(_ object: Any?) -> [String: Any]? {
        guard let session = object as? [String: Any],
              let access = session["access_token"] as? String, !access.isEmpty,
              let refresh = session["refresh_token"] as? String, !refresh.isEmpty else { return nil }
        return session
    }

    private func readRewardKeychain(_ synced: Bool) -> Data? {
        var query = rewardQuery(synced)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let bytes = result as? Data,
              let object = try? JSONSerialization.jsonObject(with: bytes),
              validRewardSession(object) != nil else { return nil }
        return bytes
    }

    private func writeRewardKeychain(_ bytes: Data, synced: Bool) -> Bool {
        let query = rewardQuery(synced)
        let updated = SecItemUpdate(query as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
        if updated == errSecSuccess { return true }
        guard updated == errSecItemNotFound else { return false }
        var attributes = query
        attributes[kSecValueData as String] = bytes
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    private func restoreRewardSession() {
        guard let documents else { return }
        if let bytes = readRewardKeychain(false) ?? readRewardKeychain(true) {
            rewardSession = bytes
            try? bytes.write(to: documents.appendingPathComponent("reward_session_inbox.json"), options: .atomic)
        }
        try? Data().write(to: documents.appendingPathComponent("reward_session_checked"), options: .atomic)
    }

    private func preserveRewardSession() {
        guard let documents,
              let bytes = try? Data(contentsOf: documents.appendingPathComponent("nest_save.json")),
              let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let session = validRewardSession(root["backend_session"]),
              let encoded = try? JSONSerialization.data(withJSONObject: session, options: .sortedKeys),
              encoded != rewardSession else { return }
        // Local Keychain survives an app reinstall on this device. The synchronizable
        // copy additionally carries the account to devices with iCloud Keychain enabled.
        if writeRewardKeychain(encoded, synced: false) {
            rewardSession = encoded
            _ = writeRewardKeychain(encoded, synced: true)
        }
    }

    private func publishInbox() {
        guard let documents else { return }
        var slots = [String]()
        for index in 0..<slotCount {
            if let bytes = store.data(forKey: slotPrefix + String(index)),
               let text = String(data: bytes, encoding: .utf8) {
                slots.append(text)
            }
        }
        guard let bytes = try? JSONSerialization.data(withJSONObject: ["slots": slots]),
              bytes != lastInbox else { return }
        do {
            try bytes.write(to: documents.appendingPathComponent("cloud_kvs_inbox.json"), options: .atomic)
            lastInbox = bytes
        } catch { }
    }

    private func uploadOutbox() {
        guard available, let documents,
              let bytes = try? Data(contentsOf: documents.appendingPathComponent("cloud_kvs_outbox.json")),
              bytes.count < 100_000,
              let root = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let format = root["format"] as? Int, format == 1,
              let save = root["save"] as? [String: Any],
              let revision = save["cloud_revision"] as? Int,
              revision >= 0 else { return }
        let key = slotPrefix + String(revision % slotCount)
        guard store.data(forKey: key) != bytes else { return }
        store.set(bytes, forKey: key)
        available = store.synchronize()
        if available {
            lastSentAt = Date().timeIntervalSince1970
            publishInbox()
        }
    }

    private func publishStatus() {
        guard let documents else { return }
        let status: [String: Any] = [
            "available": available,
            "last_sent_at": lastSentAt,
            "remote_slots": (0..<slotCount).filter { store.data(forKey: slotPrefix + String($0)) != nil }.count
        ]
        guard let bytes = try? JSONSerialization.data(withJSONObject: status),
              bytes != lastStatus else { return }
        do {
            try bytes.write(to: documents.appendingPathComponent("cloud_kvs_status.json"), options: .atomic)
            lastStatus = bytes
        } catch { }
    }
}
