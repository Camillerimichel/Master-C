import SwiftUI
import Charts

private let localDateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateStyle = .short
    df.timeStyle = .none
    df.locale = Locale(identifier: "fr_FR")
    return df
}()

struct SupportDetailView: View {
    let contratId: Int
    let support: SyntheseSupportClient
    
    @State private var historique: [HistoAffairesW] = []
    @State private var expandedSection: Int? = nil
    @State private var selectedChart: Int = 0

    var body: some View {
        List {
            // Informations support
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedSection == 1 },
                    set: { expandedSection = $0 ? 1 : nil }
                )
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    // Bloc identité
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Nom : \(support.nom ?? "-")")
                        Text("ISIN : \(support.codeIsin ?? "-")")
                        Text("Promoteur : \(support.promoteur ?? "-")")
                        
                        let vl = support.totalNbUC > 0 ? support.totalValo / support.totalNbUC : 0
                        Text("VL : \(String(format: "%.3f", vl))")
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Poids dans le contrat : \(String(format: "%.2f %%", support.poidsPourcent))")
                            ProgressView(value: support.poidsPourcent / 100)
                                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Bloc catégories
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Catégorie générale : \(support.catGene ?? "-")")
                        Text("Catégorie principale : \(support.catPrincipale ?? "-")")
                        Text("Catégorie détaillée : \(support.catDet ?? "-")")
                        Text("Catégorie géographique : \(support.catGeo ?? "-")")
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    
                    // Bloc Caractéristiques financières
                    infoBlock(title: "Caractéristiques financières") {
                        rowRight(label: "Valorisation totale",
                                 value: "\(Int(support.totalValo)) €")
                        rowRight(label: "Nombre d’UC",
                                 value: String(format: "%.3f", support.totalNbUC))

                        // 👉 Ajout SRRI
                        if let srri = support.srri {
                            rowRight(label: "SRRI", value: "\(srri)")
                        }

                        let vl = support.totalNbUC > 0 ? support.totalValo / support.totalNbUC : 0
                        let isGain = support.prmpMoyen < vl
                        rowRightIcon(
                            label: "PRMP moyen",
                            value: String(format: "%.3f", support.prmpMoyen),
                            color: isGain ? .green : .red,
                            systemImage: isGain ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
                        )
                        
                        rowRight(label: "Taux de rétrocession",
                                 value: support.tauxRetro != nil ? "\(Int(support.tauxRetro!))" : "-")

                  }

                    
                    // Bloc ESG
                    infoBlock(title: "ESG") {
                        rowRight(label: "Environnement", value: support.noteE ?? "-")
                        rowRight(label: "Social", value: support.noteS ?? "-")
                        rowRight(label: "Gouvernance", value: support.noteG ?? "-")
                    }
                }
                .padding(.vertical, 6)
            } label: {
                Label("Informations support", systemImage: "info.circle")
            }
            
            // Graphiques
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedSection == 2 },
                    set: { expandedSection = $0 ? 2 : nil }
                )
            ) {
                if historique.isEmpty {
                    Text("Aucune donnée trouvée")
                        .foregroundColor(.secondary)
                } else {
                    VStack(spacing: 16) {
                        Picker("Type de graphique", selection: $selectedChart) {
                            Text("Valorisation").tag(0)
                            Text("VL").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        
                        if selectedChart == 0 {
                            let points = historique.compactMap { item in
                                if let d = item.date, let v = item.valo {
                                    return (date: d, valo: v)
                                }
                                return nil
                            }
                            if let minV = points.map({ $0.valo }).min(),
                               let maxV = points.map({ $0.valo }).max() {
                                Chart(points, id: \.date) { p in
                                    LineMark(
                                        x: .value("Date", p.date),
                                        y: .value("Valorisation", p.valo)
                                    )
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(.blue)
                                }
                                .chartYScale(domain: minV...maxV)
                                .frame(height: 250)
                                .padding(.horizontal)
                            }
                        }
                        
                        if selectedChart == 1 {
                            let vlPoints = historique.compactMap { item in
                                if let d = item.date, let vl = item.vl {
                                    return (date: d, vl: vl)
                                }
                                return nil
                            }
                            if let minVL = vlPoints.map({ $0.vl }).min(),
                               let maxVL = vlPoints.map({ $0.vl }).max() {
                                Chart(vlPoints, id: \.date) { p in
                                    LineMark(
                                        x: .value("Date", p.date),
                                        y: .value("VL", p.vl)
                                    )
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(.green)
                                }
                                .chartYScale(domain: minVL...maxVL)
                                .frame(height: 250)
                                .padding(.horizontal)
                            }
                        }
                        
                        if selectedChart == 2 {
                            let cumulPoints = cumulMouvementsAffaire()
                            if let minC = cumulPoints.map({ $0.cumul }).min(),
                               let maxC = cumulPoints.map({ $0.cumul }).max() {
                                Chart(cumulPoints, id: \.date) { p in
                                    LineMark(
                                        x: .value("Date", p.date),
                                        y: .value("Cumul des mouvements", p.cumul)
                                    )
                                    .interpolationMethod(.monotone)
                                    .foregroundStyle(.orange)
                                }
                                .chartYScale(domain: minC...maxC)
                                .chartYAxis {
                                    AxisMarks(position: .leading) { value in
                                        AxisGridLine()
                                        AxisTick()
                                        AxisValueLabel {
                                            if let v = value.as(Double.self) {
                                                Text("\(Int(v)) €")
                                            }
                                        }
                                    }
                                }
                                .frame(height: 250)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
            } label: {
                Label("Graphiques", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        .navigationTitle("\(support.nom ?? "Sans nom") (\(support.codeIsin ?? "-"))")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            historique = DatabaseManager.shared
                .getHistoriqueSupportPourAffaire(contratId: contratId, supportId: support.id)
                .sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }
        }
    }
    
    private func cumulMouvementsAffaire() -> [(date: Date, cumul: Double)] {
        var cumul: Double = 0
        var result: [(date: Date, cumul: Double)] = []
        
        let mouvements = DatabaseManager.shared.getMouvementsPourSupport(
            contratId: contratId,
            supportId: support.id
        )
        
        for m in mouvements {
            guard let d = m.date else { continue }
            cumul += m.mouvement
            result.append((date: d, cumul: cumul))
        }
        return result
    }
}
// Bloc visuel encadré avec un titre
@ViewBuilder
private func infoBlock(title: String, @ViewBuilder content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        Text(title)
            .font(.headline)
            .foregroundColor(.blue)
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

// Ligne simple avec valeur alignée à droite
@ViewBuilder
private func rowRight(label: String, value: String) -> some View {
    HStack {
        Text(label)
        Spacer()
        Text(value)
            .multilineTextAlignment(.trailing)
            .frame(alignment: .trailing)
    }
}

// Ligne avec icône et couleur conditionnelle
@ViewBuilder
private func rowRightIcon(label: String, value: String, color: Color, systemImage: String) -> some View {
    HStack {
        Text(label)
        Spacer()
        HStack(spacing: 4) {
            Text(value)
                .foregroundColor(color)
            Image(systemName: systemImage)
                .foregroundColor(color)
        }
        .frame(alignment: .trailing)
    }
}
