import SwiftUI

@main
struct WeddingLedgerSwiftApp: App {
    @StateObject private var state: AppState

    init() {
        let store: LedgerStore
        do {
            store = try LedgerStore()
        } catch {
            fatalError(error.localizedDescription)
        }
        _state = StateObject(wrappedValue: AppState(store: store))
    }

    var body: some Scene {
        WindowGroup(appTitle) {
            RootView()
                .environmentObject(state)
                .preferredColorScheme(state.themePreference.colorScheme)
                .frame(minWidth: 860, minHeight: 660)
        }
        .defaultSize(width: 1180, height: 720)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
