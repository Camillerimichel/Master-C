import SwiftUI
import Charts

struct ClientDetailView: View {
    let client: Client
    
    @State private var srriActuel: Int = 0
    @State private var volat: Double? = nil
    @State private var valo: Double = 0
    @State private var dateDebut: Date? = nil
    @State private var dateAnciennete: Date? = nil
    @State private var contrats: [Affaire] = []
    @State private var contratsMetrics: [Int: (totalValo: Double, lastDate: String?, lastSrri: Int?, lastVolat: Double?)] = [:]
    
    @State private var totalVersements: Double = 0
    @State private var totalRetraits: Double = 0
    @State private var soldeMouvements: Double = 0
    
    @State private var supportsSynthese: [SyntheseSupportClient] = []
    @State private var datesDisponibles: [String] = []
    @State private var dateSelectionnee: String = ""
    @State private var supportsGroupExpanded: Bool = false
    
    // Variables pour les graphiques harmonisés
    @State private var annualValo: [(Int, Double)] = []
    @State private var monthlyValo: [(Date, Double)] = []
    @State private var annualMouvements: [(Int, Double)] = []
    @State private var monthlyMouvements: [(Date, Double)] = []
    @State private var annualPerfVol: [(Int, Double, Double)] = []
    @State private var monthlyCombinedValoMouv: (valo: [(Date, Double)], mouv: [(Date, Double)]) = ([], [])
    
    @State private var distMode: Int = 0
    @State private var distType: Int = 0
    @State private var distData: [DistributionItem] = []
    
    @State private var selectedAllocationNom: String = ""
    @State private var comparisonData: [SicavComparisonPoint] = []
    @State private var expandedSection: String? = nil
    
    
    
    private var contratsTriés: [Affaire] {
        let contratsAvecHistorique = contrats.filter { contrat in
            DatabaseManager.shared.contratADesDonneesHistoriques(contrat.id)
        }
        return contratsAvecHistorique.sorted { contrat1, contrat2 in
            let contrat1Ouvert = contrat1.dateCle?.isEmpty != false
            let contrat2Ouvert = contrat2.dateCle?.isEmpty != false
            if contrat1Ouvert && !contrat2Ouvert {
                return true
            } else if !contrat1Ouvert && contrat2Ouvert {
                return false
            } else {
                guard let date1Str = contrat1.dateDebut,
                      let date2Str = contrat2.dateDebut,
                      let date1 = DatabaseManager.shared.parseDate(date1Str),
                      let date2 = DatabaseManager.shared.parseDate(date2Str) else {
                    return false
                }
                return date1 > date2
            }
        }
    }
    @ViewBuilder
    func normalizeDateString(_ s: String) -> String? {
        if let d = DatabaseManager.shared.parseDate(s) {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.string(from: d)
        }
        return nil
    }
    
