import SwiftUI
import Charts

struct RisqueItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let systemImage: String
    let color: Color
}

struct RiskCombined: Identifiable {
    let id = UUID()
    let categorie: String
    let type: String
    let valeur: Double
}
struct SicavPoint: Identifiable {
    let id = UUID()
    let date: String
    let value: Double
}

// === Vue principale ===


struct DashboardView: View {
    @State private var selectedDate: Date = Date()
    @State private var volumetrieDataCount: [DistributionItem] = []
    @State private var volumetrieDataAmount: [DistributionItem] = []
    @State private var volumetrieMode: Int = 0
    @State private var lastAvailableDate: Date? = nil
    @State private var expandedSection: String? = nil
    @State private var risqueStats: RisqueStats? = nil
    @State private var snapshot: PortfolioSnapshot?
    @State private var totalStats: TotalStats? = nil
    @State private var globalSupports: [SyntheseSupportClient] = []
    @State private var globalDistType: Int = 0
    @State private var globalDistMode: Int = 0
    @State private var globalDistData: [DistributionItem] = []
    @State private var documentStats: [DocumentStats] = []

    private func formattedValue(_ val: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: val)) ?? "\(Int(val))"
    }
    
    private func risqueIcon(categorie: String) -> (String, Color) {
        switch categorie {
        case "Sous le niveau": return ("snowflake", .blue)
        case "Dans le niveau": return ("hands.sparkles.fill", .green)
        case "Au-dessus du niveau": return ("flame.fill", .red)
        case "SRRI actuel manquant": return ("exclamationmark.triangle.fill", .orange)
        default: return ("questionmark", .gray)
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 0).id("top") // ancre

                    // Sélecteur de date
                    if let maxDate = lastAvailableDate {
                        DatePicker("Date de référence", selection: $selectedDate, in: ...maxDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    } else {
                        DatePicker("Date de référence", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Snapshot
                    if let snap = snapshot {
                        SnapshotView(snap: snap, stats: totalStats)
                    }
                    
                    // Volumétrie
                    DashboardSection(title: "📊 Volumétrie", expandedSection: $expandedSection) {
                        VolumetrieCombinedView(
                            data: DatabaseManager.shared.getVolumetrieCombined(aLaDate: selectedDate.fridayOfWeek())
                        )
                    }
                    
                    // Supports
                    DashboardSection(title: "📊 Supports financiers (Global)", expandedSection: $expandedSection) {
                        VStack(spacing: 16) {
                            if globalSupports.isEmpty {
                                Text("Aucune donnée disponible.").foregroundColor(.secondary)
                            } else {
                                SupportsTableView(supports: globalSupports)
                            }
                            Divider()
                            SupportsDistributionView(
                                distType: $globalDistType,
                                distMode: $globalDistMode,
                                distData: $globalDistData,
                                lastAvailableDate: lastAvailableDate,
                                selectedDate: selectedDate
                            )
                        }
                    }
                    
                    // Risque
                    DashboardSection(title: "⚖️ Gestion du risque", expandedSection: $expandedSection) {
                        RiskSectionView(stats: risqueStats, format: formattedValue, iconProvider: risqueIcon)
                    }
                    
                    // Documents
                    DashboardSection(title: "📄 Documents", expandedSection: $expandedSection) {
                        let obso = documentStats.filter { $0.statut == "Obsolète" }
                        let nonObso = documentStats.filter { $0.statut == "Non obsolète" }
                        
                        RadarChart(obsoletes: obso, nonObsoletes: nonObso)
                            .frame(height: 400)
                    }
                    
                    // Allocations cibles
                    DashboardSection(title: "🎯 Allocations cibles", expandedSection: $expandedSection) {
                        AllocationView()
                    }
                    
                    // Rémunération
                    DashboardSection(title: "💶 Rémunérations", expandedSection: $expandedSection) {
                        RemunerationsGlobaleView()
                    }
                }
                .padding()
            }
            .navigationTitle("Tableau de bord")
            .onAppear {
                loadData(for: selectedDate)
                proxy.scrollTo("top", anchor: .top)
            }
            .onChange(of: selectedDate) { newDate in
                loadData(for: newDate)
                proxy.scrollTo("top", anchor: .top)
            }
        }
    }
    
    private func loadData(for date: Date) {
        lastAvailableDate = DatabaseManager.shared.getLastAvailableDate()
        let vendredi = date.fridayOfWeek()
        
        volumetrieDataCount = DatabaseManager.shared.getVolumetrieClientsCount(aLaDate: vendredi)
        volumetrieDataAmount = DatabaseManager.shared.getVolumetrieClientsAmount(aLaDate: vendredi)
        documentStats = DatabaseManager.shared.getDocumentsStats()
        
        let stats = DatabaseManager.shared.fetchRiskStats()
        risqueStats = RisqueStats(
            sous: (stats["Risque réduit"]?.clients ?? 0, stats["Risque réduit"]?.montant ?? 0),
            aNiveau: (stats["Risque identique"]?.clients ?? 0, stats["Risque identique"]?.montant ?? 0),
            auDessus: (stats["Risque augmenté"]?.clients ?? 0, stats["Risque augmenté"]?.montant ?? 0),
            manquant: (stats["SRRI actuel manquant"]?.clients ?? 0, stats["SRRI actuel manquant"]?.montant ?? 0)
        )
        
        snapshot = DatabaseManager.shared.getSnapshot(at: vendredi)
        totalStats = DatabaseManager.shared.getTotalStats(aLaDate: vendredi)
        
        if let maxDate = lastAvailableDate {
            let refDate = min(date, maxDate)
            let refDateStr = sqlDateFormatter.string(from: refDate)
            globalSupports = DatabaseManager.shared.getSyntheseSupportsGlobal(aLaDate: refDateStr)
            globalDistData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "cat_gene")
        }
    }
}



