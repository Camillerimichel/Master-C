//
//  CombinedSicavChart.swift
//  Master C
//
//  Created by Michel Camilleri on 22/08/2025.
//
import SwiftUI
import Charts

struct CombinedSicavChart: View {
    let data: [SicavComparisonPoint]

    var body: some View {
        if data.isEmpty {
            Text("Aucune donnée commune").foregroundColor(.secondary)
        } else {
            let minY = data.map(\.value).min() ?? 0
            let maxY = data.map(\.value).max() ?? 100

            Chart {
                ForEach(data) { point in
                    if let d = DatabaseManager.shared.parseDate(point.date) {
                        LineMark(
                            x: .value("Date", d),
                            y: .value("SICAV", point.value),
                            series: .value("Source", point.source)
                        )
                        .foregroundStyle(by: .value("Source", point.source))
                    }
                }
            }
            .frame(height: 250)
            .chartLegend(.visible)
            .chartYScale(domain: minY...maxY)
            .chartXAxis {
                AxisMarks(values: .stride(by: .year)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.year()) // 👈 uniquement l’année
                }
            }
        }
    }
}
