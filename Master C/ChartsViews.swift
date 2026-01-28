//
//  Charts.swift
//  Master C
//
//  Created by Michel Camilleri on 15/08/2025.
//

import SwiftUI
import Charts

// MARK: - Graphique annuel valorisation
public struct AnnualValoChart: View {
    public let data: [(annee: Int, valeur: Double)]
    
    private var minYear: Int { data.map { $0.annee }.min() ?? 0 }
    private var maxYear: Int { data.map { $0.annee }.max() ?? 0 }
    private var minY: Double { (data.map { $0.valeur }.min() ?? 0) * 0.95 }
    private var maxY: Double { (data.map { $0.valeur }.max() ?? 0) * 1.05 }
    
    public init(data: [(annee: Int, valeur: Double)]) {
        self.data = data
    }
    
    public var body: some View {
        Chart {
            ForEach(data, id: \.annee) { item in
                LineMark(
                    x: .value("Année", item.annee),
                    y: .value("Valorisation", item.valeur)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: Double(minYear)...Double(maxYear))
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding(.vertical)
    }
}

// MARK: - Graphique annuel mouvements
public struct AnnualMouvementsChart: View {
    public let data: [(annee: Int, cumulMouvements: Double)]
    
    private var minYear: Int { data.map { $0.annee }.min() ?? 0 }
    private var maxYear: Int { data.map { $0.annee }.max() ?? 0 }
    private var minY: Double { (data.map { $0.cumulMouvements }.min() ?? 0) * 0.95 }
    private var maxY: Double { (data.map { $0.cumulMouvements }.max() ?? 0) * 1.05 }
    
    public init(data: [(annee: Int, cumulMouvements: Double)]) {
        self.data = data
    }
    
    public var body: some View {
        Chart {
            ForEach(data, id: \.annee) { item in
                LineMark(
                    x: .value("Année", item.annee),
                    y: .value("Cumul mouvements", item.cumulMouvements)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: Double(minYear)...Double(maxYear))
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding(.vertical)
    }
}

// MARK: - Graphique annuel Performance vs Volatilité
public struct AnnualPerfVolChart: View {
    public struct PerfVolData: Identifiable {
        public let id = UUID()
        let annee: String
        let type: String
        let valeur: Double
    }
    
    private var chartData: [PerfVolData]
    private var years: [String]
    private var maxVal: Double
    
    public init(data: [(annee: Int, perf: Double, volat: Double)]) {
        var temp: [PerfVolData] = []
        for entry in data {
            let yearString = "\(entry.annee)"
            temp.append(PerfVolData(annee: yearString, type: "Performance", valeur: entry.perf))
            temp.append(PerfVolData(annee: yearString, type: "Volatilité", valeur: entry.volat))
        }
        self.chartData = temp
        self.years = Array(Set(temp.map { $0.annee })).sorted()
        self.maxVal = (temp.map { abs($0.valeur) }.max() ?? 0) * 1.1
    }
    
    private var filteredYears: [String] {
        let totalYears = years.count
        let step: Int
        if totalYears <= 10 {
            step = 1
        } else if totalYears <= 20 {
            step = 2
        } else {
            step = max(1, totalYears / 10)
        }
        return years.enumerated().compactMap { index, year in
            index % step == 0 ? year : nil
        }
    }
    
    public var body: some View {
        Chart {
            ForEach(chartData) { item in
                BarMark(
                    x: .value("Année", item.annee),
                    y: .value("Valeur (%)", item.valeur)
                )
                .foregroundStyle(by: .value("Type", item.type))
                .position(by: .value("Type", item.type))
            }
        }
        .chartXScale(domain: years)
        .chartYScale(domain: -maxVal...maxVal)
        .chartXAxis {
            AxisMarks(values: filteredYears) { value in
                if let yearString = value.as(String.self) {
                    AxisValueLabel {
                        Text(yearString)
                            .font(.caption)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let doubleValue = value.as(Double.self) {
                    AxisValueLabel {
                        Text("\(doubleValue * 100, specifier: "%.1f") %")
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical)
        .chartLegend(position: .bottom, alignment: .center)
    }
}

// MARK: - Graphique annuel combiné valorisation + mouvements
public struct AnnualCombinedChart: View {
    public struct CombinedData: Identifiable {
        public let id = UUID()
        let annee: Int
        let type: String
        let valeur: Double
    }
    
    private var chartData: [CombinedData]
    private var minYear: Int
    private var maxYear: Int
    private var minY: Double
    private var maxY: Double
    
    public init(valoData: [(annee: Int, valeur: Double)],
                mouvData: [(annee: Int, cumulMouvements: Double)]) {
        var temp: [CombinedData] = []
        for entry in valoData {
            temp.append(CombinedData(annee: entry.annee, type: "Valorisation", valeur: entry.valeur))
        }
        for entry in mouvData {
            temp.append(CombinedData(annee: entry.annee, type: "Cumul mouvements", valeur: entry.cumulMouvements))
        }
        self.chartData = temp
        let allYears = temp.map { $0.annee }
        self.minYear = allYears.min() ?? 0
        self.maxYear = allYears.max() ?? 0
        let allValues = temp.map { $0.valeur }
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 0
        self.minY = minValue * 0.95
        self.maxY = maxValue * 1.05
    }
    
    public var body: some View {
        Chart {
            ForEach(chartData) { item in
                LineMark(
                    x: .value("Année", item.annee),
                    y: .value("Valeur", item.valeur)
                )
                .foregroundStyle(by: .value("Type", item.type))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
                .symbol(by: .value("Type", item.type))
            }
        }
        .chartXScale(domain: Double(minYear)...Double(maxYear))
        .chartYScale(domain: minY...maxY)
        .chartForegroundStyleScale([
            "Valorisation": .orange,
            "Cumul mouvements": .blue
        ])
        .frame(height: 200)
        .padding(.vertical)
        .chartLegend(position: .bottom, alignment: .center)
    }
}

// MARK: - Graphique mensuel valorisation
public struct MonthlyValoChart: View {
    public let data: [(date: Date, valeur: Double)]
    
    private var minDate: Date { data.map { $0.date }.min() ?? Date() }
    private var maxDate: Date { data.map { $0.date }.max() ?? Date() }
    private var minY: Double { (data.map { $0.valeur }.min() ?? 0) * 0.95 }
    private var maxY: Double { (data.map { $0.valeur }.max() ?? 0) * 1.05 }
    
    public init(data: [(date: Date, valeur: Double)]) {
        self.data = data
    }
    
    public var body: some View {
        Chart {
            ForEach(data, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Valorisation", item.valeur)
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: minDate...maxDate)
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding(.vertical)
        
    }
}

// MARK: - Graphique mensuel mouvements
public struct MonthlyMouvementsChart: View {
    public let data: [(date: Date, cumulMouvements: Double)]
    
    private var minDate: Date { data.map { $0.date }.min() ?? Date() }
    private var maxDate: Date { data.map { $0.date }.max() ?? Date() }
    private var minY: Double { (data.map { $0.cumulMouvements }.min() ?? 0) * 0.95 }
    private var maxY: Double { (data.map { $0.cumulMouvements }.max() ?? 0) * 1.05 }
    
    public init(data: [(date: Date, cumulMouvements: Double)]) {
        self.data = data
    }
    
    public var body: some View {
        Chart {
            ForEach(data, id: \.date) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Cumul mouvements", item.cumulMouvements)
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: minDate...maxDate)
        .chartYScale(domain: minY...maxY)
        .frame(height: 200)
        .padding(.vertical)
        
    }
}

public struct MonthlyCombinedChart: View {
    public struct CombinedData: Identifiable {
        public let id = UUID()
        let date: Date
        let type: String
        let valeur: Double
    }
    
    private var chartData: [CombinedData]
    private var minDate: Date
    private var maxDate: Date
    private var minY: Double
    private var maxY: Double
    
    public init(valoData: [(date: Date, valeur: Double)],
                mouvData: [(date: Date, cumulMouvements: Double)]) {
        var temp: [CombinedData] = []
        
        for entry in valoData {
            temp.append(CombinedData(date: entry.date,
                                     type: "Valorisation",
                                     valeur: entry.valeur))
        }
        
        for entry in mouvData {
            temp.append(CombinedData(date: entry.date,
                                     type: "Cumul mouvements",
                                     valeur: entry.cumulMouvements))
        }
        
        self.chartData = temp
        
        let allDates = temp.map { $0.date }
        self.minDate = allDates.min() ?? Date()
        self.maxDate = allDates.max() ?? Date()
        
        let allValues = temp.map { $0.valeur }
        let minValue = allValues.min() ?? 0
        let maxValue = allValues.max() ?? 0
        self.minY = minValue * 0.95
        self.maxY = maxValue * 1.05
    }
    
    public var body: some View {
        Chart {
            ForEach(chartData) { item in
                LineMark(
                    x: .value("Date", item.date),
                    y: .value("Valeur", item.valeur)
                )
                .foregroundStyle(by: .value("Type", item.type))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.monotone)
            }
        }
        .chartXScale(domain: minDate...maxDate)
        .chartYScale(domain: minY...maxY)
        .chartForegroundStyleScale([
            "Valorisation": .orange,
            "Cumul mouvements": .blue
        ])
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 6)) { value in
                if let dateValue = value.as(Date.self) {
                    AxisValueLabel {
                        Text(dateValue, format: .dateTime.month(.abbreviated).year())
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical)
        .chartLegend(position: .bottom, alignment: .center)
    }
}
// MARK: - Répartitions (Bar/Pie)
private func formattedValue(_ val: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.groupingSeparator = " "   // espace comme séparateur
    return formatter.string(from: NSNumber(value: val)) ?? "\(Int(val))"
}

struct DistributionBarChart: View {
    let items: [DistributionItem]
    let isPercentage: Bool
    
    // Updated initializer to accept isPercentage parameter
    init(items: [DistributionItem], isPercentage: Bool = false) {
        self.items = items
        self.isPercentage = isPercentage
    }
    
    private func formattedValue(_ val: Double) -> String {
        if isPercentage {
            return String(format: "%.1f%%", val)
        } else {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.groupingSeparator = " "
            return formatter.string(from: NSNumber(value: val)) ?? "\(Int(val))"
        }
    }
    
    var body: some View {
        Chart {
            ForEach(items, id: \.id) { it in
                BarMark(
                    x: .value("Valeur", it.value),
                    y: .value("Tranche", it.label)
                )
                .annotation(position: .trailing) {
                    Text(formattedValue(it.value))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 50, alignment: .trailing) // 👈 justification droite
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.55)
        .padding(.vertical)
    }
}

struct DistributionPieChart: View {
    let items: [DistributionItem]
    let isPercentage: Bool
    
    // Updated initializer to accept isPercentage parameter
    init(items: [DistributionItem], isPercentage: Bool = false) {
        self.items = items
        self.isPercentage = isPercentage
    }
    
    var body: some View {
        let total = items.map { $0.value }.reduce(0, +)
        
        Chart {
            ForEach(items, id: \.id) { it in
                SectorMark(
                    angle: .value("Valeur", it.value),
                    innerRadius: .ratio(0.55)
                )
                .foregroundStyle(by: .value("Tranche", it.label))
                .annotation(position: .overlay) {   // 👈 centré dans la part
                    let pct = if isPercentage {
                        it.value // Already a percentage
                    } else {
                        total > 0 ? (it.value / total * 100) : 0 // Calculate percentage
                    }
                    if pct >= 5 {   // 👈 éviter d'afficher sur les toutes petites parts
                        Text(String(format: "%.1f%%", pct))
                            .font(.caption2)
                            .foregroundColor(.white) // 👈 lisible sur couleur vive
                            .bold()
                    }
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height * 0.55)
        .padding(.vertical)
        .chartLegend(position: .bottom, alignment: .center)
    }
}