// === Vue Snapshot ===
struct SnapshotView: View {
    let snap: PortfolioSnapshot
    let stats: TotalStats?
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack { Text("Valorisation totale :"); Spacer(); Text("\(formattedInt(snap.totalValo)) €").bold() }
            HStack { Text("Mouvements cumulés :"); Spacer(); Text("\(formattedInt(snap.mouvementsCumules)) €").bold() }
            HStack { Text("Perf 52s :"); Spacer(); if let perf = snap.perf52s { Text(String(format: "%.2f %%", perf * 100)).bold() } else { Text("-") } }
            HStack { Text("Volatilité :"); Spacer(); if let vol = snap.volat { Text(String(format: "%.2f %%", vol * 100)).bold() } else { Text("-") } }
            
            if let stats = stats {
                Divider().padding(.vertical, 4)
                HStack { Text("Total clients :"); Spacer(); Text("\(stats.totalClients)").bold().foregroundColor(.blue) }
                HStack { Text("Total affaires :"); Spacer(); Text("\(stats.totalAffaires)").bold().foregroundColor(.green) }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// === Vue Risque principale ===
struct RiskSectionView: View {
    let stats: RisqueStats?
    let format: (Double) -> String
    let iconProvider: (String) -> (String, Color)
    
    var body: some View {
        if let rs = stats {
            VStack(alignment: .leading, spacing: 12) {
                RiskTotalsView(stats: rs)
                
                RiskChartView(
                    combined: RiskSectionView.makeCombined(rs),
                    format: format,
                    iconProvider: iconProvider
                )
            }
        } else {
            Text("Aucune donnée disponible.").foregroundColor(.secondary)
        }
    }
    
    private static func makeCombined(_ rs: RisqueStats) -> [RiskCombined] {
        [
            RiskCombined(categorie: "Sous le niveau", type: "Montant (€)", valeur: rs.sous.montant),
            RiskCombined(categorie: "Sous le niveau", type: "Clients", valeur: Double(rs.sous.clients)),
            RiskCombined(categorie: "Dans le niveau", type: "Montant (€)", valeur: rs.aNiveau.montant),
            RiskCombined(categorie: "Dans le niveau", type: "Clients", valeur: Double(rs.aNiveau.clients)),
            RiskCombined(categorie: "Au-dessus du niveau", type: "Montant (€)", valeur: rs.auDessus.montant),
            RiskCombined(categorie: "Au-dessus du niveau", type: "Clients", valeur: Double(rs.auDessus.clients)),
            RiskCombined(categorie: "SRRI actuel manquant", type: "Montant (€)", valeur: rs.manquant.montant),
            RiskCombined(categorie: "SRRI actuel manquant", type: "Clients", valeur: Double(rs.manquant.clients))
        ]
    }
}

// === Totaux textuels ===
struct RiskTotalsView: View {
    let stats: RisqueStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text("🔥 Au-dessus du niveau"); Spacer(); Text("\(stats.auDessus.clients)") }
            HStack { Text("🙌 Dans le niveau"); Spacer(); Text("\(stats.aNiveau.clients)") }
            HStack { Text("❄️ Sous le niveau"); Spacer(); Text("\(stats.sous.clients)") }
            HStack { Text("⚠️ SRRI manquant"); Spacer(); Text("\(stats.manquant.clients)") }
        }
        .padding(.bottom, 8)
    }
}

