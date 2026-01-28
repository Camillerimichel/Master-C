//
//  DatabaseManager.swift
//  Master C
//
//  Created by Michel Camilleri on 14/08/2025.
//

import Foundation
import SQLite3

// MARK: - Structures des tables

struct Client: Identifiable {
    let id: Int
    let nom: String
    let prenom: String
    let srri: Int?
    var displayName: String { [nom, prenom].joined(separator: " ").trimmingCharacters(in: .whitespaces) }
}

struct Support: Identifiable {
    let id: Int
    let codeIsin: String?
    let nom: String?
    let catGene: String?
    let catPrincipale: String?
    let catDet: String?
    let catGeo: String?
    let promoteur: String?
    let tauxRetro: Double?
}

struct Affaire: Identifiable {
    let id: Int
    let clientId: Int          // = id_personne
    let ref: String?
    let dateDebut: String?
    let dateCle: String?
    let srri: Int?
    let fraisCourtier: Double?
    // non présents en base (utilisés par certaines vues)
    let titre: String? = nil
    let montant: Double? = nil
}

struct HistoriqueAffaire: Identifiable {
    let id: Int
    let date: String?
    let valo: Double?
    let mouvement: Double?
    let sicav: Double?             // REAL
    let perfSicavHebdo: Double?    // REAL
    let perfSicav52: Double?       // REAL
    let volat: Double?             // REAL
    let annee: Int?                // alias "Année"
}

struct HistoriquePersonne: Identifiable {
    let id: Int
    let date: String?
    let valo: Double?
    let mouvement: Double?
    let sicav: Double?             // REAL
    let perfSicavHebdo: String?    // TEXT (⚠️ différent de _affaire_w)
    let perfSicav52: Double?
    let volat: Double?
    let srri: Int?
    let annee: Int?                // alias "Année"
}

struct HistoriquePersonneW: Identifiable {
    let id = UUID()
    let date: String?
    let valo: Double?
    let mouvement: Double?
    let perfHebdo: Double?
    let perf52: Double?
}


// MARK: - Table mariadb_historique_support_w
// idSource = identifiant du contrat
// idSupport = identifiant du support
struct HistoAffairesW: Identifiable {
    let id: Int?
    let modifQuand: Date?
    let source: String?
    let idSource: Int?      // ID du contrat
    let date: Date?
    let idSupport: String?  // ID du support
    let nbuc: Double?
    let vl: Double?
    let prmp: Double?
    let valo: Double?
}

struct SyntheseSupportClient: Identifiable {
    let id: Int
    let codeIsin: String?
    let nom: String?
    let catGene: String?
    let catPrincipale: String?
    let catDet: String?
    let catGeo: String?
    let promoteur: String?
    let tauxRetro: Double?
    let totalValo: Double
    let totalNbUC: Double
    let prmpMoyen: Double
    let poidsPourcent: Double
    let noteE: String?
    let noteS: String?
    let noteG: String?
    let srri: Int?
}


struct DistributionItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Statistiques (pour StatsView)

struct DatabaseStats: Identifiable {
    let id = UUID()
    let tableName: String
    let rowCount: Int
    let columns: [String]
}

struct DonneesESGEtendu: Identifiable {
    let id = UUID()
    let isin: String?
    let nom: String?
    let wasteEfficiency: Double?
    let waterEfficiency: Double?
    let executivePay: Double?
    let boardIndependence: Double?
    let environmentalGood: Double?
    let socialGood: Double?
    let environmentalHarm: Double?
    let socialHarm: Double?
    let numberOfEmployees: Double?
    let avgPerEmployeeSpend: Double?
    let pctFemaleBoard: Double?
    let pctFemaleExec: Double?
    let ghgIntensityValue: Double?
    let biodiversity: Double?
    let emissionsToWater: Double?
    let hazardousWaste: Double?
    let violationsUNGC: Double?
    let processesUNGC: Double?
    let genderPayGap: Double?
    let boardGenderDiversity: Double?
    let controversialWeapons: Double?
    let scope1And2CarbonIntensity: Double?
    let scope3CarbonIntensity: Double?
    let carbonTrend: Double?
    let temperatureScore: Double?
    let exposureToFossilFuels: Double?
    let renewableEnergy: Double?
    let climateImpactRevenue: Double?
    let climateChangePositive: Double?
    let climateChangeNegative: Double?
    let climateChangeNet: Double?
    let naturalResourcePositive: Double?
    let naturalResourceNegative: Double?
    let naturalResourceNet: Double?
    let pollutionPositive: Double?
    let pollutionNegative: Double?
    let pollutionNet: Double?
    let avoidingWaterScarcity: Double?
    let sfdrBiodiversityPAI: Double?
    let noteE: Double?
    let noteS: Double?
    let noteG: Double?
}

struct MouvementAffaire: Identifiable {
    let id = UUID()
    let date: Date?
    let mouvement: Double
}

struct RemunerationGlobale: Identifiable {
    let id = UUID()
    let annee: String
    let encoursMoyen: Double
    let retrocession: Double
    let assuranceVie: Double
    let total: Double
}



// MARK: - Gestionnaire de base

final class DatabaseManager {
    static let shared = DatabaseManager()
    var db: OpaquePointer?
    
    // 🔒 file série pour éviter l’accès concurrent à SQLite
    private let queue = DispatchQueue(label: "DatabaseQueue")
    private init() {}
    
    // ▶️ URL Dropbox (forcer le téléchargement direct avec dl=1)
    // Ton lien partagé a dl=0 ; on force dl=1 pour récupérer le binaire.
    private let dropboxURLString = "https://www.dropbox.com/scl/fi/lq788tvzn8gi205j2woj8/Base.sqlite?rlkey=jprzb762av8j2t3czf3jrrf2w&dl=1"
    
    // Tables attendues
    // Tables attendues
    private let expectedTables: [String] = [
        "mariadb_affaires",
        "mariadb_clients",
        "mariadb_historique_affaire_w",
        "mariadb_historique_personne_w",
        "mariadb_support",
        "mariadb_historique_support_w",
        "donnees_esg_etendu"   // ✅ corrigé
    ]
    
    // documents
    struct DocumentClientDetail: Identifiable {
        let id = UUID()  // identifiant unique SwiftUI
        let idClient: Int
        let nomClient: String
        let idDocumentBase: Int
        let nomDocument: String
        let dateCreation: Date?
        let dateObsolescence: Date?
        let statutObsolescence: String?
        let documentRef: String
        let niveau: String?
        let obsolescenceAnnees: Int?
        let risque: String?
    }
    
    
    // MARK: - Chemins
    
    private func getDatabasePath() -> String {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docDir.appendingPathComponent("Base.sqlite").path
    }
    
    func getLocalDatabaseInfo() -> (exists: Bool, modificationDate: Date?) {
        let path = getDatabasePath()
        guard FileManager.default.fileExists(atPath: path) else {
            return (false, nil)
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let modDate = attrs[.modificationDate] as? Date {
            return (true, modDate)
        }
        return (true, nil)
    }
    
    // MARK: - Ouverture / fermeture
    
    func openDatabase() -> Bool {
        if db != nil { return true }   // ✅ déjà ouverte
        
        let path = getDatabasePath()
        if FileManager.default.fileExists(atPath: path) {
            if sqlite3_open(path, &db) == SQLITE_OK {
                print("✅ Base SQLite ouverte et conservée en mémoire")
                return true
            }
        }
        print("❌ Impossible d'ouvrir la base à \(path)")
        return false
    }
    
    
    
    private func closeDatabase() {
        if db != nil {
            sqlite3_close(db)
            db = nil
            print("ℹ️ Base SQLite fermée manuellement")
        }
    }
    
    // MARK: - Téléchargement Dropbox → Documents/Base.sqlite
    
    private func downloadDatabaseFromDropbox(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: dropboxURLString) else {
            print("❌ URL Dropbox invalide")
            completion(false)
            return
        }
        
        let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                print("❌ Téléchargement Dropbox échoué: \(error)")
                completion(false)
                return
            }
            guard let tempURL = tempURL else {
                print("❌ Téléchargement sans fichier")
                completion(false)
                return
            }
            
