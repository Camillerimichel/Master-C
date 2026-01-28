import SwiftUI

struct ClientsListView: View {
    struct ClientDisplay: Identifiable {
        let id: Int
        let nom: String
        let prenom: String
        let srriInitial: Int
        let dateDebut: Date?
        let valo: Double
        let srriActuel: Int
        let volat: Double?
        let dateAnciennete: Date?
    }
    
    enum TriCritere: String, CaseIterable {
        case nom = "Nom"
        case srriInitial = "SRRI initial"
        case srriActuel = "SRRI actuel"
        case iconeRisque = "Icône de risque"
    }
    
    @State private var clients: [ClientDisplay] = []
    @State private var clientsSource: [ClientDisplay] = []
    @State private var critereTri: TriCritere = .nom
    @State private var ordreCroissant: Bool = true
    
    // Filtres par risque
    @State private var filtreRisqueAugmente = false
    @State private var filtreRisqueIdentique = false
    @State private var filtreRisqueReduit = false
    
    // Filtres par valorisation
    @State private var montantFiltre: String = ""
    @State private var filtreValoSup = true // true = supérieur, false = inférieur
    
    // Filtre par recherche
    @State private var rechercheTexte: String = ""
    
    @State private var showFilters = false

    var body: some View {
        List {
            ForEach(clients) { client in
                NavigationLink(
                    destination: ClientDetailView(
                        client: Client(id: client.id, nom: client.nom, prenom: client.prenom, srri: client.srriInitial)
                    )
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        
                        // Ligne 1 : Nom, prénom + SRRI initial avec logo risque réel
                        HStack {
                            Text("\(client.prenom) \(client.nom)")
                                .font(.headline)
                            Spacer()
                            HStack(spacing: 4) {
                                risqueIcon(for: client) // ❄️ 🙌 🔥
                                Text("SRRI: \(client.srriInitial)")
                                //                        .font(.subheadline)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Ligne 2 : Date ouverture + valo
                        HStack {
                            if let dateDebut = client.dateDebut {
                                Label(dateFormatter.string(from: dateDebut), systemImage: "calendar")
                            } else {
                                Label("-", systemImage: "calendar")
                            }
                            Spacer()
                            Label(
                                "\(valoFormatter.string(from: NSNumber(value: client.valo)) ?? "0")",
                                systemImage: "eurosign.circle"
                            )
                        }
//                        .font(.subheadline)
                        .font(.caption)

                        .foregroundColor(.secondary)
                        
                        // Ligne 3 : SRRI actuel + volatilité
                        HStack {
                            Label("SRRI actuel : \(client.srriActuel)", systemImage: "chart.line.uptrend.xyaxis")
//                            if let v = client.volat {
//                                Text(String(format: "(%.2f%%)", v))
//                                    .foregroundColor(.secondary)
//                            }
                        }
                        .font(.footnote)
  /**/
                        if let esg = calculerNotesESGClient(client) {
                            HStack {
                                Text("Note E : \(esg.noteELettre)")
                                    .foregroundColor(.green)
                                    .font(.caption)

                                Spacer()
                                Text("Note S : \(esg.noteSLettre)")
                                    .foregroundColor(.blue)
                                    .font(.caption)

                                Spacer()
                                Text("Note G : \(esg.noteGLettre)")
                                    .foregroundColor(.orange)
                                    .font(.caption)

                            }
                        }

  
                        // Ligne 4 : ancienneté
                        if let dateAnc = client.dateAnciennete {
                            Label(
                                "Ancienneté : \(dateFormatter.string(from: dateAnc))",
                                systemImage: "clock"
                            )
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            loadClients()
        }
        .navigationTitle("Clients (\(clients.count))")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilters = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .sheet(isPresented: $showFilters) {
            NavigationView {
                Form {
                    // Recherche par nom ou prénom
                    Section(header: Text("Recherche par nom/prénom")) {
                        TextField("Nom ou prénom", text: $rechercheTexte)
                    }
                    
                    // Tri
                    Section(header: Text("Tri")) {
                        Picker("Trier par", selection: $critereTri) {
                            ForEach(TriCritere.allCases, id: \.self) { critere in
                                Text(critere.rawValue).tag(critere)
                            }
                        }
                        Toggle("Ordre croissant", isOn: $ordreCroissant)
                    }
                    
                    // Filtres par risque
                    Section(header: Text("Filtrer par risque")) {
                        Toggle("❄️ Sous le niveau de risque", isOn: $filtreRisqueReduit)      // SRRI actuel < SRRI initial
                        Toggle("🙏 Dans le niveau de risque", isOn: $filtreRisqueIdentique)   // SRRI actuel == SRRI initial
                        Toggle("🔥 Au-dessus du niveau de risque", isOn: $filtreRisqueAugmente) // SRRI actuel > SRRI initial
                    }

                    // Filtres par valorisation
                    Section(header: Text("Filtrer par valorisation")) {
                        TextField("Montant", text: $montantFiltre)
                            .keyboardType(.decimalPad)
                        Toggle("Supérieur au montant", isOn: $filtreValoSup)
                    }
                }
                .navigationTitle("Filtres")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Appliquer") {
                            appliquerFiltresEtTri()
                            showFilters = false
                        }
                    }
                }
            }
        }
    }
    private func calculerNotesESGContrat(_ contrat: Affaire) -> ESGNoteResult? {
        // On prend la dernière date dispo pour le contrat
        if let d = DatabaseManager.shared.getDatesDisponiblesPourContratRAW(contrat.id).first {
            let supports = DatabaseManager.shared.getSyntheseSupportsPourContratDetail(
                contrat.id,
                aLaDate: d
            )
            
            if !supports.isEmpty {
                return ESGUtils.calculerNotesESGPonderees(
                    supports: supports.map {
                        (valeur: $0.totalValo,
                         noteE: $0.noteE,
                         noteS: $0.noteS,
                         noteG: $0.noteG)
                    }
                )
            }
        }
        return nil
    }
    private func calculerNotesESGClient(_ client: ClientDisplay) -> ESGNoteResult? {
        let contrats = DatabaseManager.shared.queryAffaires(for: client.id)
        let contratsMetrics = DatabaseManager.shared.fetchContratMetricsWithVolat()
        
        let contratsAvecValo = contrats.compactMap { contrat -> (valo: Double, noteE: String?, noteS: String?, noteG: String?)? in
            guard let metrics = contratsMetrics[contrat.id] else { return nil }
            let valo = metrics.totalValo
            guard valo > 0 else { return nil }
            
            if let esgContrat = calculerNotesESGContrat(contrat) {
                return (valo, esgContrat.noteELettre, esgContrat.noteSLettre, esgContrat.noteGLettre)
            }
            return nil
        }
        
        guard !contratsAvecValo.isEmpty else { return nil }
        
        return ESGUtils.calculerNotesESGPonderees(
            supports: contratsAvecValo.map {
                (valeur: $0.valo,
                 noteE: $0.noteE,
                 noteS: $0.noteS,
                 noteG: $0.noteG)
            }
        )
    }


    
    private func risqueIcon(for client: ClientDisplay) -> some View {
        if client.srriActuel > client.srriInitial {
            return Image(systemName: "flame.fill").foregroundColor(.red)           // Au-dessus du niveau
        } else if client.srriActuel == client.srriInitial {
            return Image(systemName: "hands.sparkles.fill").foregroundColor(.green) // Dans le niveau
        } else {
            return Image(systemName: "snowflake").foregroundColor(.blue)           // Sous le niveau
        }
    }

    private func loadClients() {
        let baseClients = DatabaseManager.shared.queryClients()
        let metrics = DatabaseManager.shared.fetchClientMetricsWithVolat()
        
        clientsSource = baseClients.compactMap { client in
            if let m = metrics[client.id] {
                let dateDebut = m.lastDate.flatMap { DatabaseManager.shared.parseDate($0) }
                let dateAnciennete = DatabaseManager.shared.getDateAnciennete(for: client.id)
                return ClientDisplay(
                    id: client.id,
                    nom: client.nom,
                    prenom: client.prenom,
                    srriInitial: client.srri ?? 0,
                    dateDebut: dateDebut,
                    valo: m.totalValo,
                    srriActuel: m.lastSrri ?? 0,
                    volat: m.lastVolat,
                    dateAnciennete: dateAnciennete
                )
            }
            return nil
        }
        appliquerFiltresEtTri()
    }
    
    private func appliquerFiltresEtTri() {
        var result = clientsSource
        
        // Filtre par texte (nom ou prénom)
        if !rechercheTexte.isEmpty {
            let recherche = rechercheTexte.lowercased()
            result = result.filter { client in
                client.nom.lowercased().contains(recherche) ||
                client.prenom.lowercased().contains(recherche)
            }
        }
        
        // Filtre par risque
        if filtreRisqueAugmente || filtreRisqueIdentique || filtreRisqueReduit {
            result = result.filter { client in
                let diff = client.srriActuel - client.srriInitial
                if filtreRisqueAugmente && diff > 0 { return true }
                if filtreRisqueIdentique && diff == 0 { return true }
                if filtreRisqueReduit && diff < 0 { return true }
                return false
            }
        }
        
        // Filtre par valorisation
        if let montant = Double(montantFiltre.replacingOccurrences(of: ",", with: ".")), montant > 0 {
            result = result.filter { client in
                if filtreValoSup {
                    return client.valo > montant
                } else {
                    return client.valo < montant
                }
            }
        }
        
        // Tri
        result.sort { a, b in
            switch critereTri {
            case .nom:
                return ordreCroissant ? a.nom < b.nom : a.nom > b.nom
            case .srriInitial:
                return ordreCroissant ? a.srriInitial < b.srriInitial : a.srriInitial > b.srriInitial
            case .srriActuel:
                return ordreCroissant ? a.srriActuel < b.srriActuel : a.srriActuel > b.srriActuel
            case .iconeRisque:
                let risqueA = a.srriActuel - a.srriInitial
                let risqueB = b.srriActuel - b.srriInitial
                return ordreCroissant ? risqueA < risqueB : risqueA > risqueB
            }
        }
        
        clients = result
    }
}



private let valoFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    formatter.groupingSeparator = " "
    return formatter
}()

