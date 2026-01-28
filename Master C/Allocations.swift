import SwiftUI
import Charts

// Normalisation d'une date String vers format "yyyy-MM-dd"

struct AllocationView: View {
    @State private var selectedAllocationNom: String = ""
    @State private var sicavSeries: [SicavPoint] = []

    private var nomsAllocations: [String] {
        DatabaseManager.shared.queryAllocationNoms()
    }

    private func loadSicavSeries() {
        guard !selectedAllocationNom.isEmpty else {
            sicavSeries = []
            return
        }
        let rows = DatabaseManager.shared.querySicavSeries(for: selectedAllocationNom)
        sicavSeries = rows.map { SicavPoint(date: $0.date, value: $0.sicav) }
        //print("📊 Séries récupérées pour \(selectedAllocationNom): \(sicavSeries)")
    }

    var body: some View {
        VStack(spacing: 16) {
            Picker("Sélectionnez une allocation", selection: $selectedAllocationNom) {
                ForEach(nomsAllocations, id: \.self) { nom in
                    Text(nom).tag(nom)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedAllocationNom) { _ in
  //              print("🔄 Allocation changée : \(selectedAllocationNom)")
                loadSicavSeries()
            }

            if !sicavSeries.isEmpty {
                let minY = sicavSeries.map { $0.value }.min() ?? 0
                let maxY = sicavSeries.map { $0.value }.max() ?? 0
                let range = maxY - minY
                let paddedMin = minY - range * 0.02
                let paddedMax = maxY + range * 0.02

                Chart(sicavSeries) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Sicav", point.value)
                    )
                }
                .frame(height: 200)
                .chartYScale(domain: paddedMin...paddedMax)
            } else {
                Text("Aucune donnée disponible")
                    .foregroundColor(.secondary)
            }
        }
        .onAppear {
            if selectedAllocationNom.isEmpty, let first = nomsAllocations.first {
                selectedAllocationNom = first
                loadSicavSeries()
            }
        }
    }
}


// MARK: - Modèle pour comparaison Client vs Allocation
struct SicavComparisonPoint: Identifiable {
    let id = UUID()
    let date: String    // ou Date si on convertit plus tard
    let value: Double
    let source: String  // "Client" ou nom de l’allocation
}
// Utilitaire pour aligner deux séries sur leurs dates communes
func alignSeries(
    clientSeries: [(String, Double)],
    allocationSeries: [(String, Double)],
    allocationName: String
) -> [SicavComparisonPoint] {
    // normalisation des dates
    let normClient = clientSeries.compactMap { (d, v) -> (String, Double)? in
        guard let norm = normalizeDateString(d) else { return nil }
        return (norm, v)
    }
    let normAlloc = allocationSeries.compactMap { (d, v) -> (String, Double)? in
        guard let norm = normalizeDateString(d) else { return nil }
        return (norm, v)
    }

    // dictionnaires
    let clientDict = Dictionary(uniqueKeysWithValues: normClient)
    let allocDict = Dictionary(uniqueKeysWithValues: normAlloc)

    // dates communes
    let commonDates = Set(clientDict.keys).intersection(allocDict.keys).sorted()

    guard
        let baseClient = commonDates.compactMap({ clientDict[$0] }).first,
        let baseAlloc = commonDates.compactMap({ allocDict[$0] }).first
    else { return [] }

    // génération des points
    var points: [SicavComparisonPoint] = []
    for d in commonDates {
        if let vC = clientDict[d] {
            let scaled = vC / baseClient * 100
            points.append(SicavComparisonPoint(date: d, value: scaled, source: "Client"))
        }
        if let vA = allocDict[d] {
            let scaled = vA / baseAlloc * 100
            points.append(SicavComparisonPoint(date: d, value: scaled, source: allocationName))
        }
    }
    return points
}
