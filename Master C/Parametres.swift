import SwiftUI

/*struct ParametresView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("⚖️ Indications réglementaires")
                    .font(.title2)
                    .padding(.bottom)
                
                Text("Conformément aux obligations AMF, cette application ...")
                    .font(.body)
                
                // Ajouter d’autres points réglementaires
            }
            .padding()
        }
    }
}
*/

import SwiftUI

// === ONBOARDING ===
struct OnboardingView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @State private var selection = 0
    
    var body: some View {
        VStack {
            // Titre générique
            Text("Transparence")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            TabView(selection: $selection) {
                
                OnboardingPage(
                    color: Color.blue.opacity(0.2),
                    systemImage: "book.fill",
                    title: "Aide et Introduction",
                    subtitle: "Suivi des portefeuilles clients sur contrats d’assurance vie et comptes-titres, conforme aux réglementations DDA2, PRIIPS et SFDR."
                )
                .tag(0)
                
                OnboardingPage(
                    color: Color.orange.opacity(0.2),
                    systemImage: "gearshape.fill",
                    title: "Fonctionnalités principales",
                    subtitle: "Tableau de bord interactif, suivi des encours et des volumétries, conformité des risques, obsolescence documentaire, comparaison produits et calculs des rémunérations."
                )
                .tag(1)
                
                OnboardingPage(
                    color: Color.green.opacity(0.2),
                    systemImage: "person.3.fill",
                    title: "Suivi des clients",
                    subtitle: "Filtres avancés axés sur les risques, affichage des indicateurs ESG et profils clients, suivi détaillé par contrat et vision consolidée globale."
                )
                .tag(2)
                
                OnboardingPage(
                    color: Color.purple.opacity(0.2),
                    systemImage: "folder.fill",
                    title: "Données",
                    subtitle: "Sources multiples (Penelop, API, bases internes). Base embarquée sur l’appareil pour assurer la continuité d’activité hors connexion, avec chiffrement local et conformité RGPD."
                )
                .tag(3)
                
                OnboardingPage(
                    color: Color.gray.opacity(0.2),
                    systemImage: "checkmark.shield.fill",
                    title: "Mentions réglementaires",
                    subtitle: "Respect des cadres français et européens : DDA2, PRIIPS, SFDR, RGPD et alignement avec les recommandations AMF."
                )
                .tag(4)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .overlay(alignment: .topTrailing) {
                Button("Fermer") {
                    hasSeenOnboarding = true
                    presentationMode.wrappedValue.dismiss()
                }
                .padding()
            }
        }
    }
}

// === Page individuelle ===
struct OnboardingPage: View {
    var color: Color
    var systemImage: String
    var title: String
    var subtitle: String
    
    var body: some View {
        ZStack {
            color.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.blue)
                
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(subtitle)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 30)
            }
        }
    }
}



// === PARAMETRES VIEW ===
import SwiftUI

struct ParametresView: View {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @State private var showOnboarding = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    
                    // Bouton Introduction
                    Button(action: { showOnboarding = true }) {
                        HStack {
                            Text("👋 Introduction")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .sheet(isPresented: $showOnboarding) {
                        OnboardingView()
                    }
                    
                    // === Sections ===
                    ExpandableSection(title: "Aide et Introduction") {
                        VStack(alignment: .leading, spacing: 12) {
                            coloredLabel("Suivi des portefeuilles assurance vie et comptes-titres", "doc.text", .blue)
                            coloredLabel("Conformité DDA2, PRIIPS et SFDR", "checkmark.shield", .green)
                            coloredLabel("Tableau de bord basé sur une gestion comptable complète", "rectangle.grid.2x2", .orange)
                        }
                    }
                    
                    ExpandableSection(title: "Fonctionnalités principales") {
                        VStack(alignment: .leading, spacing: 12) {
                            coloredLabel("Tableau de bord interactif", "calendar", .blue)
                            coloredLabel("Volumétries d’investissements", "chart.bar.fill", .purple)
                            coloredLabel("Conformité des risques clients", "exclamationmark.triangle.fill", .red)
                            coloredLabel("Suivi de l’obsolescence documentaire", "doc.on.doc.fill", .gray)
                            coloredLabel("Comparaison avec l’offre produits", "magnifyingglass", .orange)
                            coloredLabel("Calculs comptables des rémunérations", "eurosign.circle.fill", .green)
                        }
                    }
                    
                    ExpandableSection(title: "Suivi des clients") {
                        VStack(alignment: .leading, spacing: 12) {
                            coloredLabel("Filtres de recherche avancés axés risques", "line.3.horizontal.decrease.circle", .blue)
                            coloredLabel("Indicateurs risques et ESG par client et contrat", "person.text.rectangle", .green)
                            coloredLabel("Suivi détaillé par contrat", "doc.plaintext", .gray)
                            coloredLabel("Vue consolidée globale et comparaison produits", "globe", .purple)
                        }
                    }
                    
                    ExpandableSection(title: "Données") {
                        VStack(alignment: .leading, spacing: 12) {
                            coloredLabel("Sources multiples : Penelop, bases, API", "link", .blue)
                            coloredLabel("Base embarquée sur l’appareil", "iphone", .green)
                            coloredLabel("Continuité d’activité hors connexion", "arrow.triangle.2.circlepath", .orange)
                            coloredLabel("Chiffrement local et conformité RGPD", "lock.shield.fill", .red)
                        }
                    }
                    
                    ExpandableSection(title: "Mentions réglementaires") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Application développée dans le respect des cadres réglementaires français et européens.")
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)
                            
                            coloredLabel("DDA2 – adéquation produit/profil client", "checkmark.circle.fill", .green)
                            coloredLabel("PRIIPS – informations standardisées", "list.bullet.rectangle.fill", .blue)
                            coloredLabel("SFDR – intégration critères ESG", "leaf.fill", .green)
                            coloredLabel("RGPD – protection des données", "lock.fill", .red)
                            coloredLabel("AMF – alignement avec les contrôles", "building.columns.fill", .purple)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Transparence")  // <<< Titre en haut
            .navigationBarTitleDisplayMode(.inline)
        }
        // Affichage automatique onboarding au premier lancement
        .fullScreenCover(isPresented: .constant(!hasSeenOnboarding)) {
            OnboardingView()
        }
    }
}


// === COMPOSANTS UTILITAIRES ===
struct ExpandableSection<Content: View>: View {
    let title: String
    let content: () -> Content
    @State private var expanded: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { withAnimation { expanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            if expanded {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }
}

// Helper pour Label coloré
func coloredLabel(_ text: String, _ systemImage: String, _ color: Color) -> some View {
    Label {
        Text(text)
    } icon: {
        Image(systemName: systemImage)
            .foregroundColor(color)
    }
}


//
struct DatabaseManagerView: View {
    @Binding var dbModificationDate: Date?
    @Binding var isLoading: Bool
    @Binding var loadError: String?
    @Binding var showWelcomeScreen: Bool

    var loadDatabase: (Bool) -> Void

    var body: some View {
        VStack(spacing: 16) {
            if let date = dbModificationDate {
                Text("Base présente, chargée le **\(dateFormatter.string(from: date))**")
            } else {
                Text("Aucune base détectée en local.")
                    .foregroundColor(.secondary)
            }

            if isLoading {
                ProgressView("Chargement en cours...")
            } else {
                if dbModificationDate != nil {
                    Button("🔄 Recharger la base") {
                        loadDatabase(true)
                    }
                    .buttonStyle(.borderedProminent)

                } else {
                    Button("📥 Télécharger la base") {
                        loadDatabase(true)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if let error = loadError {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 8)
    }
}
