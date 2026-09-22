import SwiftUI

@main
struct ForgeCADApp: App {
    @State private var store = DocumentStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