// === Vue Chart Risque ===
struct RiskChartView: View {
    let combined: [RiskCombined]
    let format: (Double) -> String
    let iconProvider: (String) -> (String, Color)
    
    var body: some View {
        Chart(combined, id: \.id) { item in
            BarMark(
                x: .value("Valeur", item.valeur),
                y: .value("Catégorie", item.categorie)
            )
            .foregroundStyle(by: .value("Type", item.type))
            .position(by: .value("Type", item.type))
            .annotation(position: .trailing) {
                if item.type == "Montant (€)" {
                    Text("\(format(item.valeur)) €")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(Int(item.valeur)) clients")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let cat = value.as(String.self) {
                    let iconInfo = iconProvider(cat)
                    AxisValueLabel {
                        HStack {
                            Image(systemName: iconInfo.0)
                                .foregroundColor(iconInfo.1)
                            Text(cat)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .frame(height: 400)
        .padding(.vertical)
        .chartLegend(position: .bottom, alignment: .center)
    }
}

// === Vue Volumétrie ===
struct VolumetrieSectionView: View {
    @Binding var dataCount: [DistributionItem]
    @Binding var dataAmount: [DistributionItem]
    @Binding var mode: Int
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("📈 Nombre de clients par tranche").font(.headline)
                Picker("Affichage", selection: $mode) {
                    Text("Barres").tag(0)
                    Text("Secteurs").tag(1)
                }.pickerStyle(.segmented).padding(.bottom, 8)
                if dataCount.isEmpty {
                    Text("Aucune donnée disponible.").foregroundColor(.secondary)
                } else {
                    if mode == 0 { DistributionBarChart(items: dataCount) }
                    else { DistributionPieChart(items: dataCount) }
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("💰 Montants totaux par tranche (€)").font(.headline)
                if dataAmount.isEmpty {
                    Text("Aucune donnée disponible.").foregroundColor(.secondary)
                } else {
                    if mode == 0 { DistributionBarChart(items: dataAmount) }
                    else { DistributionPieChart(items: dataAmount) }
                }
            }
        }
    }
}

// === Vue Distribution Supports ===
// === Vue Distribution Supports (version corrigée) ===
struct SupportsDistributionView: View {
    @Binding var distType: Int
    @Binding var distMode: Int
    @Binding var distData: [DistributionItem]
    let lastAvailableDate: Date?
    let selectedDate: Date
    
    var body: some View {
        VStack(spacing: 12) {
            Picker("Dimension", selection: $distType) {
                Text("Cat. générale").tag(0)
                Text("Cat. principale").tag(1)
                Text("Cat. détaillée").tag(2)
                Text("Géographie").tag(3)
                Text("Promoteur").tag(4)
                Text("SRRI").tag(5)
            }
            .pickerStyle(.menu)
            .onChange(of: distType) { newValue in
                updateDistribution(for: newValue)
            }
            
            Picker("Affichage", selection: $distMode) {
                Text("Barres").tag(0)
                Text("Secteurs").tag(1)
            }.pickerStyle(.segmented)
            
            if distData.isEmpty {
                Text("Aucune donnée pour cette dimension.").foregroundColor(.secondary)
            } else {
                let total = distData.map { $0.value }.reduce(0, +)
                let percentData = distData.map { item in
                    DistributionItem(label: item.label, value: total > 0 ? (item.value / total * 100.0) : 0)
                }.sorted { $0.value > $1.value }
                
                if distMode == 0 {
                    DistributionBarChart(items: Array(percentData.prefix(10)), isPercentage: true)
                } else {
                    DistributionPieChart(items: Array(percentData.prefix(10)), isPercentage: true)
                }
                
                if percentData.count > 10 {
                    let remainingPercent = percentData.dropFirst(10).map { $0.value }.reduce(0, +)
                    if remainingPercent > 0.01 {
                        Text("Autres (\(percentData.count - 10) éléments): \(String(format: "%.1f", remainingPercent))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .onAppear {
            updateDistribution(for: distType)
        }
        // Ajout de ce onChange pour réagir aux changements de date
        .onChange(of: selectedDate) { _ in
            updateDistribution(for: distType)
        }
    }
    
    private func updateDistribution(for type: Int) {
        guard let maxDate = lastAvailableDate else { return }
        let refDate = min(selectedDate, maxDate)
        let refDateStr = sqlDateFormatter.string(from: refDate)
        
        // Mise à jour directe du binding avec DispatchQueue pour s'assurer que l'UI se rafraîchit
        DispatchQueue.main.async {
            switch type {
            case 0:
                distData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "cat_gene")
            case 1:
                distData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "cat_principale")
            case 2:
                distData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "cat_det")
            case 3:
                distData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "cat_geo")
            case 4:
                distData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "promoteur")
            case 5:
                distData = DatabaseManager.shared.getDistributionSupportsGlobal(aLaDate: refDateStr, key: "SRRI")
            default:
                break
            }
        }
    }
}

// === Vue Tableau Supports ===
// === Vue Tableau Supports ===
struct SupportsTableView: View {
    let supports: [SyntheseSupportClient]
    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: 6) {
                headerRow
                Divider()
                ForEach(supports.prefix(10)) { sup in
                    SupportRow(sup: sup)
                }
            }.padding()
        }
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
    
