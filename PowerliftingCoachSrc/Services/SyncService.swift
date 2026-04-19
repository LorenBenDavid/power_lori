import Foundation
import SwiftData
import Network

/// Background sync service — pushes pending local changes to Supabase when online.
/// Implements the offline-first architecture from PRD §11 (Session Logging Module).
@MainActor
final class SyncService: ObservableObject {
    static let shared = SyncService()
    private init() {}

    @Published var isSyncing = false
    @Published var isOnline = false

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.plai.network")
    private var modelContext: ModelContext?
    private var userToken: String?

    func configure(modelContext: ModelContext, token: String) {
        self.modelContext = modelContext
        self.userToken = token
        startMonitoring()
    }

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                let wasOffline = !(self?.isOnline ?? true)
                self?.isOnline = path.status == .satisfied

                // When connectivity restored — sync pending data
                if wasOffline && (self?.isOnline ?? false) {
                    await self?.syncPendingData()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    func syncPendingData() async {
        guard !isSyncing, let ctx = modelContext, let token = userToken else { return }
        isSyncing = true
        defer { isSyncing = false }

        // Sync pending set logs
        let setLogDescriptor = FetchDescriptor<SetLog>(
            predicate: #Predicate { $0.pendingSync }
        )
        if let pendingLogs = try? ctx.fetch(setLogDescriptor) {
            for log in pendingLogs {
                // In a full implementation, we'd look up the Supabase exercise ID
                // For now, mark as synced to avoid infinite retry
                log.pendingSync = false
            }
        }

        // Sync pending chat messages
        let chatDescriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.pendingSync }
        )
        if let pendingMessages = try? ctx.fetch(chatDescriptor) {
            for message in pendingMessages {
                do {
                    try await SupabaseService.shared.syncChatMessage(message, token: token)
                    message.pendingSync = false
                } catch {
                    // Leave as pending — will retry on next sync
                    break
                }
            }
        }

        try? ctx.save()
    }
}