            let dstPath = self.getDatabasePath()
            let dstURL = URL(fileURLWithPath: dstPath)
            do {
                // Remplace l'ancien fichier
                if FileManager.default.fileExists(atPath: dstPath) {
                    try FileManager.default.removeItem(at: dstURL)
                }
                try FileManager.default.copyItem(at: tempURL, to: dstURL)
                print("✅ Base.sqlite téléchargée et copiée en Documents")
                completion(true)
            } catch {
                print("❌ Copie du fichier téléchargé échouée: \(error)")
                completion(false)
            }
        }
        task.resume()
    }
    
    // MARK: - Vérifications des tables
    
    private func currentTables(in db: OpaquePointer?) -> Set<String> {
        var set = Set<String>()
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT name FROM sqlite_master WHERE type='table';", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let name = String(cString: sqlite3_column_text(stmt, Int32(0)))
                set.insert(name)
            }
        }
        sqlite3_finalize(stmt)
        return set
    }
    
    private func ensureExpectedTables() -> Bool {
        var localDB: OpaquePointer?
        let path = getDatabasePath()
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ Base.sqlite manquant en Documents")
            return false
        }
        guard sqlite3_open(path, &localDB) == SQLITE_OK else {
            print("❌ Ouverture échouée après téléchargement")
            return false
        }
        let found = currentTables(in: localDB)
        sqlite3_close(localDB)
        
        let expected = Set(expectedTables)
        if expected.isSubset(of: found) {
            print("✅ La base en Documents contient bien les tables attendues.")
            return true
        } else {
            print("❌ Tables manquantes après téléchargement: \(expected.subtracting(found))")
            print("ℹ️ Tables présentes: \(found)")
            return false
        }
    }
    
    // MARK: - Chargement depuis Dropbox (appelé par Master_CApp)
    
    func updateDatabaseFromDropbox(completion: @escaping (Bool) -> Void) {
        // 1) Télécharge la base depuis Dropbox
        downloadDatabaseFromDropbox { ok in
            guard ok else { DispatchQueue.main.async { completion(false) }; return }
            
            // 2) Vérifie les 5 tables
            let valid = self.ensureExpectedTables()
            guard valid else { DispatchQueue.main.async { completion(false) }; return }
            
            // 3) Ping d'ouverture rapide + log des stats
            let dbPath = self.getDatabasePath()
            if sqlite3_open(dbPath, &self.db) == SQLITE_OK {
                sqlite3_close(self.db)
                print("✅ Base SQLite disponible : \(dbPath)")
                _ = self.getStats() // force le log strict des 5 tables
                DispatchQueue.main.async { completion(true) }
            } else {
                print("❌ Erreur ouverture Base.sqlite après téléchargement")
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // MARK: - Stats (log strict)
    
    @discardableResult
    private func logDatabaseStatsStrict() -> [DatabaseStats] {
        var stats: [DatabaseStats] = []
        
        let tableQuery = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        var tableStmt: OpaquePointer?
        
        var found: [String] = []
        if sqlite3_prepare_v2(db, tableQuery, -1, &tableStmt, nil) == SQLITE_OK {
            while sqlite3_step(tableStmt) == SQLITE_ROW {
                let tname = String(cString: sqlite3_column_text(tableStmt, Int32(0)))
                found.append(tname)
                
                // Colonnes
                var cols: [String] = []
                var colStmt: OpaquePointer?
                if sqlite3_prepare_v2(db, "PRAGMA table_info(\(tname));", -1, &colStmt, nil) == SQLITE_OK {
                    while sqlite3_step(colStmt) == SQLITE_ROW {
                        if let c = sqlite3_column_text(colStmt, Int32(1)) {
                            cols.append(String(cString: c))
                        }
                    }
                }
                sqlite3_finalize(colStmt)
                
                // Compte
                let cnt = executeCountQuery("SELECT COUNT(*) FROM \(tname);")
                stats.append(DatabaseStats(tableName: tname, rowCount: cnt, columns: cols))
                
                // Log par table
                print("📂 Table: \(tname) — \(cnt) lignes")
                print("    📊 Colonnes: \(cols.joined(separator: ", "))")
            }
        }
        sqlite3_finalize(tableStmt)
        
        // Vérification stricte
        let foundSet = Set(found)
        let expectedSet = Set(expectedTables)
        let missing = expectedSet.subtracting(foundSet)
        let extra = foundSet.subtracting(expectedSet)
        
        if missing.isEmpty {
            print("✅ Vérification tables: les 5 tables attendues sont présentes.")
        } else {
            print("❌ Tables manquantes: \(Array(missing))")
        }
        if !extra.isEmpty {
            print("ℹ️ Tables supplémentaires détectées (non attendues): \(Array(extra))")
        }
        
        return stats
    }
    
    func getStats() -> [DatabaseStats] {
        guard openDatabase() else { return [] }
        let s = logDatabaseStatsStrict()
        closeDatabase()
        return s
    }
    
    // MARK: - Queries typées (5 tables)
    
    func queryClients(filter: String = "", limit: Int = 10000) -> [Client] {
        let query = filter.isEmpty
        ? "SELECT id, nom, prenom, SRRI FROM mariadb_clients LIMIT \(limit);"
        : """
              SELECT id, nom, prenom, SRRI
              FROM mariadb_clients
              WHERE nom LIKE '%\(filter)%' OR prenom LIKE '%\(filter)%'
              LIMIT \(limit);
              """
        return runClientQuery(query)
    }
    
    func querySupports(filter: String = "", limit: Int = 10000) -> [Support] {
        let query = filter.isEmpty
        ? """
              SELECT id, code_isin, nom, cat_gene, cat_principale, cat_det, cat_geo, promoteur, "Taux rétro"
              FROM mariadb_support
              LIMIT \(limit);
              """
        : """
              SELECT id, code_isin, nom, cat_gene, cat_principale, cat_det, cat_geo, promoteur, "Taux rétro"
              FROM mariadb_support
              WHERE nom LIKE '%\(filter)%' OR code_isin LIKE '%\(filter)%'
              LIMIT \(limit);
              """
        return runSupportQuery(query)
    }
    
    func queryAffaires(for clientId: Int, limit: Int = 10000) -> [Affaire] {
        let query = """
        SELECT id, id_personne, ref, date_debut, date_cle, SRRI, "Frais courtier"
        FROM mariadb_affaires
        WHERE id_personne = \(clientId)
        LIMIT \(limit);
        """
        return runAffaireQuery(query)
    }
    
    // Historique Affaire — pas d'id_affaire en base
    func queryHistoriqueAffaire(limit: Int = 10000) -> [HistoriqueAffaire] {
        let query = """
        SELECT id, date, valo, mouvement, sicav, perf_sicav_hebdo, perf_sicav_52, volat, "Année" AS Annee
        FROM mariadb_historique_affaire_w
        LIMIT \(limit);
        """
        return runHistAffaireQuery(query)
    }
    
    // Historique Personne — pas d'id_personne en base
    func queryHistoriquePersonne(limit: Int = 10000) -> [HistoriquePersonne] {
        let query = """
        SELECT id, date, valo, mouvement, sicav, perf_sicav_hebdo, perf_sicav_52, volat, SRRI, "Année" AS Annee
        FROM mariadb_historique_personne_w
        LIMIT \(limit);
        """
        return runHistPersonneQuery(query)
    }
    
    func queryHistoAffairesW(limit: Int = 10000) -> [HistoAffairesW] {
        let query = """
        SELECT 
            id, modif_quand, source, id_source, date, id_support, nbuc, vl, prmp, valo
        FROM mariadb_historique_support_w
        LIMIT \(limit);
        """
        return runHistoAffairesWQuery(query)
    }
    
    // MARK: - Exécution des requêtes
    
    private func runClientQuery(_ query: String) -> [Client] {
        guard openDatabase() else { return [] }
        var results: [Client] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(Client(
                    id: Int(sqlite3_column_int(stmt, Int32(0))),
                    nom: textColumn(stmt, 1),
                    prenom: textColumn(stmt, 2),
                    srri: intColumn(stmt, 3)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    private func runSupportQuery(_ query: String) -> [Support] {
        guard openDatabase() else { return [] }
        var results: [Support] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(Support(
                    id: intColumn(stmt, 0) ?? 0,
                    codeIsin: optionalTextColumn(stmt, 1),
                    nom: optionalTextColumn(stmt, 2),
                    catGene: optionalTextColumn(stmt, 3),
                    catPrincipale: optionalTextColumn(stmt, 4),
                    catDet: optionalTextColumn(stmt, 5),
                    catGeo: optionalTextColumn(stmt, 6),
                    promoteur: optionalTextColumn(stmt, 7),
                    tauxRetro: doubleColumn(stmt, 8)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    private func runAffaireQuery(_ query: String) -> [Affaire] {
        guard openDatabase() else { return [] }
        var results: [Affaire] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(Affaire(
                    id: intColumn(stmt, 0) ?? 0,
                    clientId: intColumn(stmt, 1) ?? 0,
                    ref: optionalTextColumn(stmt, 2),
                    dateDebut: optionalTextColumn(stmt, 3),
                    dateCle: optionalTextColumn(stmt, 4),
                    srri: intColumn(stmt, 5),
                    fraisCourtier: doubleColumn(stmt, 6)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    private func runHistAffaireQuery(_ query: String) -> [HistoriqueAffaire] {
        guard openDatabase() else { return [] }
        var results: [HistoriqueAffaire] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(HistoriqueAffaire(
                    id: intColumn(stmt, 0) ?? 0,
                    date: optionalTextColumn(stmt, 1),
                    valo: doubleColumn(stmt, 2),
                    mouvement: doubleColumn(stmt, 3),
                    sicav: doubleColumn(stmt, 4),
                    perfSicavHebdo: doubleColumn(stmt, 5),
                    perfSicav52: doubleColumn(stmt, 6),
                    volat: doubleColumn(stmt, 7),
                    annee: intColumn(stmt, 8)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    private func runHistPersonneQuery(_ query: String) -> [HistoriquePersonne] {
        guard openDatabase() else { return [] }
        var results: [HistoriquePersonne] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                results.append(HistoriquePersonne(
                    id: intColumn(stmt, 0) ?? 0,
                    date: optionalTextColumn(stmt, 1),
                    valo: doubleColumn(stmt, 2),
                    mouvement: doubleColumn(stmt, 3),
                    sicav: doubleColumn(stmt, 4),
                    // TEXT ici :
                    perfSicavHebdo: optionalTextColumn(stmt, 5),
                    perfSicav52: doubleColumn(stmt, 6),
                    volat: doubleColumn(stmt, 7),
                    srri: intColumn(stmt, 8),
                    annee: intColumn(stmt, 9)
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    private func runHistoAffairesWQuery(_ query: String) -> [HistoAffairesW] {
        guard openDatabase() else { return [] }
        var results: [HistoAffairesW] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let modifQuandStr = optionalTextColumn(stmt, 1)
                let dateStr = optionalTextColumn(stmt, 4)
                
                results.append(HistoAffairesW(
                    id: intColumn(stmt, 0),
                    modifQuand: modifQuandStr.flatMap { parseDate($0) },
                    source: optionalTextColumn(stmt, 2),
                    idSource: intColumn(stmt, 3),
                    date: dateStr.flatMap { parseDate($0) },
                    idSupport: optionalTextColumn(stmt, 5),
                    nbuc: doubleColumn(stmt, 6),
                    vl: doubleColumn(stmt, 7),
                    prmp: doubleColumn(stmt, 8),
                    valo: doubleColumn(stmt, 9)
                ))
            }
        }
        
        sqlite3_finalize(stmt)
        return results
    }
    
    // MARK: - Utilitaires SQLite
    
    private func dateColumn(_ stmt: OpaquePointer?, _ index: Int) -> Date? {
        guard let c = sqlite3_column_text(stmt, Int32(index)) else { return nil }
        let str = String(cString: c)
        return parseDate(str)
    }
    
    
    
    
    private func executeCountQuery(_ query: String) -> Int {
        var stmt: OpaquePointer?
        var count = 0
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                count = Int(sqlite3_column_int(stmt, Int32(0)))
            }
        }
        sqlite3_finalize(stmt)
        return count
    }
    
    private func textColumn(_ stmt: OpaquePointer?, _ index: Int) -> String {
        String(cString: sqlite3_column_text(stmt, Int32(index)))
    }
    
    func optionalTextColumn(_ stmt: OpaquePointer?, _ index: Int) -> String? {
        guard let c = sqlite3_column_text(stmt, Int32(index)) else { return nil }
        return String(cString: c)
    }
    func optionalDateColumn(_ stmt: OpaquePointer?, _ index: Int32) -> Date? {
        if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
        if let cString = sqlite3_column_text(stmt, index) {
            let str = String(cString: cString)
            // Essaye format standard SQLite : "YYYY-MM-DD" ou "YYYY-MM-DD HH:MM:SS"
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            if str.count == 10 {
                formatter.dateFormat = "yyyy-MM-dd"
            } else {
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            }
            return formatter.date(from: str)
        }
        return nil
    }
    
    func intColumn(_ stmt: OpaquePointer?, _ index: Int) -> Int? {
        sqlite3_column_type(stmt, Int32(index)) != SQLITE_NULL
        ? Int(sqlite3_column_int(stmt, Int32(index)))
        : nil
    }
    
    // MARK: - Utilitaires de vérification et de parsing
    
    func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: string) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
    
    // Vérifie l'existence d'une colonne dans une table
    private func tableHasColumn(table: String, column: String) -> Bool {
        guard openDatabase() else { return false }
        defer { closeDatabase() }
        var stmt: OpaquePointer?
        var exists = false
        if sqlite3_prepare_v2(db, "PRAGMA table_info(\(table));", -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let c = sqlite3_column_text(stmt, Int32(1)) {
                    let name = String(cString: c)
                    if name == column { exists = true; break }
                }
            }
        }
        sqlite3_finalize(stmt)
        return exists
    }
    
    // MARK: - Métriques clients et contrats
    
    // DatabaseManager.swift optimisé (partie réécrite)
    // Fonctions fetchClientMetrics, fetchClientMetricsWithVolat et fetchContratMetricsWithVolat
    
    func fetchClientMetrics() -> [Int: (totalValo: Double, lastDate: String?, lastSrri: Int?)] {
        let table = "mariadb_historique_personne_w"
        guard openDatabase() else { return [:] }
        
        var results: [Int: (Double, String?, Int?)] = [:]
        
        let query = """
            SELECT id,
                   MAX(date) AS last_date,
                   FIRST_VALUE(valo)  OVER (PARTITION BY id ORDER BY date DESC)  AS last_valo,
                   FIRST_VALUE(volat) OVER (PARTITION BY id ORDER BY date DESC)  AS last_volat
            FROM \(table)
            GROUP BY id;
            """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let personId   = Int(sqlite3_column_int(stmt, Int32(0)))
                let lastDate   = optionalTextColumn(stmt, 1)
                let lastValo   = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? sqlite3_column_double(stmt, 2) : 0.0
                let rawVolat   = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil
                
                let srriActuel = rawVolat.map { calculateSRRI(fromVolat: $0) }
                
                results[personId] = (lastValo, lastDate, srriActuel)
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    func fetchClientMetricsWithVolat() -> [Int: (totalValo: Double, lastDate: String?, lastSrri: Int?, lastVolat: Double?)] {
        return queue.sync {
            let table = "mariadb_historique_personne_w"
            guard openDatabase() else { return [:] }
            var results: [Int: (Double, String?, Int?, Double?)] = [:]
            let query = """
                SELECT id,
                       MAX(date) AS last_date,
                       FIRST_VALUE(valo)  OVER (PARTITION BY id ORDER BY date DESC)  AS last_valo,
                       FIRST_VALUE(volat) OVER (PARTITION BY id ORDER BY date DESC)  AS last_volat
                FROM \(table)
                GROUP BY id;
                """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let personId   = Int(sqlite3_column_int(stmt, 0))
                    let lastDate   = optionalTextColumn(stmt, 1)
                    let lastValo   = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? sqlite3_column_double(stmt, 2) : 0.0
                    let rawVolat   = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil
                    let srriActuel = rawVolat.map { calculateSRRI(fromVolat: $0) }
                    let volAff     = rawVolat.map { $0 * 100.0 }
                    results[personId] = (lastValo, lastDate, srriActuel, volAff)
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }
    
    
    
    func fetchContratMetricsWithVolat() -> [Int: (totalValo: Double, lastDate: String?, lastSrri: Int?, lastVolat: Double?)] {
        return queue.sync {
            guard openDatabase() else { return [:] }
            var results: [Int: (Double, String?, Int?, Double?)] = [:]
            let query = """
                SELECT id,
                       MAX(date) AS last_date,
                       FIRST_VALUE(valo)  OVER (PARTITION BY id ORDER BY date DESC)  AS last_valo,
                       FIRST_VALUE(volat) OVER (PARTITION BY id ORDER BY date DESC)  AS last_volat
                FROM mariadb_historique_affaire_w
                GROUP BY id;
                """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let contratId  = Int(sqlite3_column_int(stmt, 0))
                    let lastDate   = optionalTextColumn(stmt, 1)
                    let lastValo   = sqlite3_column_type(stmt, 2) != SQLITE_NULL ? sqlite3_column_double(stmt, 2) : 0.0
                    let rawVolat   = sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil
                    let srriActuel = rawVolat.map { calculateSRRI(fromVolat: $0) }
                    let volAff     = rawVolat.map { $0 * 100.0 }
                    results[contratId] = (lastValo, lastDate, srriActuel, volAff)
                }
            }
            sqlite3_finalize(stmt)
            return results
        }
    }
    
    
    
    
    
    // Conversion volatilité → SRRI selon ta table
    private func calculateSRRI(fromVolat volat: Double) -> Int {
        switch volat {
        case ..<0.005: // < 0,5%
            return 1
        case 0.005..<0.02: // 0,5% à < 2%
            return 2
        case 0.02..<0.05: // 2% à < 5%
            return 3
        case 0.05..<0.10: // 5% à < 10%
            return 4
        case 0.10..<0.15: // 10% à < 15%
            return 5
        case 0.15..<0.25: // 15% à < 25%
            return 6
        default: // ≥ 25%
            return 7
        }
    }
    
    // MARK: - Statistiques de mouvement
    
    func getMouvementsStats(for personId: Int) -> (versements: Double, retraits: Double, solde: Double) {
        guard openDatabase() else { return (0, 0, 0) }
        
        let query = """
        SELECT mouvement
        FROM mariadb_historique_personne_w
        WHERE id = ?
        """
        
        var stmt: OpaquePointer?
        var totalPos: Double = 0
        var totalNeg: Double = 0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let mouvement = sqlite3_column_double(stmt, 0)
                if mouvement > 0 {
                    totalPos += mouvement
                } else if mouvement < 0 {
                    totalNeg += mouvement
                }
            }
        }
        sqlite3_finalize(stmt)
        
        return (totalPos, totalNeg, totalPos + totalNeg)
    }
    
    func getDateAnciennete(for personId: Int) -> Date? {
        guard openDatabase() else { return nil }
        
        let query = """
        SELECT MIN(date)
        FROM mariadb_historique_personne_w
        WHERE id = ?
        """
        
        var stmt: OpaquePointer?
        var minDate: Date? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            if sqlite3_step(stmt) == SQLITE_ROW, let dateStr = optionalTextColumn(stmt, 0) {
                minDate = parseDate(dateStr)
            }
        }
        sqlite3_finalize(stmt)
        return minDate
    }
    
    // MARK: - Graphiques : Valorisation annuelle et mensuelle
    
    func getAnnualValoForClient(_ personId: Int) -> [(annee: Int, valo: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT "Année",
                   FIRST_VALUE(valo) OVER (PARTITION BY "Année" ORDER BY date DESC) AS last_valo
            FROM mariadb_historique_personne_w
            WHERE id = ?
            GROUP BY "Année";
            """
        
        var stmt: OpaquePointer?
        var results: [(Int, Double)] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let annee = intColumn(stmt, 0),
                   let valo = doubleColumn(stmt, 1) {
                    results.append((annee, valo))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    
    func getMonthlyValoForClient(_ personId: Int) -> [(date: Date, valo: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT date,
                   valo
            FROM mariadb_historique_personne_w
            WHERE id = ?
            ORDER BY date;
            """
        
        var stmt: OpaquePointer?
        var results: [(Date, Double)] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let d = dateColumn(stmt, 0),
                   let valo = doubleColumn(stmt, 1) {
                    results.append((d, valo))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    // MARK: - Graphiques : Cumul des mouvements
    
    func getAnnualMouvementsForClient(_ personId: Int) -> [(Int, Double)] {
        guard openDatabase() else { return [] }
        
        
        let query = """
        SELECT "Année", SUM(mouvement) as total_mvt
        FROM mariadb_historique_personne_w
        WHERE id = ?
        GROUP BY "Année"
        ORDER BY "Année" ASC;
        """
        
        var stmt: OpaquePointer?
        var result: [(Int, Double)] = []
        var cumul: Double = 0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let annee = intColumn(stmt, 0),
                   let mvt = doubleColumn(stmt, 1) {
                    cumul += mvt
                    result.append((annee, cumul))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    func getMonthlyMouvementsForClient(_ personId: Int) -> [(date: Date, cumulMouvements: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT date, mouvement
            FROM mariadb_historique_personne_w
            WHERE id = ?
            ORDER BY date;
            """
        
        var stmt: OpaquePointer?
        var results: [(Date, Double)] = []
        var cumul = 0.0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let d = dateColumn(stmt, 0),
                   let mvt = doubleColumn(stmt, 1) {
                    cumul += mvt
                    results.append((d, cumul))   // ✅ cumul progressif sur toute la période
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    
    
    // MARK: - Version Affaire pour les graphiques
    
    func getAnnualValoForAffaire(_ affaireId: Int) -> [(annee: Int, valo: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT "Année",
                   FIRST_VALUE(valo) OVER (PARTITION BY "Année" ORDER BY date DESC) AS last_valo
            FROM mariadb_historique_affaire_w
            WHERE id = ?
            GROUP BY "Année";
            """
        
        var stmt: OpaquePointer?
        var results: [(Int, Double)] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let annee = intColumn(stmt, 0),
                   let valo = doubleColumn(stmt, 1) {
                    results.append((annee, valo))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    func getMonthlyValoForAffaire(_ affaireId: Int) -> [(date: Date, valo: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT date,
                   valo
            FROM mariadb_historique_affaire_w
            WHERE id = ?
            ORDER BY date;
            """
        
        var stmt: OpaquePointer?
        var results: [(Date, Double)] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let d = dateColumn(stmt, 0),
                   let valo = doubleColumn(stmt, 1) {
                    results.append((d, valo))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    
    func getAnnualMouvementsForAffaire(_ affaireId: Int) -> [(Int, Double)] {
        guard openDatabase() else { return [] }
        
        
        let query = """
        SELECT \"Année\", SUM(mouvement) AS total
        FROM mariadb_historique_affaire_w
        WHERE id = ?
        GROUP BY \"Année\"
        ORDER BY \"Année\";
        """
        
        var stmt: OpaquePointer?
        var result: [(Int, Double)] = []
        var cumul: Double = 0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let annee = intColumn(stmt, 0),
                   let mvt = doubleColumn(stmt, 1) {
                    cumul += mvt
                    result.append((annee, cumul))
                }
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    func getMonthlyMouvementsForAffaire(_ affaireId: Int) -> [(date: Date, cumulMouvements: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT date, mouvement
            FROM mariadb_historique_affaire_w
            WHERE id = ?
            ORDER BY date;
            """
        
        var stmt: OpaquePointer?
        var results: [(Date, Double)] = []
        var cumul = 0.0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let d = dateColumn(stmt, 0),
                   let mvt = doubleColumn(stmt, 1) {
                    cumul += mvt
                    results.append((d, cumul))   // ✅ cumul progressif sur toute la période
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    
    
    // MARK: - Performances et volatilités annuelles
    
    func getAnnualPerfVolForClient(_ personId: Int) -> [(annee: Int, perf: Double, volat: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT "Année",
                   FIRST_VALUE(perf_sicav_52) OVER (PARTITION BY "Année" ORDER BY date DESC) AS perf,
                   FIRST_VALUE(volat)        OVER (PARTITION BY "Année" ORDER BY date DESC) AS volat
            FROM mariadb_historique_personne_w
            WHERE id = ?
            GROUP BY "Année";
            """
        
        var stmt: OpaquePointer?
        var results: [(Int, Double, Double)] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(personId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let annee = intColumn(stmt, 0),
                   let perf = doubleColumn(stmt, 1),
                   let vol  = doubleColumn(stmt, 2) {
                    results.append((annee, perf, vol))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    func getAnnualPerfVolForAffaire(_ affaireId: Int) -> [(annee: Int, perf: Double, volat: Double)] {
        guard openDatabase() else { return [] }
        
        let query = """
            SELECT "Année",
                   FIRST_VALUE(perf_sicav_52) OVER (PARTITION BY "Année" ORDER BY date DESC) AS perf,
                   FIRST_VALUE(volat)        OVER (PARTITION BY "Année" ORDER BY date DESC) AS volat
            FROM mariadb_historique_affaire_w
            WHERE id = ?
            GROUP BY "Année";
            """
        
        var stmt: OpaquePointer?
        var results: [(Int, Double, Double)] = []
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let annee = intColumn(stmt, 0),
                   let perf = doubleColumn(stmt, 1),
                   let vol  = doubleColumn(stmt, 2) {
                    results.append((annee, perf, vol))
                }
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    // MARK: - Synthèse des supports pour un client
    
    func getSyntheseSupportsPourClient(_ clientId: Int, aLaDate dateFiltre: String) -> [SyntheseSupportClient] {
        guard openDatabase() else { return [] }
        
        let query = """
        SELECT s.id,
               s.code_isin,
               s.nom,
               s.cat_gene,
               s.cat_principale,
               s.cat_det,
               s.cat_geo,
               s.promoteur,
               SUM(h.nbuc) as total_nbuc,      -- index 8
               SUM(h.valo) as total_valo,      -- index 9
               CASE WHEN SUM(h.nbuc) != 0
                    THEN SUM(h.nbuc * IFNULL(h.prmp,0)) / SUM(h.nbuc)
                    ELSE 0 END as prmp_moyen,  -- index 10
               esg.noteE,                      -- index 11
               esg.noteS,                      -- index 12
               esg.noteG,                      -- index 13
               s.SRRI   -- index 14
        FROM mariadb_affaires a
        JOIN mariadb_historique_support_w h ON h.id_source = a.id
        JOIN mariadb_support s ON s.id = h.id_support
        LEFT JOIN donnees_esg_etendu esg ON esg.Isin = s.code_isin
        WHERE a.id_personne = ? AND h.date = ?
        GROUP BY s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale,
                 s.cat_det, s.cat_geo, s.promoteur,
                 esg.noteE, esg.noteS, esg.noteG, s.SRRI
        ORDER BY total_valo DESC;
        """
        
        var results: [SyntheseSupportClient] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            sqlite3_bind_text(stmt, 2, (dateFiltre as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let sup = SyntheseSupportClient(
                    id: intColumn(stmt, 0) ?? 0,
                    codeIsin: optionalTextColumn(stmt, 1),
                    nom: optionalTextColumn(stmt, 2),
                    catGene: optionalTextColumn(stmt, 3),
                    catPrincipale: optionalTextColumn(stmt, 4),
                    catDet: optionalTextColumn(stmt, 5),
                    catGeo: optionalTextColumn(stmt, 6),
                    promoteur: optionalTextColumn(stmt, 7),
                    tauxRetro: nil, // pas inclus dans cette requête
                    totalValo: doubleColumn(stmt, 9) ?? 0,
                    totalNbUC: doubleColumn(stmt, 8) ?? 0,
                    prmpMoyen: doubleColumn(stmt, 10) ?? 0,   // ✅ PRMP correct
                    poidsPourcent: 0, // calculé après
                    noteE: optionalTextColumn(stmt, 11),
                    noteS: optionalTextColumn(stmt, 12),
                    noteG: optionalTextColumn(stmt, 13),
                    srri: intColumn(stmt, 14)
                )
                results.append(sup)
            }
        }
        sqlite3_finalize(stmt)
        
        // calcul du poids relatif de chaque support
        let totalGlobalValo = results.reduce(0) { $0 + $1.totalValo }
        return results.map { sup in
            SyntheseSupportClient(
                id: sup.id,
                codeIsin: sup.codeIsin,
                nom: sup.nom,
                catGene: sup.catGene,
                catPrincipale: sup.catPrincipale,
                catDet: sup.catDet,
                catGeo: sup.catGeo,
                promoteur: sup.promoteur,
                tauxRetro: sup.tauxRetro,
                totalValo: sup.totalValo,
                totalNbUC: sup.totalNbUC,
                prmpMoyen: sup.prmpMoyen,
                poidsPourcent: totalGlobalValo > 0 ? (sup.totalValo / totalGlobalValo) * 100 : 0,
                noteE: sup.noteE,
                noteS: sup.noteS,
                noteG: sup.noteG,
                srri: sup.srri
            )
        }
    }
    
    // === Synthèse supports pour un CONTRAT (mêmes champs que côté client) ===
    func getSyntheseSupportsPourContratDetail(_ affaireId: Int, aLaDate dateStr: String) -> [SyntheseSupportClient] {
        guard openDatabase() else { return [] }
        
        let query = """
        SELECT s.id,
               s.code_isin,
               s.nom,
               s.cat_gene,
               s.cat_principale,
               s.cat_det,
               s.cat_geo,
               s.promoteur,
               SUM(h.nbuc) as total_nbuc,      -- index 8
               SUM(h.valo) as total_valo,      -- index 9
               CASE WHEN SUM(h.nbuc) != 0
                    THEN SUM(h.nbuc * IFNULL(h.prmp,0)) / SUM(h.nbuc)
                    ELSE 0 END as prmp_moyen,  -- index 10
               esg.noteE,                      -- index 11
               esg.noteS,                      -- index 12
               esg.noteG,                       -- index 13
               s.SRRI
        FROM mariadb_historique_support_w h
        JOIN mariadb_support s ON s.id = h.id_support
        JOIN mariadb_affaires a ON a.id = h.id_source
        LEFT JOIN donnees_esg_etendu esg ON esg.Isin = s.code_isin
        WHERE a.id = ? AND h.date = ?
        GROUP BY s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale,
                 s.cat_det, s.cat_geo, s.promoteur,
                 esg.noteE, esg.noteS, esg.noteG,s.SRRI
        ORDER BY total_valo DESC;
        """
        
        var results: [SyntheseSupportClient] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            sqlite3_bind_text(stmt, 2, (dateStr as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let sup = SyntheseSupportClient(
                    id: intColumn(stmt, 0) ?? 0,
                    codeIsin: optionalTextColumn(stmt, 1),
                    nom: optionalTextColumn(stmt, 2),
                    catGene: optionalTextColumn(stmt, 3),
                    catPrincipale: optionalTextColumn(stmt, 4),
                    catDet: optionalTextColumn(stmt, 5),
                    catGeo: optionalTextColumn(stmt, 6),
                    promoteur: optionalTextColumn(stmt, 7),
                    tauxRetro: nil, // pas inclus dans cette requête
                    totalValo: doubleColumn(stmt, 9) ?? 0,
                    totalNbUC: doubleColumn(stmt, 8) ?? 0,
                    prmpMoyen: doubleColumn(stmt, 10) ?? 0,   // ✅ PRMP correct
                    poidsPourcent: 0, // recalculé après
                    noteE: optionalTextColumn(stmt, 11),
                    noteS: optionalTextColumn(stmt, 12),
                    noteG: optionalTextColumn(stmt, 13),
                    srri: intColumn(stmt, 14)
                )
                results.append(sup)
            }
        }
        sqlite3_finalize(stmt)
        
        // calcul du poids relatif de chaque support
        let totalGlobalValo = results.reduce(0) { $0 + $1.totalValo }
        return results.map { sup in
            SyntheseSupportClient(
                id: sup.id,
                codeIsin: sup.codeIsin,
                nom: sup.nom,
                catGene: sup.catGene,
                catPrincipale: sup.catPrincipale,
                catDet: sup.catDet,
                catGeo: sup.catGeo,
                promoteur: sup.promoteur,
                tauxRetro: sup.tauxRetro,
                totalValo: sup.totalValo,
                totalNbUC: sup.totalNbUC,
                prmpMoyen: sup.prmpMoyen,
                poidsPourcent: totalGlobalValo > 0 ? (sup.totalValo / totalGlobalValo) * 100 : 0,
                noteE: sup.noteE,
                noteS: sup.noteS,
                noteG: sup.noteG,
                srri: sup.srri
            )
        }
    }
    
    // Variante pratique si tu as déjà une Date
    func getSyntheseSupportsPourContratDetail(_ affaireId: Int, aLaDate: Date) -> [SyntheseSupportClient] {
        getSyntheseSupportsPourContratDetail(affaireId, aLaDate: dateFormatter.string(from: aLaDate))
    }
    
    // MARK: - Historique support par affaire
    func getHistoriqueSupportPourAffaire(contratId: Int, supportId: Int) -> [HistoAffairesW] {
        guard openDatabase() else { return [] }
        let query = """
        SELECT h.id, h.modif_quand, h.source, h.id_source, h.date,
               h.id_support, h.nbuc, h.vl, h.prmp, h.valo
        FROM mariadb_historique_support_w h
        WHERE h.id_source = ?
          AND h.id_support = ?
        ORDER BY h.date ASC;
        """
        
        var results: [HistoAffairesW] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            // Bind contratId (INTEGER)
            sqlite3_bind_int(stmt, 1, Int32(contratId))
            // Bind supportId (TEXT)
            sqlite3_bind_text(stmt, 2, (String(supportId) as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let modifQuand = optionalDateColumn(stmt, 1)
                let source = optionalTextColumn(stmt, 2)
                let idSource = Int(sqlite3_column_int(stmt, 3))
                let date = optionalDateColumn(stmt, 4)
                let idSupport = optionalTextColumn(stmt, 5)
                let nbuc = sqlite3_column_double(stmt, 6)
                let vl = sqlite3_column_double(stmt, 7)
                let prmp = sqlite3_column_double(stmt, 8)
                let valo = sqlite3_column_double(stmt, 9)
                
                results.append(
                    HistoAffairesW(
                        id: id,
                        modifQuand: modifQuand,
                        source: source,
                        idSource: idSource,
                        date: date,
                        idSupport: idSupport,
                        nbuc: nbuc,
                        vl: vl,
                        prmp: prmp,
                        valo: valo
                    )
                )
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    // Dates côté contrat en STRING pour matcher 1:1 avec la base
    func getDatesDisponiblesPourContratRAW(_ affaireId: Int) -> [String] {
        return queue.sync {
            guard openDatabase() else { return [] }
            let query = """
                SELECT DISTINCT date
                FROM mariadb_historique_support_w
                WHERE id_source = ?
                ORDER BY date DESC;
                """
            var out: [String] = []
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(affaireId))
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let s = optionalTextColumn(stmt, 0) { out.append(s) }
                }
            }
            sqlite3_finalize(stmt)
            return out
        }
    }

    // MARK: - Correction de la méthode getSyntheseSupportsPourContrat
    
    func getSyntheseSupportsPourContrat(_ affaireId: Int, aLaDate: Date? = nil) -> [(support: Support, montant: Double)] {
        guard openDatabase() else { return [] }
        
        var results: [(Support, Double)] = []
        
        // ✅ Correction 1: Utiliser CAST ou s'assurer que les types correspondent
        // ✅ Correction 2: Gérer le cas où aLaDate est nil (prendre la date la plus récente)
        var query: String
        
        if aLaDate != nil {
            // Cas avec date spécifique
            query = """
                SELECT s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale,
                       s.cat_det, s.cat_geo, s.promoteur, s."Taux rétro",
                       SUM(h.valo) as total_valo
                FROM mariadb_support s
                JOIN mariadb_historique_support_w h ON CAST(h.id_support AS INTEGER) = s.id
                WHERE h.id_source = ? AND h.date = ?
                GROUP BY s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale,
                         s.cat_det, s.cat_geo, s.promoteur, s."Taux rétro"
                ORDER BY total_valo DESC
                """
        } else {
            // Cas sans date : prendre les données de la date la plus récente
            query = """
                SELECT s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale,
                       s.cat_det, s.cat_geo, s.promoteur, s."Taux rétro",
                       SUM(h.valo) as total_valo
                FROM mariadb_support s
                JOIN mariadb_historique_support_w h ON CAST(h.id_support AS INTEGER) = s.id
                WHERE h.id_source = ? 
                AND h.date = (
                    SELECT MAX(date) 
                    FROM mariadb_historique_support_w 
                    WHERE id_source = ?
                )
                GROUP BY s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale,
                         s.cat_det, s.cat_geo, s.promoteur, s."Taux rétro"
                ORDER BY total_valo DESC
                """
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            
            if let d = aLaDate {
                // Utiliser le bon format de date
                let dateString = dateFormatter.string(from: d)
                sqlite3_bind_text(stmt, 2, (dateString as NSString).utf8String, -1, nil)
            } else {
                // Pour la requête avec MAX(date), on bind le même affaireId deux fois
                sqlite3_bind_int(stmt, 2, Int32(affaireId))
            }
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let support = Support(
                    id: Int(sqlite3_column_int(stmt, 0)),
                    codeIsin: optionalTextColumn(stmt, 1),
                    nom: optionalTextColumn(stmt, 2),
                    catGene: optionalTextColumn(stmt, 3),
                    catPrincipale: optionalTextColumn(stmt, 4),
                    catDet: optionalTextColumn(stmt, 5),
                    catGeo: optionalTextColumn(stmt, 6),
                    promoteur: optionalTextColumn(stmt, 7),
                    tauxRetro: doubleColumn(stmt, 8)
                )
                let montant = sqlite3_column_double(stmt, 9)
                results.append((support, montant))
            }
        } else {
            // ✅ Debug: Afficher l'erreur SQL
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Erreur SQL getSyntheseSupportsPourContrat: \(String(cString: errorMsg))")
            }
        }
        sqlite3_finalize(stmt)
        
        // ✅ Debug: Afficher le nombre de résultats
        print("ℹ️ getSyntheseSupportsPourContrat - Contrat \(affaireId): \(results.count) supports trouvés")
        
        return results
    }
    
    
    
    // ✅ Correction 3: Vérifier aussi la méthode de récupération des dates
    func getDatesDisponiblesPourContrat(_ affaireId: Int) -> [Date] {
        guard openDatabase() else { return [] }
        var results: [Date] = []
        
        let query = """
            SELECT DISTINCT date
            FROM mariadb_historique_support_w
            WHERE id_source = ?
            ORDER BY date DESC;
            """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let d = dateColumn(stmt, 0) {
                    results.append(d)
                }
            }
        } else {
            // Debug
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Erreur SQL getDatesDisponiblesPourContrat: \(String(cString: errorMsg))")
            }
        }
        sqlite3_finalize(stmt)
        
        print("ℹ️ getDatesDisponiblesPourContrat - Contrat \(affaireId): \(results.count) dates trouvées")
        return results
    }
    
    
    func getDatesDisponiblesPourClient(_ clientId: Int) -> [String] {
        guard openDatabase() else { return [] }
        
        
        let query = """
        SELECT DISTINCT date
        FROM mariadb_historique_support_w h
        JOIN mariadb_affaires a ON a.id = h.id_source
        WHERE a.id_personne = ?
        ORDER BY date DESC
        """
        
        var dates: [String] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let dateStr = optionalTextColumn(stmt, 0) {
                    dates.append(dateStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        return dates
    }
    // ✅ Correction 4: S'assurer que le dateFormatter est correctement défini
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    // ✅ Méthode de diagnostic pour identifier le problème
    func diagnosticContratSupports(_ affaireId: Int) {
        guard openDatabase() else { return }
        
        print("🔍 === DIAGNOSTIC CONTRAT \(affaireId) ===")
        
        // 1. Vérifier si le contrat existe
        let queryContrat = "SELECT COUNT(*) FROM mariadb_affaires WHERE id = ?;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, queryContrat, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = sqlite3_column_int(stmt, 0)
                print("✅ Contrat existe: \(count > 0 ? "OUI" : "NON")")
            }
        }
        sqlite3_finalize(stmt)
        
        // 2. Vérifier les données dans histo_affaires_w
        let queryHisto = "SELECT COUNT(*) FROM mariadb_historique_support_w WHERE id_source = ?;"
        if sqlite3_prepare_v2(db, queryHisto, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = sqlite3_column_int(stmt, 0)
                print("✅ Historique histo_affaires_w: \(count) lignes")
            }
        }
        sqlite3_finalize(stmt)
        
        // 3. Vérifier les id_support dans histo_affaires_w
        let querySupports = "SELECT DISTINCT id_support FROM mariadb_historique_support_w WHERE id_source = ?;"
        if sqlite3_prepare_v2(db, querySupports, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            var supportIds: [String] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let supportId = optionalTextColumn(stmt, 0) {
                    supportIds.append(supportId)
                }
            }
            print("✅ Support IDs trouvés: \(supportIds)")
        }
        sqlite3_finalize(stmt)
        
        // 4. Vérifier la correspondance avec la table support
        let queryMatchSupports = """
            SELECT h.id_support, s.id, s.nom 
            FROM mariadb_historique_support_w h
            LEFT JOIN mariadb_support s ON CAST(h.id_support AS INTEGER) = s.id
            WHERE h.id_source = ?
            LIMIT 5;
            """
        if sqlite3_prepare_v2(db, queryMatchSupports, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idSupport = optionalTextColumn(stmt, 0) ?? "NULL"
                let supportId = intColumn(stmt, 1) ?? -1
                let supportNom = optionalTextColumn(stmt, 2) ?? "NULL"
                print("✅ Match: histo.id_support=\(idSupport) -> support.id=\(supportId) nom=\(supportNom)")
            }
        }
        sqlite3_finalize(stmt)
        
        // ✅ Ajout d’un diagnostic global sur les deux nouvelles tables
        let extraTables = ["mariadb_historique_support_w", "Données ESG étendu"]
        for t in extraTables {
            let q = "SELECT COUNT(*) FROM \"\(t)\";"
            var stmt2: OpaquePointer?
            if sqlite3_prepare_v2(db, q, -1, &stmt2, nil) == SQLITE_OK {
                if sqlite3_step(stmt2) == SQLITE_ROW {
                    let cnt = sqlite3_column_int(stmt2, 0)
                    print("📊 Table \(t): \(cnt) lignes")
                }
            } else {
                if let err = sqlite3_errmsg(db) {
                    print("❌ Erreur lecture table \(t): \(String(cString: err))")
                }
            }
            sqlite3_finalize(stmt2)
        }
        
        
        print("🔍 === FIN DIAGNOSTIC ===")
    }
    func queryHistoriquePersonneW(for clientId: Int) -> [HistoriquePersonneW] {
        guard openDatabase() else { return [] }
        
        
        let query = """
        SELECT date, valo, mouvement, perf_sicav_hebdo, perf_sicav_52
        FROM mariadb_historique_personne_w
        WHERE id = ?
        ORDER BY date ASC
        """
        
        var result: [HistoriquePersonneW] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let date = optionalTextColumn(stmt, 0)
                let valo = doubleColumn(stmt, 1)
                let mouvement = doubleColumn(stmt, 2)
                let perfHebdo = doubleColumn(stmt, 3)
                let perf52 = doubleColumn(stmt, 4)
                
                let histo = HistoriquePersonneW(
                    date: date,
                    valo: valo,
                    mouvement: mouvement,
                    perfHebdo: perfHebdo,
                    perf52: perf52
                )
                result.append(histo)
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    // MARK: - Vérification de données historiques pour contrats
    
    func contratADesDonneesHistoriques(_ affaireId: Int) -> Bool {
        return queue.sync {
            var stmt: OpaquePointer?
            let query = """
                SELECT COUNT(*)
                FROM mariadb_historique_support_w
                WHERE id_source = ?
                LIMIT 1;
                """
            var result = false
            
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(affaireId))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let count = sqlite3_column_int(stmt, 0)
                    result = (count > 0)
                }
            }
            sqlite3_finalize(stmt)
            return result
        }
    }
    
    
    
    
    func contratADesDonneesHistoriquesDetaillees(_ contratId: Int) -> Bool {
        return queue.sync {
            guard openDatabase() else { return false }
            
            // Vérifier d'abord dans mariadb_historique_support_w (liée au contrat par id_source)
            let queryHistorique = """
                SELECT COUNT(*)
                FROM mariadb_historique_support_w
                WHERE id_source = ?
                LIMIT 1;
                """
            
            var stmt: OpaquePointer?
            var hasHistorique = false
            
            if sqlite3_prepare_v2(db, queryHistorique, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int(stmt, 1, Int32(contratId))
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let count = sqlite3_column_int(stmt, 0)
                    hasHistorique = (count > 0)
                }
            }
            sqlite3_finalize(stmt)
            
            // (Conserve ton 2e check si tu veux vérifier une autre source ; ici inutile car déjà la table principale)
            return hasHistorique
        }
    }
    
    
    
    func getContratMetrics(for contratId: Int) -> (valo: Double, date: String?, srriActuel: Int?, volat: Double?)? {
        let metrics = fetchContratMetricsWithVolat()
        guard let metric = metrics[contratId] else { return nil }
        return (valo: metric.totalValo, date: metric.lastDate, srriActuel: metric.lastSrri, volat: metric.lastVolat)
    }
    
    func getMouvementsStatsForAffaire(_ affaireId: Int) -> (versements: Double, retraits: Double, solde: Double) {
        guard openDatabase() else { return (0, 0, 0) }
        
        
        let query = """
        SELECT mouvement
        FROM mariadb_historique_affaire_w
        WHERE id = ?
        """
        
        var stmt: OpaquePointer?
        var totalPos: Double = 0
        var totalNeg: Double = 0
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let mouvement = sqlite3_column_double(stmt, 0)
                if mouvement > 0 {
                    totalPos += mouvement
                } else if mouvement < 0 {
                    totalNeg += mouvement
                }
            }
        }
        sqlite3_finalize(stmt)
        
        return (totalPos, totalNeg, totalPos + totalNeg)
    }
    // MARK: - Répartitions (dernière VL) — CONTRAT
    private func getLatestDistributionForContrat(_ affaireId: Int, column: String) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        let query = """
        SELECT COALESCE(\(column), '(non renseigné)') AS label, SUM(h.valo) AS total
        FROM mariadb_historique_support_w h
        JOIN mariadb_support s ON CAST(h.id_support AS INTEGER) = s.id
        WHERE h.id_source = ?
          AND h.date = (SELECT MAX(date) FROM mariadb_historique_support_w WHERE id_source = ?)
        GROUP BY label
        ORDER BY total DESC;        
        """
        var items: [DistributionItem] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(affaireId))
            sqlite3_bind_int(stmt, 2, Int32(affaireId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let label = optionalTextColumn(stmt, 0) ?? "(non renseigné)"
                let total = doubleColumn(stmt, 1) ?? 0
                items.append(DistributionItem(label: label, value: total))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }
    
    func getLatestDistributionSupportsForContrat(_ affaireId: Int) -> [DistributionItem] {
        return queue.sync {
            self.getLatestDistributionForContrat(affaireId, column: "s.nom")
        }
    }
    
    func getLatestDistributionCategorieForContrat(_ affaireId: Int, key: String) -> [DistributionItem] {
        // Désactivé temporairement
        return []
    }
    
    func getLatestDistributionPromoteurForContrat(_ affaireId: Int) -> [DistributionItem] {
        // Désactivé temporairement
        return []
    }
    
    // MARK: - Répartitions (dernière VL) — CLIENT
    // MARK: - Répartitions (dernière VL) — CLIENT
    private func getLatestDistributionForClient(_ clientId: Int, column: String) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        let query = """
        SELECT COALESCE(\(column), '(non renseigné)') AS label,
               SUM(h.valo) AS total
        FROM mariadb_historique_support_w h
        JOIN mariadb_affaires a ON a.id = h.id_source
        JOIN mariadb_support s ON CAST(h.id_support AS INTEGER) = s.id
        WHERE a.id_personne = ?
          AND h.date = (
              SELECT MAX(h2.date)
              FROM mariadb_historique_support_w h2
              JOIN mariadb_affaires a2 ON a2.id = h2.id_source
              WHERE a2.id_personne = ?
          )
        GROUP BY label
        ORDER BY total DESC;
        """
        var items: [DistributionItem] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            sqlite3_bind_int(stmt, 2, Int32(clientId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let label = optionalTextColumn(stmt, 0) ?? "(non renseigné)"
                let total = doubleColumn(stmt, 1) ?? 0
                items.append(DistributionItem(label: label, value: total))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }
    
    func getLatestDistributionSupportsForClient(_ clientId: Int) -> [DistributionItem] {
        return queue.sync {
            self.getLatestDistributionForClient(clientId, column: "s.nom")
        }
    }
    
    func getLatestDistributionCategorieForClient(_ clientId: Int, key: String) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        
        let allowedKeys = ["cat_gene", "cat_principale", "cat_det", "cat_geo", "promoteur", "SRRI"]
        guard allowedKeys.contains(key) else { return [] }
        
        let query = """
        SELECT COALESCE(s.\(key), '(non renseigné)') AS label,
               SUM(h.valo) AS total
        FROM mariadb_historique_support_w h
        JOIN mariadb_affaires a ON a.id = h.id_source
        JOIN mariadb_support s ON CAST(h.id_support AS INTEGER) = s.id
        WHERE a.id_personne = ?
          AND h.date = (
              SELECT MAX(h2.date)
              FROM mariadb_historique_support_w h2
              JOIN mariadb_affaires a2 ON a2.id = h2.id_source
              WHERE a2.id_personne = ?
          )
        GROUP BY label
        ORDER BY total DESC;
        """
        
        var items: [DistributionItem] = []
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            sqlite3_bind_int(stmt, 2, Int32(clientId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let label = optionalTextColumn(stmt, 0) ?? "(non renseigné)"
                let total = doubleColumn(stmt, 1) ?? 0
                items.append(DistributionItem(label: label, value: total))
            }
        }
        sqlite3_finalize(stmt)
        return items
    }

    
    func getLatestDistributionPromoteurForClient(_ clientId: Int) -> [DistributionItem] {
        return queue.sync {
            self.getLatestDistributionForClient(clientId, column: "s.promoteur")
        }
    }
    
    
    // À mettre APRÈS ouverture réussie de la base (db != nil)
    private func ensureIndices() {
        // Index cruciaux pour 3,2M de lignes
        let sqls = [
            // pour toutes les recherches par contrat + date
            "CREATE INDEX IF NOT EXISTS idx_histo_affaires_source_date ON mariadb_historique_support_w(id_source, date);",
            // pour les jointures vers supports
            "CREATE INDEX IF NOT EXISTS idx_histo_affaires_support ON mariadb_historique_support_w(id_support);",
            // pour filtrer les contrats d'un client
            "CREATE INDEX IF NOT EXISTS idx_affaires_personne ON mariadb_affaires(id_personne);"
        ]
        for sql in sqls {
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                _ = sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }
    
}
// MARK: - Volumétrie (clients par tranche de valorisation)
extension DatabaseManager {
    func getVolumetrieClients(aLaDate date: Date) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        
        let dateString = dateFormatter.string(from: date) // "yyyy-MM-dd"
        var results: [DistributionItem] = []
        
        let query = """
        SELECT a.id_personne, SUM(h.valo) AS total_valo
        FROM mariadb_affaires a
        JOIN mariadb_historique_affaire_w h ON h.id_source = a.id
        WHERE h.date = ?
        GROUP BY a.id_personne;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let totalValo = sqlite3_column_double(stmt, 1)
                
                // Détermination de la tranche
                let label: String
                switch totalValo {
                case ..<100_000: label = "<100k"
                case 100_000..<250_000: label = "100–250k"
                case 250_000..<500_000: label = "250–500k"
                case 500_000..<1_000_000: label = "500k–1M"
                case 1_000_000..<5_000_000: label = "1M–5M"
                default: label = ">5M"
                }
                
                // On incrémente la valeur (compte de clients dans la tranche)
                if let idx = results.firstIndex(where: { $0.label == label }) {
                    let old = results[idx]
                    results[idx] = DistributionItem(label: label, value: old.value + 1)
                } else {
                    results.append(DistributionItem(label: label, value: 1))
                }
            }
        } else {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Erreur SQL getVolumetrieClients: \(String(cString: errorMsg))")
            }
        }
        sqlite3_finalize(stmt)
        
        return results
    }
}

// MARK: - Volumétrie (clients et montants par tranche de valorisation)
extension DatabaseManager {
    
    /// Volumétrie par nombre de clients
    func getVolumetrieClientsCount(aLaDate date: Date) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        let lastDate = getLastAvailableDate() ?? date
        let effectiveDate = min(date, lastDate)
        let dateString = dateFormatter.string(from: effectiveDate)
        let param = "\(dateString)%"
        
        // 🔒 Ordre fixe des tranches
        let tranches = [
            "<100k", "100–250k", "250–500k", "500k–1M", "1M–5M", ">5M"
        ]
        var counts = [String: Double]()
        
        let query = """
        SELECT a.id_personne, SUM(h.valo) AS total_valo
        FROM mariadb_affaires a
        JOIN mariadb_historique_support_w h ON h.id_source = a.id
        WHERE h.date LIKE ?
        GROUP BY a.id_personne;
        """
        
        let debugQuery = query.replacingOccurrences(of: "?", with: "'\(param)'")
        print("🔍 SQL getVolumetrieClientsCount : \(debugQuery)")
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (param as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let totalValo = sqlite3_column_double(stmt, 1)
                
                let label: String
                switch totalValo {
                case ..<100_000: label = "<100k"
                case 100_000..<250_000: label = "100–250k"
                case 250_000..<500_000: label = "250–500k"
                case 500_000..<1_000_000: label = "500k–1M"
                case 1_000_000..<5_000_000: label = "1M–5M"
                default: label = ">5M"
                }
                counts[label, default: 0] += 1
            }
        } else {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Erreur SQL getVolumetrieClientsCount: \(String(cString: errorMsg))")
            }
        }
        sqlite3_finalize(stmt)
        
        // 🔒 Construire résultats dans l’ordre fixe
        return tranches.map { tranche in
            DistributionItem(label: tranche, value: counts[tranche] ?? 0)
        }
    }
    
    /// Volumétrie par montants (€)
    func getVolumetrieClientsAmount(aLaDate date: Date) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        let lastDate = getLastAvailableDate() ?? date
        let effectiveDate = min(date, lastDate)
        let dateString = dateFormatter.string(from: effectiveDate)
        let param = "\(dateString)%"
        
        let tranches = [
            "<100k", "100–250k", "250–500k", "500k–1M", "1M–5M", ">5M"
        ]
        var amounts = [String: Double]()
        
        let query = """
        SELECT a.id_personne, SUM(h.valo) AS total_valo
        FROM mariadb_affaires a
        JOIN mariadb_historique_support_w h ON h.id_source = a.id
        WHERE h.date LIKE ?
        GROUP BY a.id_personne;
        """
        
        let debugQuery = query.replacingOccurrences(of: "?", with: "'\(param)'")
        print("🔍 SQL getVolumetrieClientsAmount : \(debugQuery)")
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (param as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let totalValo = sqlite3_column_double(stmt, 1)
                
                let label: String
                switch totalValo {
                case ..<100_000: label = "<100k"
                case 100_000..<250_000: label = "100–250k"
                case 250_000..<500_000: label = "250–500k"
                case 500_000..<1_000_000: label = "500k–1M"
                case 1_000_000..<5_000_000: label = "1M–5M"
                default: label = ">5M"
                }
                amounts[label, default: 0] += totalValo
            }
        } else {
            if let errorMsg = sqlite3_errmsg(db) {
                print("❌ Erreur SQL getVolumetrieClientsAmount: \(String(cString: errorMsg))")
            }
        }
        sqlite3_finalize(stmt)
        
        return tranches.map { tranche in
            DistributionItem(label: tranche, value: amounts[tranche] ?? 0)
        }
    }
}

struct VolumetrieSerie: Identifiable {
    let id = UUID()
    let tranche: String
    let type: String   // "Clients" ou "Encours"
    let valeur: Double
}
extension DatabaseManager {
    func getVolumetrieCombined(aLaDate date: Date) -> [VolumetrieSerie] {
        let counts = getVolumetrieClientsCount(aLaDate: date)
        let amounts = getVolumetrieClientsAmount(aLaDate: date)
        
        // 🔒 Ordre fixe des tranches
        let tranches = [
            "<100k", "100–250k", "250–500k", "500k–1M", "1M–5M", ">5M"
        ]
        
        var results: [VolumetrieSerie] = []
        for tranche in tranches {
            if let c = counts.first(where: { $0.label == tranche }) {
                results.append(VolumetrieSerie(tranche: tranche, type: "Clients", valeur: c.value))
            } else {
                results.append(VolumetrieSerie(tranche: tranche, type: "Clients", valeur: 0))
            }
            
            if let a = amounts.first(where: { $0.label == tranche }) {
                results.append(VolumetrieSerie(tranche: tranche, type: "Encours", valeur: a.value))
            } else {
                results.append(VolumetrieSerie(tranche: tranche, type: "Encours", valeur: 0))
            }
        }
        
        return results
    }
}





extension DatabaseManager {
    func getLastAvailableDate() -> Date? {
        guard openDatabase() else { return nil }
        
        let query = "SELECT MAX(date) FROM mariadb_historique_support_w;"
        var stmt: OpaquePointer?
        var result: Date? = nil
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                if let dateStr = optionalTextColumn(stmt, 0) {
                    result = parseDate(dateStr)
                }
            }
        }
        sqlite3_finalize(stmt)
        
        if let d = result {
            print("✅ Dernière date disponible en base : \(d)")
        } else {
            print("❌ Impossible de récupérer la dernière date en base")
        }
        
        return result
    }
}
extension DatabaseManager {
    func getRisqueStats(aLaDate date: Date) -> RisqueStats {
        guard openDatabase() else {
            return RisqueStats(sous: (0,0), aNiveau: (0,0), auDessus: (0,0), manquant: (0,0))
        }
        
        let lastDate = getLastAvailableDate() ?? date
        let effectiveDate = min(date, lastDate)
        let dateString = dateFormatter.string(from: effectiveDate)
        let param = "\(dateString)%"
        
        let query = """
        SELECT c.id, c.SRRI AS srri_client, h.SRRI AS srri_historique, h.valo
        FROM mariadb_clients c
        JOIN mariadb_historique_personne_w h ON h.id = c.id
        WHERE h.date LIKE ?;
        """
        
        var stats = RisqueStats(sous: (0,0), aNiveau: (0,0), auDessus: (0,0), manquant: (0,0))
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (param as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let srriClient = sqlite3_column_int(stmt, 1)
                let srriHistorique = sqlite3_column_int(stmt, 2)
                let totalValo = sqlite3_column_double(stmt, 3)
                
                if srriHistorique < srriClient {
                    stats.sous.clients += 1
                    stats.sous.montant += totalValo
                } else if srriHistorique == srriClient {
                    stats.aNiveau.clients += 1
                    stats.aNiveau.montant += totalValo
                } else {
                    stats.auDessus.clients += 1
                    stats.auDessus.montant += totalValo
                }
            }
        }
        sqlite3_finalize(stmt)
        
        return stats
    }
}

struct PortfolioSnapshot {
    let totalValo: Double
    let mouvementsCumules: Double
    let perf52s: Double?
    let volat: Double?
}

extension DatabaseManager {
    func getSnapshot(at refDate: Date) -> PortfolioSnapshot? {
        guard openDatabase() else { return nil }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: refDate)
        
        var totalValo: Double = 0
        var mouvements: Double = 0
        var perfMoyenne: Double? = nil
        var volatMoyenne: Double? = nil
        var stmt: OpaquePointer?
        
        // 1. Valorisation totale
        let sqlValo = """
            SELECT SUM(valo)
            FROM mariadb_historique_personne_w
            WHERE date = (
                SELECT MAX(date)
                FROM mariadb_historique_personne_w
                WHERE date <= ?
            );
        """
        if sqlite3_prepare_v2(db, sqlValo, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalValo = doubleColumn(stmt, 0) ?? 0
            }
        }
        sqlite3_finalize(stmt)
        
        // 2. Cumul mouvements
        let sqlMvt = """
            SELECT SUM(mouvement)
            FROM mariadb_historique_personne_w
            WHERE date <= ?;
        """
        if sqlite3_prepare_v2(db, sqlMvt, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                mouvements = doubleColumn(stmt, 0) ?? 0
            }
        }
        sqlite3_finalize(stmt)
        
        // 3. Moyenne perf 52s
        let sqlPerf = """
            SELECT AVG(perf_sicav_52)
            FROM mariadb_historique_personne_w
            WHERE date <= ? AND perf_sicav_52 IS NOT NULL;
        """
        if sqlite3_prepare_v2(db, sqlPerf, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                perfMoyenne = doubleColumn(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        
        // 4. Moyenne volat
        let sqlVolat = """
            SELECT AVG(volat)
            FROM mariadb_historique_personne_w
            WHERE date <= ? AND volat IS NOT NULL;
        """
        if sqlite3_prepare_v2(db, sqlVolat, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (dateString as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                volatMoyenne = doubleColumn(stmt, 0)
            }
        }
        sqlite3_finalize(stmt)
        
        return PortfolioSnapshot(
            totalValo: totalValo,
            mouvementsCumules: mouvements,
            perf52s: perfMoyenne,
            volat: volatMoyenne
        )
    }

}

// Ajoutez ces structures et méthodes à votre DatabaseManager.swift

// Ajoutez ces structures et méthodes à votre DatabaseManager.swift

// MARK: - Structure pour les totaux
struct TotalStats {
    let totalClients: Int
    let totalAffaires: Int
}

// MARK: - Extension DatabaseManager pour les totaux
extension DatabaseManager {
    
    /// Récupère le total des clients et affaires à une date donnée
    func getTotalStats(aLaDate date: Date) -> TotalStats {
        guard openDatabase() else {
            return TotalStats(totalClients: 0, totalAffaires: 0)
        }
        
        let lastDate = getLastAvailableDate() ?? date
        let effectiveDate = min(date, lastDate)
        let dateString = dateFormatter.string(from: effectiveDate)
        let param = "\(dateString)%"
        
        var totalClients = 0
        var totalAffaires = 0
        
        // 📊 Compter les clients distincts à cette date
        let clientQuery = """
        SELECT COUNT(DISTINCT id)
        FROM mariadb_historique_personne_w
        WHERE date LIKE ?;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, clientQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (param as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalClients = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        // 📊 Compter les affaires distinctes à cette date
        let affaireQuery = """
        SELECT COUNT(DISTINCT id)
        FROM mariadb_historique_affaire_w
        WHERE date LIKE ?;
        """
        
        if sqlite3_prepare_v2(db, affaireQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (param as NSString).utf8String, -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                totalAffaires = Int(sqlite3_column_int(stmt, 0))
            }
        }
        sqlite3_finalize(stmt)
        
        print("📊 Total stats pour \(dateString): \(totalClients) clients, \(totalAffaires) affaires")
        
        return TotalStats(totalClients: totalClients, totalAffaires: totalAffaires)
    }
}


extension DatabaseManager {
    
    func getSyntheseSupportsGlobal(aLaDate date: String) -> [SyntheseSupportClient] {
        var result: [SyntheseSupportClient] = []
        
        let sql = """
        SELECT 
            s.id,
            s.code_isin,
            s.nom,
            s.cat_gene,
            s.cat_principale,
            s.cat_det,
            s.cat_geo,
            s.promoteur,
            SUM(h.nbuc)    AS totalNbUC,
            SUM(h.valo)    AS totalValo,
            AVG(h.prmp)    AS prmpMoyen,
            esg.noteE,
            esg.noteS,
            esg.noteG,
            s.SRRI
        FROM mariadb_historique_support_w h
        JOIN mariadb_support s 
            ON s.id = h.id_support
        LEFT JOIN donnees_esg_etendu esg 
            ON esg.Isin = s.code_isin
        WHERE h.date = ?
        GROUP BY s.id, s.code_isin, s.nom, s.cat_gene, s.cat_principale, s.cat_det,
                 s.cat_geo, s.promoteur, esg.noteE, esg.noteS, esg.noteG,s.SRRI
        ORDER BY totalValo DESC;
        """
        
        var stmt: OpaquePointer?
        var tempSupports: [SyntheseSupportClient] = []
        
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (date as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                // ✅ CORRECTION : Ordre correct des colonnes selon la requête SQL
                let id          = Int(sqlite3_column_int(stmt, 0))               // s.id
                let codeIsin    = optionalTextColumn(stmt, 1)                    // s.code_isin
                let nom         = optionalTextColumn(stmt, 2)                    // s.nom
                let catGene     = optionalTextColumn(stmt, 3)                    // s.cat_gene
                let catPrincipale = optionalTextColumn(stmt, 4)                  // s.cat_principale
                let catDet      = optionalTextColumn(stmt, 5)                    // s.cat_det
                let catGeo      = optionalTextColumn(stmt, 6)                    // s.cat_geo
                let promoteur   = optionalTextColumn(stmt, 7)                    // s.promoteur
                //let tauxRetro   = doubleColumn(stmt, 8)                          // s."Taux rétro"
                
                let totalNbUC   = sqlite3_column_double(stmt, 8)
                let totalValo   = sqlite3_column_double(stmt, 9)
                let prmpMoyen   = sqlite3_column_double(stmt, 10)
                
                let noteE       = optionalTextColumn(stmt, 11)
                let noteS       = optionalTextColumn(stmt, 12)
                let noteG       = optionalTextColumn(stmt, 13)
                let srri        = intColumn(stmt, 14)
                // 🔍 Debug pour vérifier les données
                //                print("ISIN=\(codeIsin ?? "-"), noteE=\(noteE ?? "nil"), noteS=\(noteS ?? "nil"), noteG=\(noteG ?? "nil")")
                
                let support = SyntheseSupportClient(
                    id: id,
                    codeIsin: codeIsin,
                    nom: nom,
                    catGene: catGene,
                    catPrincipale: catPrincipale,
                    catDet: catDet,
                    catGeo: catGeo,
                    promoteur: promoteur,
                    tauxRetro: nil,
                    totalValo: totalValo,
                    totalNbUC: totalNbUC,
                    prmpMoyen: prmpMoyen,
                    poidsPourcent: 0,
                    noteE: noteE,
                    noteS: noteS,
                    noteG: noteG,
                    srri: srri
                )
                
                tempSupports.append(support)
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("❌ Erreur préparation getSyntheseSupportsGlobal: \(errmsg)")
        }
        
        sqlite3_finalize(stmt)
        
        // Calcul du poids %
        let totalValoGlobal = tempSupports.reduce(0) { $0 + $1.totalValo }
        if totalValoGlobal > 0 {
            result = tempSupports.map { sup in
                SyntheseSupportClient(
                    id: sup.id,
                    codeIsin: sup.codeIsin,
                    nom: sup.nom,
                    catGene: sup.catGene,
                    catPrincipale: sup.catPrincipale,
                    catDet: sup.catDet,
                    catGeo: sup.catGeo,
                    promoteur: sup.promoteur,
                    tauxRetro: sup.tauxRetro,
                    totalValo: sup.totalValo,
                    totalNbUC: sup.totalNbUC,
                    prmpMoyen: sup.prmpMoyen,
                    poidsPourcent: (sup.totalValo / totalValoGlobal) * 100.0,
                    noteE: sup.noteE,
                    noteS: sup.noteS,
                    noteG: sup.noteG,
                    srri: sup.srri  
                )
            }
        } else {
            result = tempSupports
        }
        
        return result
    }
}




extension DatabaseManager {
    func getDistributionSupportsGlobal(aLaDate dateFiltre: String, key: String) -> [DistributionItem] {
        guard openDatabase() else { return [] }
        
        // Liste blanche pour éviter l’injection
        let allowedKeys = ["cat_gene", "cat_principale", "cat_det", "cat_geo", "promoteur", "SRRI"]
        guard allowedKeys.contains(key) else { return [] }
        
        let query = """
        SELECT COALESCE(s.\(key), '(non renseigné)') AS label,
               SUM(h.valo) AS total
        FROM mariadb_historique_support_w h
        JOIN mariadb_support s ON CAST(h.id_support AS INTEGER) = s.id
        WHERE h.date = ?
        GROUP BY label
        ORDER BY total DESC;
        """
        
        var results: [DistributionItem] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, (dateFiltre as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let label = optionalTextColumn(stmt, 0) ?? "(non renseigné)"
                let total = doubleColumn(stmt, 1) ?? 0
                results.append(DistributionItem(label: label, value: total))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }

    func doubleColumn(_ stmt: OpaquePointer?, _ index: Int) -> Double? {
        guard sqlite3_column_type(stmt, Int32(index)) != SQLITE_NULL else { return nil }
        if let c = sqlite3_column_text(stmt, Int32(index)) {
            let str = String(cString: c).trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(str)   // nil si non convertible
        }
        return nil
    }
    
    
    private func runDonneesESGQuery(_ query: String) -> [DonneesESGEtendu] {
        guard openDatabase() else { return [] }
        var results: [DonneesESGEtendu] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                var col = 0
                results.append(DonneesESGEtendu(
                    isin: { let v = optionalTextColumn(stmt, col); col += 1; return v }(),
                    nom: { let v = optionalTextColumn(stmt, col); col += 1; return v }(),
                    wasteEfficiency: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    waterEfficiency: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    executivePay: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    boardIndependence: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    environmentalGood: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    socialGood: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    environmentalHarm: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    socialHarm: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    numberOfEmployees: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    avgPerEmployeeSpend: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    pctFemaleBoard: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    pctFemaleExec: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    ghgIntensityValue: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    biodiversity: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    emissionsToWater: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    hazardousWaste: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    violationsUNGC: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    processesUNGC: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    genderPayGap: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    boardGenderDiversity: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    controversialWeapons: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    scope1And2CarbonIntensity: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    scope3CarbonIntensity: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    carbonTrend: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    temperatureScore: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    exposureToFossilFuels: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    renewableEnergy: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    climateImpactRevenue: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    climateChangePositive: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    climateChangeNegative: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    climateChangeNet: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    naturalResourcePositive: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    naturalResourceNegative: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    naturalResourceNet: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    pollutionPositive: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    pollutionNegative: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    pollutionNet: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    avoidingWaterScarcity: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    sfdrBiodiversityPAI: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    noteE: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    noteS: { let v = doubleColumn(stmt, col); col += 1; return v }(),
                    noteG: { let v = doubleColumn(stmt, col); col += 1; return v }()
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
    
    func queryDonneesESG(isin: String? = nil, limit: Int = 10000) -> [DonneesESGEtendu] {
        var query = """
        SELECT Isin, nom, wasteEfficiency, waterEfficiency, executivePay, boardIndependence,
               environmentalGood, socialGood, environmentalHarm, socialHarm, numberOfEmployees,
               avgPerEmployeeSpend, pctFemaleBoard, pctFemaleExec, ghgIntensityValue, biodiversity,
               emissionsToWater, hazardousWaste, violationsUNGC, processesUNGC, genderPayGap,
               boardGenderDiversity, controversialWeapons, scope1And2CarbonIntensity, scope3CarbonIntensity,
               carbonTrend, temperatureScore, exposureToFossilFuels, renewableEnergy, climateImpactRevenue,
               climateChangePositive, climateChangeNegative, climateChangeNet, naturalResourcePositive,
               naturalResourceNegative, naturalResourceNet, pollutionPositive, pollutionNegative,
               pollutionNet, avoidingWaterScarcity, sfdrBiodiversityPAI, noteE, noteS, noteG
        FROM donnees_esg_etendu
        """
        //       let esg = DatabaseManager.shared.queryDonneesESG(isin: "FR0010315770") // par ex. un ISIN existant
        //       print(esg)
        
        if let isin = isin {
            query += " WHERE Isin = '\(isin)'"
        }
        query += " LIMIT \(limit);"
        return runDonneesESGQuery(query)
    }
    
}

struct RiskCategoryStats {
    let clients: Int
    let montant: Double
}

extension DatabaseManager {
    func fetchRiskStats() -> [String: RiskCategoryStats] {
        var result: [String: RiskCategoryStats] = [:]
        let query = """
            SELECT 
                CASE
                    WHEN srri_actuel = 0 THEN 'SRRI actuel manquant'
                    WHEN srri_actuel > srri_initial THEN 'Risque augmenté'
                    WHEN srri_actuel = srri_initial THEN 'Risque identique'
                    ELSE 'Risque réduit'
                END AS niveau_risque,
                COUNT(*) AS nb_clients,
                SUM(valo) AS montant_total
            FROM (
                SELECT c.id,
                       c.SRRI AS srri_initial,
                       CASE
                           WHEN h.volat IS NULL THEN 0
                           WHEN h.volat < 0.005 THEN 1
                           WHEN h.volat < 0.02  THEN 2
                           WHEN h.volat < 0.05  THEN 3
                           WHEN h.volat < 0.10  THEN 4
                           WHEN h.volat < 0.15  THEN 5
                           WHEN h.volat < 0.25  THEN 6
                           ELSE 7
                       END AS srri_actuel,
                       h.valo
                FROM mariadb_clients c
                LEFT JOIN (
                    SELECT a.id, a.volat, a.valo
                    FROM mariadb_historique_personne_w a
                    JOIN (
                        SELECT id, MAX(date) AS max_date
                        FROM mariadb_historique_personne_w
                        GROUP BY id
                    ) b ON a.id = b.id AND a.date = b.max_date
                ) h ON h.id = c.id
            ) t
            GROUP BY niveau_risque;
        """
        
        var statement: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let catCStr = sqlite3_column_text(statement, 0) {
                    let categorie = String(cString: catCStr)
                    let nbClients = Int(sqlite3_column_int(statement, 1))
                    let montant = sqlite3_column_double(statement, 2)
                    result[categorie] = RiskCategoryStats(clients: nbClients, montant: montant)
                }
            }
        }
        sqlite3_finalize(statement)
        
        return result
    }
}

extension DatabaseManager {
    func getDocumentsStats() -> [DocumentStats] {
        var results: [DocumentStats] = []
        
        // --- Contrôle chemin du fichier DB ---
        if let cPath = sqlite3_db_filename(db, "main") {
            print("DEBUG => DB ouvert: \(String(cString: cPath))")
        }
        
        // --- Contrôle du nombre de lignes dans Documents_client ---
        let checkSQL = "SELECT COUNT(*) FROM Documents_client;"
        var checkStmt: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, checkSQL, -1, &checkStmt, nil) == SQLITE_OK {
            if sqlite3_step(checkStmt) == SQLITE_ROW {
                let count = sqlite3_column_int(checkStmt, 0)
                print("DEBUG => nb lignes Documents_client = \(count)")
            }
        }
        sqlite3_finalize(checkStmt)
        
        // --- Requête principale ---
        let sql = """
        SELECT d.Documents AS Type_Document,
               SUM(CASE 
                     WHEN DATE(STRFTIME('%Y-%m-%d', dc.Date_creation, '+' || d."Obsolescence (années)" || ' years'))
                          <= DATE((SELECT MAX(date) FROM mariadb_historique_affaire_w))
                     THEN 1 ELSE 0 END) AS Obsoletes,
               SUM(CASE 
                     WHEN DATE(STRFTIME('%Y-%m-%d', dc.Date_creation, '+' || d."Obsolescence (années)" || ' years'))
                          > DATE((SELECT MAX(date) FROM mariadb_historique_affaire_w))
                     THEN 1 ELSE 0 END) AS Non_Obsoletes
        FROM Documents_client dc
        JOIN Documents d ON dc.Id_document_base = d."Id document base"
        GROUP BY d.Documents;
        """
        
        var stmt: OpaquePointer? = nil
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let type = String(cString: sqlite3_column_text(stmt, 0))
                
                var obsoletes = 0
                if let c1 = sqlite3_column_text(stmt, 1) {
                    obsoletes = Int(String(cString: c1)) ?? 0
                }
                
                var nonObsoletes = 0
                if let c2 = sqlite3_column_text(stmt, 2) {
                    nonObsoletes = Int(String(cString: c2)) ?? 0
                }
                
                results.append(DocumentStats(type: type, statut: "Obsolète", valeur: obsoletes))
                results.append(DocumentStats(type: type, statut: "Non obsolète", valeur: nonObsoletes))
                
                print("DEBUG => \(type) | Obso: \(obsoletes) | Non obso: \(nonObsoletes)")
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db))
            print("Erreur SQLite: \(errmsg)")
        }
        sqlite3_finalize(stmt)
        
        return results
    }
}

extension DatabaseManager {
    func getDocumentsClients(for clientId: Int) -> [DocumentClientItem] {
        var results: [DocumentClientItem] = []
        let query = """
            SELECT dc.Id_client,
                   dc.Nom_client,
                   dc.Id_document_base,
                   dc.Nom_Document,
                   dc.Date_creation,
                   dc.Date_obsolescence,
                   dc.Obsolescence AS Statut_obsolescence,
                   d.Documents,
                   d.Niveau,
                   d.[Obsolescence (années)],
                   d.Risque
            FROM Documents_client dc
            JOIN Documents d
              ON dc.Id_document_base = d.[Id document base]
            WHERE dc.Id_client = ?;
        """
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idClient = Int(sqlite3_column_int(stmt, 0))
                let nomClient = String(cString: sqlite3_column_text(stmt, 1))
                let idDocumentBase = Int(sqlite3_column_int(stmt, 2))
                let nomDocument = String(cString: sqlite3_column_text(stmt, 3))
                
                // Dates
                var dateCreation: Date? = nil
                if let cStr = sqlite3_column_text(stmt, 4) {
                    dateCreation = parseDate(String(cString: cStr))
                }
                var dateObsolescence: Date? = nil
                if let cStr = sqlite3_column_text(stmt, 5) {
                    dateObsolescence = parseDate(String(cString: cStr))
                }
                
                let statutObsolescence = sqlite3_column_text(stmt, 6).flatMap { String(cString: $0) }
                let documentRef = String(cString: sqlite3_column_text(stmt, 7))
                let niveau = sqlite3_column_text(stmt, 8).flatMap { String(cString: $0) }
                let obsoAnnees = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 9)) : nil
                let risque = sqlite3_column_text(stmt, 10).flatMap { String(cString: $0) }
                
                results.append(DocumentClientItem(
                    idClient: idClient,
                    nomClient: nomClient,
                    idDocumentBase: idDocumentBase,
                    nomDocument: nomDocument,
                    dateCreation: dateCreation,
                    dateObsolescence: dateObsolescence,
                    statutObsolescence: statutObsolescence,
                    documentRef: documentRef,
                    niveau: niveau,
                    obsolescenceAnnees: obsoAnnees,
                    risque: risque
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}
extension DatabaseManager {
    struct DocumentClientStats: Identifiable {
        let id = UUID()
        let idClient: Int
        let nomClient: String
        let idDocumentBase: Int
        let nomDocument: String
        let dateCreation: Date?
        let dateObsolescence: Date?
        let statut: String
        let documentRef: String
        let niveau: String?
        let obsolescenceAnnees: Int?
        let risque: String?
    }
    
    func getDocumentsClient(for clientId: Int) -> [DocumentClientStats] {
        guard openDatabase() else { return [] }
        let query = """
        SELECT dc.idClient,
               c.nom || ' ' || c.prenom AS nomClient,
               dc.idDocumentBase,
               dc.nomDocument,
               dc.dateCreation,
               dc.dateObsolescence,
               dc.statutObsolescence,
               d.documentRef,
               d.niveau,
               d.obsolescenceAnnees,
               d.risque
        FROM Documents_client dc
        LEFT JOIN mariadb_clients c ON c.id = dc.idClient
        LEFT JOIN Documents d ON d.id = dc.idDocumentBase
        WHERE dc.idClient = ?
        """
        
        var results: [DocumentClientStats] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let idClient = Int(sqlite3_column_int(stmt, 0))
                let nomClient = optionalTextColumn(stmt, 1) ?? "-"
                let idDocumentBase = Int(sqlite3_column_int(stmt, 2))
                let nomDocument = optionalTextColumn(stmt, 3) ?? "-"
                let dateCreation = optionalTextColumn(stmt, 4).flatMap { parseDate($0) }
                let dateObsolescence = optionalTextColumn(stmt, 5).flatMap { parseDate($0) }
                let statut = optionalTextColumn(stmt, 6) ?? "-"
                let documentRef = optionalTextColumn(stmt, 7) ?? "-"
                let niveau = optionalTextColumn(stmt, 8)
                let obsoAnnees = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 9)) : nil
                let risque = optionalTextColumn(stmt, 10)
                
                results.append(DocumentClientStats(
                    idClient: idClient,
                    nomClient: nomClient,
                    idDocumentBase: idDocumentBase,
                    nomDocument: nomDocument,
                    dateCreation: dateCreation,
                    dateObsolescence: dateObsolescence,
                    statut: statut,
                    documentRef: documentRef,
                    niveau: niveau,
                    obsolescenceAnnees: obsoAnnees,
                    risque: risque
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}

extension DatabaseManager {
    // Liste des noms d’allocations
    func queryAllocationNoms() -> [String] {
        let query = """
        SELECT DISTINCT nom
        FROM allocations
        WHERE nom IS NOT NULL AND nom <> ''
        ORDER BY nom;
        """
        
        //        print("⚙️ [SQL] Requête noms exécutée : \(query)")
        
        var results: [String] = []
        guard openDatabase() else {
            print("❌ Impossible d’ouvrir la base")
            return results
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            var rowCount = 0
            while sqlite3_step(stmt) == SQLITE_ROW {
                rowCount += 1
                if let cString = sqlite3_column_text(stmt, 0) {
                    let nom = String(cString: cString)
                    results.append(nom)
                    //                    print("🔹 Nom trouvé [\(rowCount)] : \(nom)")
                }
            }
            //            print("📊 Nombre total de noms récupérés : \(rowCount)")
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Erreur préparation requête noms : \(errorMessage)")
        }
        
        sqlite3_finalize(stmt)
        return results
    }
    
    // Séries de valeurs SICAV pour une allocation donnée
    func querySicavSeries(for nom: String) -> [(date: String, sicav: Double)] {
        let query = """
        SELECT id, nom, date, sicav
        FROM allocations
        WHERE nom = ?
        ORDER BY date ASC;
        """
        
        print("⚙️ [SQL] Requête série exécutée pour nom=\(nom)")
        
        var results: [(String, Double)] = []
        guard openDatabase() else {
            print("❌ Impossible d’ouvrir la base")
            return results
        }
        
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            // 👇 Conversion explicite String -> C-string
            sqlite3_bind_text(stmt, 1, (nom as NSString).utf8String, -1, nil)
            
            var rowCount = 0
            while sqlite3_step(stmt) == SQLITE_ROW {
                rowCount += 1
                if let cStringDate = sqlite3_column_text(stmt, 2),
                   let cStringNom  = sqlite3_column_text(stmt, 1) {
                    let date = String(cString: cStringDate)
                    let sicav = sqlite3_column_double(stmt, 3)
                    let realNom = String(cString: cStringNom)
                    results.append((date, sicav))
                    print("🔹 Ligne [\(rowCount)] : nom=\(realNom), date=\(date), sicav=\(sicav)")
                }
            }
            print("📊 Nombre total de points récupérés : \(rowCount)")
        } else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            print("❌ Erreur préparation requête séries : \(errorMessage)")
        }
        
        sqlite3_finalize(stmt)
        return results
    }
    
    // Série SICAV pour un client
    func queryClientSicav(for clientId: Int) -> [(date: String, sicav: Double)] {
        let query = """
            SELECT date, sicav
            FROM mariadb_historique_personne_
            WHERE id_personne = ?
            ORDER BY date ASC;
        """
        var result: [(String, Double)] = []
        guard openDatabase() else { return result }
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_int(stmt, 1, Int32(clientId))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let date = optionalTextColumn(stmt, 0) ?? ""
                let sicav = doubleColumn(stmt, 1) ?? 0.0
                result.append((date, sicav))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
    // Série SICAV pour une allocation
    func queryAllocationSicav(for nom: String) -> [(date: String, sicav: Double)] {
        let query = """
            SELECT date, sicav
            FROM allocations
            WHERE nom = ?
            ORDER BY date ASC;
        """
        var result: [(String, Double)] = []
        guard openDatabase() else { return result }
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, nom, -1, nil)
            while sqlite3_step(stmt) == SQLITE_ROW {
                let date = optionalTextColumn(stmt, 0) ?? ""
                let sicav = doubleColumn(stmt, 1) ?? 0.0
                result.append((date, sicav))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    func queryHistoriqueAffaireTuples() -> [(id: Int, date: String, sicav: Double)] {
        var result: [(Int, String, Double)] = []
        let query = """
            SELECT id, date, sicav
            FROM mariadb_historique_affaire_w
            ORDER BY date;
        """
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = Int(sqlite3_column_int(stmt, 0))
                let date = String(cString: sqlite3_column_text(stmt, 1))
                let sicav = sqlite3_column_double(stmt, 2)
                result.append((id, date, sicav))
            }
        }
        sqlite3_finalize(stmt)
        return result
    }
    
}

func testComparaisonSicav(clientId: Int, allocationNom: String) {
    // Série client
    let clientSeries = DatabaseManager.shared
        .queryHistoriquePersonne()
        .filter { $0.id == clientId }
        .compactMap { h -> (String, Double)? in
            guard let d = h.date, let v = h.sicav else { return nil }
            return (d, v)
        }
    
    print("📊 Client series count: \(clientSeries.count)")
    
    // Série allocation
    let allocSeries = DatabaseManager.shared
        .querySicavSeries(for: allocationNom)
        .map { ($0.date, $0.sicav) }
    
    print("📊 Allocation series count: \(allocSeries.count)")
    
    // Alignement
    let comparison = alignSeries(
        clientSeries: clientSeries,
        allocationSeries: allocSeries,
        allocationName: allocationNom
    )
    
    print("📊 Comparison count: \(comparison.count)")
    for point in comparison.prefix(10) {
        print("→ \(point.date) | \(point.source) : \(point.value)")
    }
}




extension DatabaseManager {
    func getMouvementsPourSupport(contratId: Int, supportId: Int) -> [MouvementAffaire] {
        guard openDatabase() else { return [] }
        let query = """
        SELECT date, mouvement
        FROM mariadb_historique_affaire_w
        WHERE id_source = ?
          AND id_support = ?
        ORDER BY date ASC
        """
        
        var results: [MouvementAffaire] = []
        var stmt: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            // id_source est un entier
            sqlite3_bind_int(stmt, 1, Int32(contratId))
            // id_support est un texte
            sqlite3_bind_text(stmt, 2, (String(supportId) as NSString).utf8String, -1, nil)
            
            while sqlite3_step(stmt) == SQLITE_ROW {
                let date = optionalDateColumn(stmt, 0)
                let mouvement = sqlite3_column_double(stmt, 1)
                results.append(MouvementAffaire(date: date, mouvement: mouvement))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}

extension DatabaseManager {
    func getRemunerationsGlobaleParAnnee() -> [RemunerationGlobale] {
        var results: [RemunerationGlobale] = []
        let query = """
        WITH hebdo AS (
            SELECT 
                strftime('%Y', h.date) AS annee,
                h.date,
                SUM(h.valo * s."Taux rétro") / 52.0 AS remuneration_retro_hebdo,
                SUM(h.valo) * 0.005 / 52.0          AS remuneration_assvie_hebdo,
                SUM(h.valo)                         AS encours_total_hebdo
            FROM mariadb_historique_support_w h
            JOIN mariadb_support s
                ON s.id = h.id_support
            JOIN mariadb_affaires a
                ON a.id = h.id_source
            JOIN mariadb_clients c
                ON c.id = a.id_personne
            GROUP BY annee, h.date
        )
        SELECT 
            annee,
            AVG(encours_total_hebdo)        AS encours_moyen_total,
            SUM(remuneration_retro_hebdo)   AS remuneration_retrocession,
            SUM(remuneration_assvie_hebdo)  AS remuneration_assurance_vie,
            SUM(remuneration_retro_hebdo) + SUM(remuneration_assvie_hebdo) AS remuneration_totale
        FROM hebdo
        GROUP BY annee
        ORDER BY annee;
        """
        
        guard openDatabase() else { return [] }
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let annee = optionalTextColumn(stmt, 0) ?? ""
                let encoursMoyen = sqlite3_column_double(stmt, 1)
                let retrocession = sqlite3_column_double(stmt, 2)
                let assuranceVie = sqlite3_column_double(stmt, 3)
                let total = sqlite3_column_double(stmt, 4)
                results.append(RemunerationGlobale(
                    annee: annee,
                    encoursMoyen: encoursMoyen,
                    retrocession: retrocession,
                    assuranceVie: assuranceVie,
                    total: total
                ))
            }
        }
        sqlite3_finalize(stmt)
        return results
    }
}



