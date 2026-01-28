import SwiftUI

// 1. Ajout d'un calcul de pourcentage pour chaque support
struct SupportAvecPourcentage {
    let support: Support
    let montant: Double
    let pourcentage: Double
}

struct ContratDetailView: View {
    let contrat: Affaire
    
    @State private var annualValo: [(Int, Double)] = []
    @State private var monthlyValo: [(Date, Double)] = []
    @State private var annualMouvements: [(Int, Double)] = []
    @State private var monthlyMouvements: [(Date, Double)] = []
    @State private var annualPerfVol: [(Int, Double, Double)] = []
    @State private var monthlyCombinedValoMouv: (valo: [(Date, Double)], mouv: [(Date, Double)]) = ([], [])
    
    // Métriques du contrat
    @State private var srriActuel: Int = 0
    @State private var volat: Double? = nil
    @State private var valo: Double = 0
    @State private var lastDate: Date? = nil
    
    // Mouvements
    @State private var totalVersements: Double = 0
    @State private var totalRetraits: Double = 0
    @State private var soldeMouvements: Double = 0
    
    @State private var supportsSynthese: [SyntheseSupportClient] = []
    @State private var datesDisponibles: [String] = []
    @State private var dateSelectionnee: String = ""
    @State private var selectedAllocationNom: String = ""
    @State private var comparisonData: [SicavComparisonPoint] = []
    
