import SwiftUI
import Charts

struct RemunerationsGlobaleView: View {
    @State private var data: [RemunerationGlobale] = []
    @State private var showChart = false
    
    private func formatValue(_ val: Double, unitMillions: Bool = false, digits: Int = 0) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = digits
        f.minimumFractionDigits = digits
        f.groupingSeparator = " "
        let value = unitMillions ? (val / 1_000_000.0) : val
        return f.string(from: NSNumber(value: value)) ?? "0"
    }
    
    // Modèle pour le graphique
    struct ChartItem: Identifiable {
        let id = UUID()
        let annee: String
        let type: String
        let valeur: Double
    }
    
    private var chartData: [ChartItem] {
        var result: [ChartItem] = []
        for row in data {
            result.append(ChartItem(annee: row.annee, type: "Rétro", valeur: row.retrocession))
            result.append(ChartItem(annee: row.annee, type: "AssVie", valeur: row.assuranceVie))
        }
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Synthèse des rémunérations")
                    .font(.title2).bold()
                Spacer()
                Toggle("Graphique", isOn: $showChart)
                    .labelsHidden()
            }
            .padding(.bottom, 8)
            
            if data.isEmpty {
                Text("Aucune donnée disponible.").foregroundColor(.secondary)
            } else {
                if showChart {
                    // === Graphique barres empilées ===
                    Chart(chartData) { item in
                        BarMark(
                            x: .value("Année", item.annee),
                            y: .value("Montant", item.valeur)
                        )
                        .foregroundStyle(by: .value("Type", item.type))
                    }
                    // Axe X : toutes les années si <= 5, sinon 1 sur 2
                    .chartXAxis {
                        if data.count <= 5 {
                            AxisMarks(preset: .aligned)
                        } else {
                            AxisMarks(values: data.enumerated().compactMap { idx, row in
                                idx.isMultiple(of: 2) ? row.annee : nil
                            })
                        }
                    }
                    .frame(height: 400)
                } else {
                    // === Tableau scrollable ===
                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            // En-tête
                            HStack {
                                Text("Année").bold().frame(width: 60, alignment: .leading)
                                Text("Encours (M€)").bold().frame(width: 100, alignment: .trailing)
                                Text("Rétro (€)").bold().frame(width: 100, alignment: .trailing)
                                Text("AssVie (€)").bold().frame(width: 100, alignment: .trailing)
                                Text("Total (€)").bold().frame(width: 120, alignment: .trailing)
                            }
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.15))
                            
                            Divider()
                            
                            // Lignes
                            ForEach(data) { row in
                                HStack {
                                    Text(row.annee).frame(width: 60, alignment: .leading)
                                    Text(formatValue(row.encoursMoyen, unitMillions: true, digits: 2))
                                        .frame(width: 100, alignment: .trailing)
                                    Text(formatValue(row.retrocession, digits: 0))
                                        .frame(width: 100, alignment: .trailing)
                                    Text(formatValue(row.assuranceVie, digits: 0))
                                        .frame(width: 100, alignment: .trailing)
                                    Text(formatValue(row.total, digits: 0))
                                        .frame(width: 120, alignment: .trailing)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .onAppear {
            print("▶️ Chargement des rémunérations…")
            data = DatabaseManager.shared.getRemunerationsGlobaleParAnnee()
            print("📊 Lignes reçues = \(data.count)")
        }
    }
}




