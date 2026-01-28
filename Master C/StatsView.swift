import SwiftUI

struct StatsView: View {
    @State private var stats: [DatabaseStats] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var dbModificationDate: Date?

    var body: some View {
        NavigationView {
            List {
                // Bloc Gestion de la base
                Section(header: Text("Gestion de la base de données")) {
                    if let date = dbModificationDate {
                        Text("Base présente, chargée le **\(dateFormatter.string(from: date))**")
                            .multilineTextAlignment(.leading)
                    } else {
                        Text("Aucune base détectée en local.")
                            .foregroundColor(.secondary)
                    }

                    if isLoading {
                        ProgressView("Chargement en cours…")
                    } else {
                        Button {
                            reloadDatabase()
                        } label: {
                            Label("Recharger la base", systemImage: "arrow.clockwise.circle")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let error = loadError {
                        Text(error)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }

                // Section statistiques
                ForEach(stats) { stat in
                    Section(header: Text("📂 \(stat.tableName)")) {
                        HStack {
                            Text("Nombre de lignes")
                            Spacer()
                            Text("\(stat.rowCount)")
                                .font(.system(.body, design: .monospaced))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Colonnes :")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(stat.columns.joined(separator: ", "))
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(.primary)
                                .padding(.top, 2)
                        }
                    }
                }

                Section {
                    ClientDiagnosticsView()
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Statistiques BDD")
            .onAppear {
                stats = DatabaseManager.shared.getStats()
                dbModificationDate = DatabaseManager.shared.getLocalDatabaseInfo().modificationDate
            }
        }
    }

    private func reloadDatabase() {
        isLoading = true
        loadError = nil
        DatabaseManager.shared.updateDatabaseFromDropbox { success in
            isLoading = false
            if success {
                stats = DatabaseManager.shared.getStats()
                dbModificationDate = DatabaseManager.shared.getLocalDatabaseInfo().modificationDate
            } else {
                loadError = "❌ Échec du téléchargement de la base."
            }
        }
    }

    private var dateFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "dd/MM/yyyy"
        return df
    }
}

// MARK: - Client Diagnostics Panel (ajout)

struct ClientDiagnosticsView: View {
    @State private var clientIdText: String = ""
    @State private var dateText: String = ""   // format "yyyy-MM-dd"
    @State private var logs: [String] = []

    func log(_ line: String) {
        DispatchQueue.main.async {
            logs.insert(line, at: 0) // plus lisible, derniers logs en haut
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Paramètres")) {
                    TextField("Client ID (ex: 1869)", text: $clientIdText)
                        .keyboardType(.numberPad)
                    TextField("Date (yyyy-MM-dd)", text: $dateText)
                }

                DisclosureGroup("Chargements généraux") {
                    Button("fetchClientMetricsWithVolat") {
                        guard let id = Int(clientIdText) else { return }
                        let m = DatabaseManager.shared.fetchClientMetricsWithVolat()
                        if let x = m[id] {
                            log("fetchClientMetricsWithVolat[\(id)] => valo=\(x.totalValo), date=\(x.lastDate ?? "nil")")
                        } else {
                            log("fetchClientMetricsWithVolat[\(id)] => nil")
                        }
                    }
                    Button("getDatesDisponiblesPourClient") {
                        guard let id = Int(clientIdText) else { return }
                        let d = DatabaseManager.shared.getDatesDisponiblesPourClient(id)
                        log("getDatesDisponiblesPourClient[\(id)] => \(d.count) dates")
                    }
                    Button("queryAffaires(for:)") {
                        guard let id = Int(clientIdText) else { return }
                        let a = DatabaseManager.shared.queryAffaires(for: id, limit: 200)
                        log("queryAffaires(for:\(id)) => \(a.count) contrats")
                    }
                }

                DisclosureGroup("Contrats") {
                    Button("contratADesDonneesHistoriques (3 contrats)") {
                        guard let id = Int(clientIdText) else { return }
                        let contrats = DatabaseManager.shared.queryAffaires(for: id, limit: 200).prefix(3)
                        for c in contrats {
                            let ok = DatabaseManager.shared.contratADesDonneesHistoriques(c.id)
                            log("contratADesDonneesHistoriques(\(c.id)) => \(ok)")
                        }
                    }
                    Button("Contrat Metrics (3 contrats)") {
                        guard let id = Int(clientIdText) else { return }
                        let contrats = DatabaseManager.shared.queryAffaires(for: id, limit: 200).prefix(3)
                        for c in contrats {
                            let m = DatabaseManager.shared.getContratMetrics(for: c.id)
                            log("getContratMetrics(\(c.id)) => \(m)")
                        }
                    }
                    Button("Mouvements Stats (3 contrats)") {
                        guard let id = Int(clientIdText) else { return }
                        let contrats = DatabaseManager.shared.queryAffaires(for: id, limit: 200).prefix(3)
                        for c in contrats {
                            let m = DatabaseManager.shared.getMouvementsStatsForAffaire(c.id)
                            log("getMouvementsStatsForAffaire(\(c.id)) => \(m)")
                        }
                    }
                }

                DisclosureGroup("Séries client") {
                    Button("getAnnualValoForClient") {
                        guard let id = Int(clientIdText) else { return }
                        let v = DatabaseManager.shared.getAnnualValoForClient(id)
                        log("getAnnualValoForClient => \(v.count) pts")
                    }
                    Button("getMonthlyValoForClient") {
                        guard let id = Int(clientIdText) else { return }
                        let v = DatabaseManager.shared.getMonthlyValoForClient(id)
                        log("getMonthlyValoForClient => \(v.count) pts")
                    }
                    Button("getAnnualMouvementsForClient") {
                        guard let id = Int(clientIdText) else { return }
                        let v = DatabaseManager.shared.getAnnualMouvementsForClient(id)
                        log("getAnnualMouvementsForClient => \(v.count) pts")
                    }
                    Button("getMonthlyMouvementsForClient") {
                        guard let id = Int(clientIdText) else { return }
                        let v = DatabaseManager.shared.getMonthlyMouvementsForClient(id)
                        log("getMonthlyMouvementsForClient => \(v.count) pts")
                    }
                    Button("getAnnualPerfVolForClient") {
                        guard let id = Int(clientIdText) else { return }
                        let v = DatabaseManager.shared.getAnnualPerfVolForClient(id)
                        log("getAnnualPerfVolForClient => \(v.count) pts")
                    }
                }

                DisclosureGroup("Répartitions client") {
                    Button("Dist Supports") {
                        guard let id = Int(clientIdText) else { return }
                        let r = DatabaseManager.shared.getLatestDistributionSupportsForClient(id)
                        log("Dist Supports client => \(r.count) items")
                    }
                    Button("Dist Catégorie principale") {
                        guard let id = Int(clientIdText) else { return }
                        let r = DatabaseManager.shared.getLatestDistributionCategorieForClient(id, key: "cat_principale")
                        log("Dist Catégorie client => \(r.count) items")
                    }
                    Button("Dist Promoteur") {
                        guard let id = Int(clientIdText) else { return }
                        let r = DatabaseManager.shared.getLatestDistributionPromoteurForClient(id)
                        log("Dist Promoteur client => \(r.count) items")
                    }
                    Button("Synthèse Supports à une date") {
                        guard let id = Int(clientIdText), !dateText.isEmpty else { return }
                        let r = DatabaseManager.shared.getSyntheseSupportsPourClient(id, aLaDate: dateText)
                        log("Synthèse supports à \(dateText) => \(r.count) lignes")
                    }
                }

                Section(header: Text("Logs")) {
                    ScrollView {
                        LazyVStack(alignment: .leading) {
                            ForEach(logs, id: \.self) { line in
                                Text(line).font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(minHeight: 150, maxHeight: 250)
                }
            }
            .navigationTitle("Diagnostics Client")
        }
    }
}

#Preview {
    StatsView()
}