    private var headerRow: some View {
        HStack {
            Text("ISIN").font(.caption).frame(width: 103, alignment: .leading)
            Text("Nom").font(.caption).frame(width: 200, alignment: .leading)
            Text("Nb UC").font(.caption).frame(width: 100, alignment: .trailing)
            Text("Valo (€)").font(.caption).frame(width: 120, alignment: .trailing)
            Text("PRMP").font(.caption).frame(width: 100, alignment: .trailing)
            Text("SRRI").font(.caption).frame(width: 60, alignment: .trailing)   // 👈 ajout SRRI
            Text("E").font(.caption).frame(width: 40, alignment: .trailing)
            Text("S").font(.caption).frame(width: 40, alignment: .trailing)
            Text("G").font(.caption).frame(width: 40, alignment: .trailing)
        }
        .foregroundColor(.secondary)
    }
}

struct SupportRow: View {
    let sup: SyntheseSupportClient
    
    private func formatNote(_ noteString: String?) -> String {
        guard var str = noteString else { return "-" }
        str = str.replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let noteValue = Double(str) { return String(format: "%.1f", noteValue) }
        return str
    }
    
    var body: some View {
        HStack {
            Text(sup.codeIsin ?? "-").frame(width: 103, alignment: .leading)
            Text(String((sup.nom ?? "(sans nom)").prefix(25))).frame(width: 200, alignment: .leading)
            Text("\(sup.totalNbUC, specifier: "%.2f")").frame(width: 100, alignment: .trailing)
            Text("\(formattedInt(sup.totalValo))").frame(width: 120, alignment: .trailing)
            
            let vl = sup.totalNbUC > 0 ? sup.totalValo / sup.totalNbUC : 0
            Text("\(sup.prmpMoyen, specifier: "%.3f")")
                .frame(width: 100, alignment: .trailing)
                .foregroundColor(sup.prmpMoyen < vl ? .green : .red)
            
            // 👇 affichage SRRI
            if let srri = sup.srri {
                Text("\(srri)").frame(width: 60, alignment: .trailing)
            } else {
                Text("-").frame(width: 60, alignment: .trailing)
            }
            
            Text(formatNote(sup.noteE)).frame(width: 40, alignment: .trailing)
            Text(formatNote(sup.noteS)).frame(width: 40, alignment: .trailing)
            Text(formatNote(sup.noteG)).frame(width: 40, alignment: .trailing)
        }
        .font(.caption)
    }
}


struct DashboardSection<Content: View>: View {
    let title: String
    let content: () -> Content
    @Binding var expandedSection: String?
    
    init(title: String, expandedSection: Binding<String?>, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self._expandedSection = expandedSection
        self.content = content
    }
    