    // Fix for the onChange handler in comparaisonContratSection
    // Fix for the onChange handler in comparaisonContratSection
    @ViewBuilder
    private func comparaisonContratSection(contratId: Int) -> some View {
        VStack(spacing: 12) {
            Picker("Sélectionnez une allocation", selection: $selectedAllocationNom) {
                ForEach(DatabaseManager.shared.queryAllocationNoms(), id: \.self) { nom in
                    Text(nom).tag(nom)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedAllocationNom) { newAlloc in
                guard !newAlloc.isEmpty else { return }
                
                let contratSeries = DatabaseManager.shared
                    .queryHistoriqueAffaireTuples()
                    .filter { $0.id == contratId }
                    .compactMap { h -> (String, Double)? in
                        guard let norm = normalizeDateString(h.date) else { return nil }
                        return (norm, h.sicav)
                    }
                
                let allocSeries = DatabaseManager.shared
                    .querySicavSeries(for: newAlloc)
                    .compactMap { h -> (String, Double)? in
                        guard let norm = normalizeDateString(h.date) else { return nil }
                        return (norm, h.sicav)
                    }
                
                comparisonData = alignSeries(
                    clientSeries: contratSeries,
                    allocationSeries: allocSeries,
                    allocationName: newAlloc
                )
            }
            
            CombinedSicavChart(data: comparisonData)
        }
    }
    
    
    
    
    
    
    var body: some View {
        List {
            Section {
                if let ref = contrat.ref {
                    Text("Référence : \(ref)")
                        .font(.headline)
                }
                if let dateStr = contrat.dateDebut,
                   let d = DatabaseManager.shared.parseDate(dateStr) {
                    Text("Ouvert le \(contratDateFormatter.string(from: d))")
                        .foregroundColor(.secondary)
                }
                
                // Dernière valorisation connue avec sa date
                if valo > 0 {
                    HStack {
                        Text("Valorisation :")
                        Spacer()
                        let valeur = valoFormatter.string(from: NSNumber(value: valo)) ?? "0 €"
                        Text(valeur)
                            .font(.headline)
                    }
                    if let lastDate = lastDate {
                        HStack {
                            Text("Au \(contratDateFormatter.string(from: lastDate))")
                                .foregroundColor(.secondary)
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
                
                // Date de fermeture si elle existe
                if let dateCleStr = contrat.dateCle,
                   !dateCleStr.isEmpty,
                   let dateCle = DatabaseManager.shared.parseDate(dateCleStr) {
                    Text("Fermé le \(contratDateFormatter.string(from: dateCle))")
                        .foregroundColor(.red)
                }
                
                // Mouvements
                HStack {
                    Text("Versements :");
                    Spacer();
                    Text(valoFormatter.string(from: NSNumber(value: totalVersements)) ?? "0 €")
                }
                HStack {
                    Text("Retraits et frais :");
                    Spacer();
                    Text(valoFormatter.string(from: NSNumber(value: totalRetraits)) ?? "0 €")
                }
                HStack {
                    Text("Solde mouvements :");
                    Spacer();
                    Text(valoFormatter.string(from: NSNumber(value: soldeMouvements)) ?? "0 €")
                }
            } header: {
                Text("Informations contrat")
            }
            
            // Section SRRI
            Section {
                HStack {
                    Text("SRRI initial : \(contrat.srri ?? 0)")
                }
                HStack {
                    Text("SRRI actuel : \(srriActuel)")
                    if let v = volat {
                        Text(String(format: "(%.2f%%)", v))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    risqueIcon(srriInitial: contrat.srri ?? 0, srriActuel: srriActuel)
                }
            } header: {
                Text("SRRI")
            }
 
            // Section ESG

            if let esg = calculerNotesESGContrat() {
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


/*            if let esg = calculerNotesESGContrat() {
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
            
            // Section Supports financiers (simplifiée → NavigationLink vers vue dédiée)
            if !supportsSynthese.isEmpty {
                Section(header: Text("Supports financiers")) {
                    NavigationLink(
                        destination: SupportsFinanciersListView(
                            contratId: contrat.id,
                            datesDisponibles: datesDisponibles,
                            dateSelectionnee: dateSelectionnee
                        )
                    ) {
                        Label("Liste des supports financiers", systemImage: "list.bullet")
                            .foregroundColor(.blue)
                    }
                }
            } else {
                Section(header: Text("Supports financiers")) {
                    Text("Aucun support trouvé")
                        .foregroundColor(.secondary)
                }
            }
            
            if !monthlyCombinedValoMouv.valo.isEmpty && !monthlyCombinedValoMouv.mouv.isEmpty {
                Section {
                    DisclosureGroup {
                        MonthlyCombinedChart(
                            valoData: monthlyCombinedValoMouv.valo.map { (date: $0.0, valeur: $0.1) },
                            mouvData: monthlyCombinedValoMouv.mouv.map { (date: $0.0, cumulMouvements: $0.1) }
                        )
                    } label: {
                        HStack {
                            Text("📈💰")
                            Text("Valorisation & mouvements mensuels combinés")
                        }
                    }
                }
            }
            
            if !annualPerfVol.isEmpty {
                Section {
                    DisclosureGroup {
                        AnnualPerfVolChart(data: annualPerfVol)
                    } label: {
                        HStack {
                            Text("📊")
                            Text("Performances et volatilités annuelles")
                        }
                    }
                }
            }
            
            Section {
                DisclosureGroup {
                    comparaisonContratSection(contratId: contrat.id)
                } label: {
                    HStack {
                        Text("📊")
                        Text("Suivi comparatif contrat")
                    }
                }
            }
        }
        .navigationTitle("Détail contrat")
        .onAppear {
            chargerDonneesContrat()
        }
    }
    
    
    private func chargerDonneesContrat() {
        
        // Diagnostic temporaire
        //       DatabaseManager.shared.diagnosticContratSupports(contrat.id)
        
        
        
        // Chargement des graphiques
        annualValo = DatabaseManager.shared.getAnnualValoForAffaire(contrat.id)
        monthlyValo = DatabaseManager.shared.getMonthlyValoForAffaire(contrat.id)
        annualMouvements = DatabaseManager.shared.getAnnualMouvementsForAffaire(contrat.id)
        monthlyMouvements = DatabaseManager.shared.getMonthlyMouvementsForAffaire(contrat.id)
        annualPerfVol = DatabaseManager.shared.getAnnualPerfVolForAffaire(contrat.id)
        monthlyCombinedValoMouv.valo = DatabaseManager.shared.getMonthlyValoForAffaire(contrat.id)
        monthlyCombinedValoMouv.mouv = DatabaseManager.shared.getMonthlyMouvementsForAffaire(contrat.id)
        datesDisponibles = DatabaseManager.shared.getDatesDisponiblesPourContratRAW(contrat.id)
        if let premiere = datesDisponibles.first {
            dateSelectionnee = premiere
            supportsSynthese = DatabaseManager.shared.getSyntheseSupportsPourContratDetail(contrat.id, aLaDate: premiere)
        }
        
        
        // Chargement des métriques SRRI
        if let metrics = DatabaseManager.shared.getContratMetrics(for: contrat.id) {
            valo = metrics.valo
            srriActuel = metrics.srriActuel ?? 0
            volat = metrics.volat
            lastDate = metrics.date.flatMap { DatabaseManager.shared.parseDate($0) }
        }
        
        // Chargement des mouvements
        let mouvements = DatabaseManager.shared.getMouvementsStatsForAffaire(contrat.id)
        totalVersements = mouvements.versements
        totalRetraits = mouvements.retraits
        soldeMouvements = mouvements.solde
    }
    
    @ViewBuilder
    private func risqueIcon(srriInitial: Int, srriActuel: Int) -> some View {
        if srriActuel > srriInitial {
            Image(systemName: "flame.fill").foregroundColor(.red)
        } else if srriActuel == srriInitial {
            Image(systemName: "hands.sparkles.fill").foregroundColor(.green)
        } else {
            Image(systemName: "snowflake").foregroundColor(.blue)
        }
    }
    private func calculerNotesESGContrat() -> ESGNoteResult? {
        guard !supportsSynthese.isEmpty else { return nil }
        return ESGUtils.calculerNotesESGPonderees(
            supports: supportsSynthese.map {
                (valeur: $0.totalValo,
                 noteE: $0.noteE,
                 noteS: $0.noteS,
                 noteG: $0.noteG)
            }
        )
    }


}


private let contratDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    formatter.locale = Locale(identifier: "fr_FR")
    return formatter
}()
// 3. Formatage amélioré des montants
private let valoFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    formatter.currencySymbol = "€"
    formatter.groupingSeparator = " "
    formatter.positiveFormat = "#,##0 ¤"
    return formatter
}()

// 4. Formatage des dates amélioré
private let localDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    formatter.locale = Locale(identifier: "fr_FR")
    return formatter
}()

// 5. Extension pour DatabaseManager - méthode de récupération optimisée
extension DatabaseManager {
    func getSyntheseSupportsPourContratAvecStats(_ affaireId: Int, aLaDate: Date? = nil) -> (supports: [(Support, Double)], totalValo: Double, nbSupports: Int) {
        let supports = getSyntheseSupportsPourContrat(affaireId, aLaDate: aLaDate)
        let total = supports.reduce(0) { $0 + $1.montant }
        return (supports: supports, totalValo: total, nbSupports: supports.count)
    }
}


struct SupportsFinanciersListView: View {
    let contratId: Int
    let datesDisponibles: [String]
    @State var dateSelectionnee: String
    
    @State private var supports: [SyntheseSupportClient] = []
    
    // On garde la plus récente à gauche (index 0)
    private var orderedDates: [String] {
        datesDisponibles.reversed()
    }
    
    var body: some View {
        VStack {
            // Bloc central unique pour la date
            HStack {
                Button {
                    goFutur()
                } label: {
                    Image(systemName: "chevron.left")
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(currentIndex == 0)
                
                Spacer()
                
                Text(formatDate(dateSelectionnee))
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .clipShape(Capsule())
                    .id(dateSelectionnee)
                    .transition(.opacity.combined(with: .slide))
                
                Spacer()
                
                Button {
                    goPasse()
                } label: {
                    Image(systemName: "chevron.right")
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(currentIndex == orderedDates.count - 1)
            }
            .padding()
            .gesture(
                DragGesture()
                    .onEnded { value in
                        if value.translation.width < -50 {
                            goPasse()
                        } else if value.translation.width > 50 {
                            goFutur()
                        }
                    }
            )
            
            // Liste des supports financiers
            List {
                if supports.isEmpty {
                    Text("Aucun support trouvé")
                        .foregroundColor(.secondary)
                } else {
                    let totalValo = supports.reduce(0) { $0 + $1.totalValo }
                    HStack {
                        Spacer()
                        Text("Valorisation totale : \(valoFormatter.string(from: NSNumber(value: totalValo)) ?? "0")")
                            .font(.headline)
                            .padding(8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    
                    ForEach(supports) { sup in
                        NavigationLink(destination: SupportDetailView(contratId: contratId, support: sup)) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(sup.nom ?? "Sans nom")
                                    .font(.headline)
                                Text("ISIN : \(sup.codeIsin ?? "-")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                if let srri = sup.srri {
                                    Text("SRRI : \(srri)")
                                        .font(.caption2)
                                        .foregroundColor(.purple)
                                }

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
                                
                                HStack {
                                    Spacer()
                                    Text(valoFormatter.string(from: NSNumber(value: sup.totalValo)) ?? "0")
                                        .font(.headline)
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
            }
            .listStyle(.plain)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("Supports financiers")
        .onAppear { loadSupports() }
    }
    
    // MARK: - Helpers
    
    private var currentIndex: Int {
        orderedDates.firstIndex(of: dateSelectionnee) ?? 0
    }
    
    private func goFutur() {
        if currentIndex > 0 {
            withAnimation {
                dateSelectionnee = orderedDates[currentIndex - 1]
                loadSupports()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    private func goPasse() {
        if currentIndex < orderedDates.count - 1 {
            withAnimation {
                dateSelectionnee = orderedDates[currentIndex + 1]
                loadSupports()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }
    
    private func loadSupports() {
        if let d = DatabaseManager.shared.parseDate(dateSelectionnee) {
            supports = DatabaseManager.shared.getSyntheseSupportsPourContratDetail(
                contratId,
                aLaDate: d
            )
        } else {
            supports = []
        }
    }
    
    private func formatDate(_ dateStr: String) -> String {
        if let d = DatabaseManager.shared.parseDate(dateStr) {
            return contratDateFormatter.string(from: d)
        }
        return dateStr
    }
}
