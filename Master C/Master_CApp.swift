import SwiftUI

@main
struct Master_CApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            // Tableau de bord
            NavigationView {
                DashboardView()
            }
            .tabItem { Label("Tableau de bord", systemImage: "rectangle.grid.2x2") }

            // Clients
            NavigationView {
                ClientsListView()
            }
            .tabItem { Label("Clients", systemImage: "person.3") }

            // Paramètres
            ParametresView()
                .tabItem {Label("Transparence", systemImage: "info.square.fill")}

            // BDD Stats
            NavigationView {
                StatsView()
            }
            .tabItem { Label("BDD Stats", systemImage: "chart.bar") }
        }
    }
}