    var body: some View {
        let isExpanded = expandedSection == title
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title).font(.title3).fontWeight(.bold)
                Spacer()
                ScrollViewReader { proxy in
                    Button(action: {
                        withAnimation {
                            expandedSection = isExpanded ? nil : title
                            if !isExpanded {
                                DispatchQueue.main.async {
                                    proxy.scrollTo(title, anchor: .top)
                                }
                            }
                        }
                    }) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            if isExpanded { content() }
        }
        .id(title) // identifiant pour ScrollViewReader
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}


#Preview {
    NavigationView { DashboardView() }
}
struct DocumentStats: Identifiable {
    let id = UUID()
    let type: String
    let statut: String   // "Obsolète" ou "Non obsolète"
    let valeur: Int
}

// === Vue Section Documents ===
struct DocumentsSectionView: View {
    let data: [DocumentStats]
    
    var body: some View {
        let obso = data.filter { $0.statut == "Obsolète" }
        let nonObso = data.filter { $0.statut == "Non obsolète" }
        
        
        VStack(alignment: .leading, spacing: 12) {
            if data.isEmpty {
                Text("Aucune donnée disponible.").foregroundColor(.secondary)
            } else {
                RadarChart(obsoletes: obso, nonObsoletes: nonObso)
                    .frame(height: 400)
                    .frame(height: 400)
                    .padding(.vertical)
            }
        }
    }
}

// === Radar Chart ===
struct RadarChart: View {
    let obsoletes: [DocumentStats]
    let nonObsoletes: [DocumentStats]
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height) - 80
            let center = CGPoint(x: geo.size.width/2, y: geo.size.height/2)
            
            // Regroupe par type pour cumuler les valeurs
            let groupedObso = Dictionary(grouping: obsoletes, by: { $0.type })
                .map { DocumentStats(type: $0.key, statut: "Obsolète", valeur: $0.value.map{$0.valeur}.reduce(0,+)) }
            
            let groupedNonObso = Dictionary(grouping: nonObsoletes, by: { $0.type })
                .map { DocumentStats(type: $0.key, statut: "Non obsolète", valeur: $0.value.map{$0.valeur}.reduce(0,+)) }
            
            // Types (axes du radar)
            let labels = Array(Set((groupedObso + groupedNonObso).map { $0.type })).sorted()
            let allValues = (groupedObso + groupedNonObso).map { $0.valeur }
            let maxValue = Double(allValues.max() ?? 1)
            
            VStack {
                ZStack {
                    // Axes
                    ForEach(0..<labels.count, id: \.self) { i in
                        let end = axisEndPoint(index: i, count: labels.count, size: size, center: center)
                        Path { path in
                            path.move(to: center)
                            path.addLine(to: end)
                        }
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    }
                    
                    // Polygone Obsolètes
                    RadarPolygon(values: groupedObso, size: size, center: center, maxValue: maxValue, color: .red)
                    
                    // Polygone Non obsolètes
                    RadarPolygon(values: groupedNonObso, size: size, center: center, maxValue: maxValue, color: .blue)
                    
                    // Labels
                    RadarLabels(types: labels, size: size + 60, center: center) // 👈 augmenté à +60
                }
                
                // Légende avec compteurs
                HStack(spacing: 20) {
                    Label("Obsolètes (\(groupedObso.map{$0.valeur}.reduce(0,+)))", systemImage: "square.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Label("Non obsolètes (\(groupedNonObso.map{$0.valeur}.reduce(0,+)))", systemImage: "square.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                }
                .padding(.top, 12)
            }
        }
    }
}


struct AllocationsCiblesView: View {
    @State private var selectedNom: String? = nil
    
