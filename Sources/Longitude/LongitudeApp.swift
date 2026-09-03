import SwiftUI

@main
struct LongitudeApp: App {
    @StateObject private var store = LabStore()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(store) }
    }
}

struct RootView: View {
    @State private var tab: Int
    init() { _tab = State(initialValue: UserDefaults.standard.integer(forKey: "initialTab")) }

    var body: some View {
        TabView(selection: $tab) {
            ResultsView().tabItem { Label("Results", systemImage: "chart.xyaxis.line") }.tag(0)
            ReportsView().tabItem { Label("Reports", systemImage: "doc.text") }.tag(1)
        }
    }
}