    private func comparaisonSicavSection(clientId: Int) -> some View {
        DisclosureGroup("📊 Suivi comparatif") {
            VStack(spacing: 12) {
                Picker("Sélectionnez une allocation", selection: $selectedAllocationNom) {
                    ForEach(DatabaseManager.shared.queryAllocationNoms(), id: \.self) { nom in
                        Text(nom).tag(nom)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedAllocationNom) { newAlloc in
                    // --- Série client ---
                    let clientSeries = DatabaseManager.shared
                        .queryHistoriquePersonne()
                        .filter { $0.id == clientId }
                        .compactMap { h -> (String, Double)? in
                            guard let d = h.date, let v = h.sicav,
                                  let norm = normalizeDateString(d) else { return nil }
                            return (norm, v)
                        }
                    // DEBUG print client
                    //                   print("=== Données Client (id: \(clientId)) ===")
                    //                                       for (d, v) in clientSeries.prefix(20) {
                    //                        print("\(d) → \(v)")
                    //                    }
                    //                    print("Total points client : \(clientSeries.count)")
                    
                    // --- Série allocation ---
                    let allocSeries = DatabaseManager.shared
                        .querySicavSeries(for: newAlloc)
                        .compactMap { h -> (String, Double)? in
                            let norm = normalizeDateString(h.date)
                            return norm.map { ($0, h.sicav) }
                        }
                    // Alignement
                    comparisonData = alignSeries(
                        clientSeries: clientSeries,
                        allocationSeries: allocSeries,
                        allocationName: newAlloc
                    )
                }
                
                CombinedSicavChart(data: comparisonData)
            }
        }
    }
    
    
    
    var body: some View {
        List {
            Section(header: Text("Valorisation et risque")) {

                
                    HStack { Text("Valorisation :"); Spacer(); Text(valoFormatter.string(from: NSNumber(value: valo)) ?? "0") }
                    HStack { Text("Versements :"); Spacer(); Text(valoFormatter.string(from: NSNumber(value: totalVersements)) ?? "0") }
                    HStack { Text("Retraits :"); Spacer(); Text(valoFormatter.string(from: NSNumber(value: totalRetraits)) ?? "0") }
                    HStack { Text("Solde mouvements :"); Spacer(); Text(valoFormatter.string(from: NSNumber(value: soldeMouvements)) ?? "0") }
                
        

                HStack {
                    Text("SRRI initial : \(client.srri ?? 0)")
                }
                HStack {
                    Text("SRRI actuel : \(srriActuel)")
                    if let v = volat {
                        Text(String(format: "(%.2f%%)", v))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    risqueIcon(srriInitial: client.srri ?? 0, srriActuel: srriActuel)
                }
            }
            if let esg = calculerNotesESGClient() {
                Section {
                    // Jauge globale
                    ESGGaugeView(
                        noteE: esg.noteELettre,
                        noteS: esg.noteSLettre,
                        noteG: esg.noteGLettre,
                        showComment: true
                    )
                    
                    // Sous-notes en petit sous la jauge
                    HStack {
                        Text("E : \(esg.noteELettre)")
                            .foregroundColor(.green)
                            .font(.footnote)
                        Spacer()
                        Text("S : \(esg.noteSLettre)")
                            .foregroundColor(.blue)
                            .font(.footnote)
                        Spacer()
                        Text("G : \(esg.noteGLettre)")
                            .foregroundColor(.orange)
                            .font(.footnote)
                    }
                } header: {
                    Text("ESG")
                }
            }


/*            if let esg = calculerNotesESGClient() {
                Section {
                    HStack {
                        Text("Note E : \(esg.noteELettre)")
                            .foregroundColor(.green)
                        Spacer()
                        Text("Note S : \(esg.noteSLettre)")
                            .foregroundColor(.blue)
                        Spacer()
                        Text("Note G : \(esg.noteGLettre)")
                            .foregroundColor(.orange)
                    }
                } header: {
                    Text("ESG")
                }
            }
*/
            
        
            // Section Liste des contrats (remontée ici)
            if !contratsTriés.isEmpty {
                Section(header: Text("Contrats")) {
                    NavigationLink(
                        destination: ContratsListView(contrats: contratsTriés, contratsMetrics: contratsMetrics)
                    ) {
                        Label("Liste des contrats", systemImage: "list.bullet")
                            .foregroundColor(.blue)
                    }
                }
            }

 
            // Section Supports financiers (regroupement)
            Section(header: Text("Supports financiers")) {
                if !datesDisponibles.isEmpty {
                    DisclosureGroup(isExpanded: $supportsGroupExpanded) {
                        Picker("Date", selection: $dateSelectionnee) {
                            ForEach(datesDisponibles, id: \.self) { dateStr in
                                Text(dateStr)
                            }
                        }
                        .onChange(of: dateSelectionnee) { nouvelleDate in
                            supportsSynthese = DatabaseManager.shared.getSyntheseSupportsPourClient(client.id, aLaDate: nouvelleDate)
                        }
                        
                        let totalValoSupports = supportsSynthese.reduce(0) { $0 + $1.totalValo }
                        HStack {
                            Spacer()
                            Text("Valorisation totale : \(valoFormatter.string(from: NSNumber(value: totalValoSupports)) ?? "0")")
                                .font(.headline)
                                .padding(8)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(8)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        
                        ForEach(supportsSynthese) { sup in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(sup.nom ?? "Sans nom").font(.headline)
                                Text("ISIN : \(sup.codeIsin ?? "-")").font(.caption).foregroundColor(.secondary)
                                if sup.noteE != nil || sup.noteS != nil || sup.noteG != nil {
                                    HStack(spacing: 12) {
                                        Text("Env. : \(sup.noteE ?? "-")")
                                            .font(.caption2)
                                            .foregroundColor(.green)
                                        Text("Social : \(sup.noteS ?? "-")")
                                            .font(.caption2)
                                            .foregroundColor(.blue)
                                        Text("Gouv. : \(sup.noteG ?? "-")")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                                HStack { Spacer(); Text(valoFormatter.string(from: NSNumber(value: sup.totalValo)) ?? "0").font(.headline) }
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        let vl = sup.totalNbUC > 0 ? sup.totalValo / sup.totalNbUC : 0
                                        Text("VL : \(vl, specifier: "%.3f")")
                                        Text("PRMP : \(sup.prmpMoyen, specifier: "%.3f")")
                                            .foregroundColor(sup.prmpMoyen < vl ? .green : .red)
                                    }
                                    Spacer()
                                    if sup.prmpMoyen < (sup.totalNbUC > 0 ? sup.totalValo / sup.totalNbUC : 0) {
                                        Image(systemName: "arrow.up.circle.fill").foregroundColor(.green)
                                    } else {
                                        Image(systemName: "arrow.down.circle.fill").foregroundColor(.red)
                                    }
                                    Spacer()
                                    ProgressView(value: sup.poidsPourcent / 100)
                                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                                        .frame(width: 80)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    } label: {
                        Text("📊 Supports financiers à la date sélectionnée")
                    }
                }
                
                // Répartition (intégrée dans la section Supports financiers)
                DisclosureGroup("📊 Répartition (dernière VL)") {
                    Picker("Dimension", selection: $distType) {
                        Text("Supports").tag(0)
                        Text("Cat. principale").tag(1)
                        Text("Cat. générale").tag(2)
                        Text("Cat. détaillée").tag(3)
                        Text("Géographie").tag(4)
                        Text("Promoteur").tag(5)
                        Text("SRRI").tag(6)   // 👈 ajout
                    }
                    .pickerStyle(.menu)
                    .onChange(of: distType) { _ in reloadDistributionClient() }
                    
                    Picker("Affichage", selection: $distMode) {
                        Text("Barres").tag(0)
                        Text("Secteurs").tag(1)
                    }
                    .pickerStyle(.segmented)
                    
                    if distData.isEmpty {
                        Text("Aucune donnée pour la dernière valorisation.")
                            .foregroundColor(.secondary)
                    } else {
                        if distMode == 0 {
                            DistributionBarChart(items: distData)
                        } else {
                            DistributionPieChart(items: distData)
                        }
                    }
                }
            }
            
            // Section Graphiques (regroupement)
            Section(header: Text("Graphiques")) {
                if !monthlyCombinedValoMouv.valo.isEmpty && !monthlyCombinedValoMouv.mouv.isEmpty {
                    DisclosureGroup("📊 Valorisation & mouvements mensuels combinés") {
                        MonthlyCombinedChart(
                            valoData: monthlyCombinedValoMouv.valo.map { (date: $0.0, valeur: $0.1) },
                            mouvData: monthlyCombinedValoMouv.mouv.map { (date: $0.0, cumulMouvements: $0.1) }
                        )
                    }
                }
                if !annualPerfVol.isEmpty {
                    DisclosureGroup("📊 Performances et volatilités annuelles") {
                        AnnualPerfVolChart(data: annualPerfVol)
                    }
                }
                comparaisonSicavSection(clientId: client.id)
            }
            
            // Section Documents
            Section(header: Text("Documents")) {
                NavigationLink(
                    destination: DocumentsClientView(clientId: client.id)
                ) {
                    Label("Visualiser les documents", systemImage: "doc.text.magnifyingglass")
                        .foregroundColor(.blue)
                }
            }
            
        }
        .onAppear {
            chargerInfosClient()
        }
        .navigationTitle(client.displayName) // Utilise le nom du client au lieu de "Détail client"
    }
    
    private func chargerInfosClient() {
        let metrics = DatabaseManager.shared.fetchClientMetricsWithVolat()
        if let m = metrics[client.id] {
            srriActuel = m.lastSrri ?? 0
            volat = m.lastVolat
            valo = m.totalValo
            dateDebut = m.lastDate.flatMap { DatabaseManager.shared.parseDate($0) }
        }
        dateAnciennete = DatabaseManager.shared.getDateAnciennete(for: client.id)
        let mouvements = DatabaseManager.shared.getMouvementsStats(for: client.id)
        totalVersements = mouvements.versements
        totalRetraits = mouvements.retraits
        soldeMouvements = mouvements.solde
        datesDisponibles = DatabaseManager.shared.getDatesDisponiblesPourClient(client.id)
        if let premiereDate = datesDisponibles.first {
            dateSelectionnee = premiereDate
            supportsSynthese = DatabaseManager.shared.getSyntheseSupportsPourClient(client.id, aLaDate: premiereDate)
        }
        contrats = DatabaseManager.shared.queryAffaires(for: client.id)
        contratsMetrics = DatabaseManager.shared.fetchContratMetricsWithVolat()
        annualValo = DatabaseManager.shared.getAnnualValoForClient(client.id)
        monthlyValo = DatabaseManager.shared.getMonthlyValoForClient(client.id)
        annualMouvements = DatabaseManager.shared.getAnnualMouvementsForClient(client.id)
        monthlyMouvements = DatabaseManager.shared.getMonthlyMouvementsForClient(client.id)
        annualPerfVol = DatabaseManager.shared.getAnnualPerfVolForClient(client.id)
        monthlyCombinedValoMouv.valo = DatabaseManager.shared.getMonthlyValoForClient(client.id)
        monthlyCombinedValoMouv.mouv = DatabaseManager.shared.getMonthlyMouvementsForClient(client.id)
        reloadDistributionClient()
    }
    
    private func risqueIcon(srriInitial: Int, srriActuel: Int) -> some View {
        if srriActuel > srriInitial { return Image(systemName: "flame.fill").foregroundColor(.red) }
        else if srriActuel == srriInitial { return Image(systemName: "hands.sparkles.fill").foregroundColor(.green) }
        else { return Image(systemName: "snowflake").foregroundColor(.blue) }
    }
    
    private func reloadDistributionClient() {
        let id = client.id
        let type = distType
        DispatchQueue.global(qos: .userInitiated).async {
            let result: [DistributionItem]
            switch type {
            case 0: result = DatabaseManager.shared.getLatestDistributionSupportsForClient(id)
            case 1: result = DatabaseManager.shared.getLatestDistributionCategorieForClient(id, key: "cat_principale")
            case 2: result = DatabaseManager.shared.getLatestDistributionCategorieForClient(id, key: "cat_gene")
            case 3: result = DatabaseManager.shared.getLatestDistributionCategorieForClient(id, key: "cat_det")
            case 4: result = DatabaseManager.shared.getLatestDistributionCategorieForClient(id, key: "cat_geo")
            case 5: result = DatabaseManager.shared.getLatestDistributionPromoteurForClient(id)
            case 6: result = DatabaseManager.shared.getLatestDistributionCategorieForClient(id, key: "SRRI")  // 👈 ajout
            default: result = []
            }
            DispatchQueue.main.async {
                self.distData = result
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
    private func calculerNotesESGClient() -> ESGNoteResult? {
        // Liste des contrats du client avec valorisation
        let contratsAvecValo = contrats.compactMap { contrat -> (valo: Double, noteE: String?, noteS: String?, noteG: String?)? in
            guard let metrics = contratsMetrics[contrat.id] else { return nil }
            let valo = metrics.totalValo
            guard valo > 0 else { return nil }
            
            // On réutilise la fonction de calcul ESG au niveau contrat
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

}

private let valoFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    formatter.groupingSeparator = " "
    return formatter
}()



struct ContratsListView: View {
    let contrats: [Affaire]
    let contratsMetrics: [Int: (totalValo: Double, lastDate: String?, lastSrri: Int?, lastVolat: Double?)]
    
    var body: some View {
        List {
            ForEach(contrats) { contrat in
                let estFermé = !(contrat.dateCle?.isEmpty ?? true)
                let metrics = contratsMetrics[contrat.id]
                let srriInitial = contrat.srri ?? 0
                let srriActuel = metrics?.lastSrri ?? 0
                
                NavigationLink(destination: ContratDetailView(contrat: contrat)) {
                    VStack(alignment: .leading, spacing: 6) {
                        // === Ton contenu interne actuel (réf, statut, dates, valo, SRRI...) ===
                        HStack {
                            if let ref = contrat.ref {
                                Text(ref).font(.headline)
                            }
                            Spacer()
                            Text(estFermé ? "FERMÉ" : "OUVERT")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(estFermé ? Color.red : Color.green)
                                .cornerRadius(4)
                        }
                        
                        if let dateStr = contrat.dateDebut,
                           let d = DatabaseManager.shared.parseDate(dateStr) {
                            Label("\(dateFormatter.string(from: d))", systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if estFermé,
                           let dateCleStr = contrat.dateCle,
                           let dateCle = DatabaseManager.shared.parseDate(dateCleStr) {
                            Label("Fermé le \(dateFormatter.string(from: dateCle))", systemImage: "calendar.badge.minus")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        
                        if let valo = metrics?.totalValo {
                            HStack {
                                Spacer()
                                Label(
                                    valoFormatter.string(from: NSNumber(value: valo)) ?? "0 €",
                                    systemImage: "eurosign.circle"
                                )
                                .font(.caption)
                                .foregroundColor(.primary)
                            }
                        }
                        
                        HStack {
                            Text("SRRI initial : \(srriInitial)")
                                .font(.subheadline)
                            
                            Text("SRRI actuel : \(srriActuel)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(srriBadgeColor(srriInitial: srriInitial, srriActuel: srriActuel))
                                .cornerRadius(4)
                            
                            risqueIcon(srriInitial: srriInitial, srriActuel: srriActuel)
                        }
                        if let esg = calculerNotesESGContrat(contrat) {
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
        .navigationTitle("Liste des contrats")
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

}

// MARK: - Helpers
private func risqueIcon(srriInitial: Int, srriActuel: Int) -> some View {
    if srriActuel > srriInitial {
        return Image(systemName: "flame.fill").foregroundColor(.red)
    } else if srriActuel == srriInitial {
        return Image(systemName: "hands.sparkles.fill").foregroundColor(.green)
    } else {
        return Image(systemName: "snowflake").foregroundColor(.blue)
    }
}

private func srriBadgeColor(srriInitial: Int, srriActuel: Int) -> Color {
    if srriActuel > srriInitial {
        return .red
    } else if srriActuel == srriInitial {
        return .green
    } else {
        return .blue
    }
}