    private var nomsAllocations: [String] {
        DatabaseManager.shared.queryAllocationNoms()
            .filter { !$0.isEmpty }
            .removingDuplicates()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Allocations cibles")
                .font(.headline)
            
            Picker("Sélectionnez une allocation", selection: $selectedNom) {
                ForEach(nomsAllocations, id: \.self) { nom in
                    Text(nom).tag(Optional(nom))
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
        .padding()
    }
}


extension Array where Element: Hashable & Comparable {
    func removingDuplicates() -> [Element] {
        Array(Set(self)).sorted()
    }
}


// --- Sous-vues (découpées pour simplifier le compilateur) ---

struct RadarAxes: View {
    let count: Int
    let size: CGFloat
    let center: CGPoint
    
    var body: some View {
        ForEach(0..<count, id: \.self) { i in
            let angle = Double(i) * 2 * .pi / Double(count) - .pi/2
            let end = CGPoint(x: center.x + cos(angle) * size/2,
                              y: center.y + sin(angle) * size/2)
            Path { path in
                path.move(to: center)
                path.addLine(to: end)
            }
            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }
}

// --- Helpers purs Swift ---
import CoreGraphics

func radarPoint(index: Int, count: Int, value: Double, maxValue: Double, size: CGFloat, center: CGPoint) -> CGPoint {
    let angle = Double(index) * 2 * .pi / Double(count) - .pi/2
    let radius = CGFloat(value / maxValue) * size/2
    let x = center.x + CGFloat(cos(angle)) * radius
    let y = center.y + CGFloat(sin(angle)) * radius
    return CGPoint(x: x, y: y)
}

func axisEndPoint(index: Int, count: Int, size: CGFloat, center: CGPoint) -> CGPoint {
    let angle = Double(index) * 2 * .pi / Double(count) - .pi/2
    let x = center.x + CGFloat(cos(angle)) * size/2
    let y = center.y + CGFloat(sin(angle)) * size/2
    return CGPoint(x: x, y: y)
}


// --- RadarPolygon réduit ---
struct RadarPolygon: View {
    let values: [DocumentStats]
    let size: CGFloat
    let center: CGPoint
    let maxValue: Double
    let color: Color
    
    var body: some View {
        let count = values.count
        Path { path in
            for (i, item) in values.enumerated() {
                let point = radarPoint(index: i, count: count, value: Double(item.valeur), maxValue: maxValue, size: size, center: center)
                if i == 0 { path.move(to: point) }
                else { path.addLine(to: point) }
            }
            path.closeSubpath()
        }
        .fill(color.opacity(0.3))
        .overlay(
            Path { path in
                for (i, item) in values.enumerated() {
                    let point = radarPoint(index: i, count: count, value: Double(item.valeur), maxValue: maxValue, size: size, center: center)
                    if i == 0 { path.move(to: point) }
                    else { path.addLine(to: point) }
                }
                path.closeSubpath()
            }
                .stroke(color, lineWidth: 2)
        )
    }
}

// --- RadarLabels réduit ---
struct RadarLabels: View {
    let types: [String]
    let size: CGFloat
    let center: CGPoint
    
    var body: some View {
        let count = types.count
        ForEach(Array(types.enumerated()), id: \.offset) { i, type in
            let point = axisEndPoint(index: i, count: count, size: size + 40, center: center)
            Text(type)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .position(point)
        }
    }
}


struct VolumetrieCombinedView: View {
    let data: [VolumetrieSerie]
    
    private let tranches = ["<100k", "100–250k", "250–500k", "500k–1M", "1M–5M", ">5M"]
    
    var body: some View {
        let maxEncours = data
            .filter { $0.type == "Encours" }
            .map { $0.valeur }
            .max() ?? 1
        
        VStack(alignment: .leading, spacing: 12) {
            ForEach(tranches, id: \.self) { tranche in
                let nbClients = data.first(where: { $0.tranche == tranche && $0.type == "Clients" })?.valeur ?? 0
                let encours = data.first(where: { $0.tranche == tranche && $0.type == "Encours" })?.valeur ?? 0
                
                if nbClients > 0 || encours > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(tranche)
                                .font(.subheadline)
                            Spacer()
                            Text(formatMontant(encours))
                                .font(.subheadline)
                        }
                        
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 10)
                                    .cornerRadius(5)
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(
                                        width: CGFloat(encours / maxEncours) * geo.size.width,
                                        height: 10
                                    )
                                    .cornerRadius(5)
                            }
                        }
                        .frame(height: 10)
                        
                        Text("\(Int(nbClients)) clients")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.vertical)
    }
    
    private func formatMontant(_ val: Double) -> String {
        if val >= 1_000_000 {
            return String(format: "%.1f M€", val / 1_000_000)
        } else if val >= 1_000 {
            return String(format: "%.0f k€", val / 1_000)
        } else {
            return "\(Int(val)) €"
        }
    }
}



