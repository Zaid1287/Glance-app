import SwiftUI

@main
struct GlanceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if model.hasKey {
                    ContentView()
                } else {
                    PairingView()
                }
            }
            .environmentObject(model)
            .onAppear { model.start() }
        }
    }
}
