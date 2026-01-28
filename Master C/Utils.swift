//
//  Utils.swift
//  Master C
//
//  Created by Michel Camilleri on 14/08/2025.
//
import SwiftUI   // ✅ nécessaire si tu gardes Color ici
import Foundation

extension Date {
    func formatted(_ style: DateFormatter.Style = .short) -> String {
        DateFormatter.localizedString(from: self, dateStyle: style, timeStyle: .short)
    }
}
// DateFormatter pour les dates

let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}()
extension Date {
    func fridayOfWeek() -> Date {
        let calendar = Calendar(identifier: .gregorian)
        let weekday = calendar.component(.weekday, from: self)
        // ⚠️ dimanche = 1, lundi = 2, ..., samedi = 7
        let daysToAdd = (6 - weekday + 7) % 7  // 6 = vendredi
        return calendar.date(byAdding: .day, value: daysToAdd, to: self)!
    }
}
struct RisqueStats {
    var sous: (clients: Int, montant: Double)
    var aNiveau: (clients: Int, montant: Double)
    var auDessus: (clients: Int, montant: Double)
    var manquant: (clients: Int, montant: Double)   // <- ajouté
}
private func risqueIcon(categorie: String) -> (String, Color) {
    switch categorie {
    case "Sous le niveau":
        return ("snowflake", .blue)
    case "Dans le niveau":
        return ("hands.sparkles.fill", .green)
    default: // "Au-dessus du niveau"
        return ("flame.fill", .red)
    }
}

func formattedInt(_ value: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: value)) ?? "0"
}
// Ajoutez cette structure dans Utils.swift

let sqlDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()
func normalizeDateString(_ s: String) -> String? {
    if let d = DatabaseManager.shared.parseDate(s) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: d)
    }
    return nil
}
struct OrientationLock {
    static func lock(to orientation: UIInterfaceOrientationMask) {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: orientation))
        }
    }
}


struct ESGNoteConverter {
    // Définition des intervalles numériques pour chaque note
    private static let intervals: [(range: ClosedRange<Double>, note: String)] = [
        (0.00...0.50, "G"),
        (0.51...1.33, "F"),
        (1.34...2.00, "E"),
        (2.01...2.67, "D"),
        (2.68...3.33, "C"),
        (3.34...4.00, "B"),
        (4.01...4.67, "A")
    ]
    
    /// Convertit une lettre en valeur numérique médiane de son intervalle
    static func toValue(_ note: String?) -> Double? {
        guard let n = note else { return nil }
        if let interval = intervals.first(where: { $0.note == n }) {
            let mid = (interval.range.lowerBound + interval.range.upperBound) / 2.0
            return mid
        }
        return nil
    }
    
    /// Convertit une valeur numérique en note ESG selon son intervalle
    static func toNote(_ value: Double?) -> String {
        guard let v = value else { return "-" }
        if let match = intervals.first(where: { $0.range.contains(v) }) {
            return match.note
        }
        return "-"
    }
}

struct ESGNoteResult {
    let noteELettre: String
    let noteSLettre: String
    let noteGLettre: String
}

struct ESGUtils {
    /// Calcule les notes ESG pondérées pour un portefeuille
    /// - Parameter supports: liste de tuples (valeur, noteE, noteS, noteG en lettres)
    /// - Returns: notes ESG agrégées (en lettres)
    static func calculerNotesESGPonderees(
        supports: [(valeur: Double, noteE: String?, noteS: String?, noteG: String?)]
    ) -> ESGNoteResult {
        
        let totalValo = supports.reduce(0) { $0 + $1.valeur }
        guard totalValo > 0 else {
            return ESGNoteResult(noteELettre: "-", noteSLettre: "-", noteGLettre: "-")
        }
        
        // Conversion lettres → valeurs, calcul pondéré
        let noteEVal = supports.compactMap { s in
            ESGNoteConverter.toValue(s.noteE).map { $0 * (s.valeur / totalValo) }
        }.reduce(0, +)
        
        let noteSVal = supports.compactMap { s in
            ESGNoteConverter.toValue(s.noteS).map { $0 * (s.valeur / totalValo) }
        }.reduce(0, +)
        
        let noteGVal = supports.compactMap { s in
            ESGNoteConverter.toValue(s.noteG).map { $0 * (s.valeur / totalValo) }
        }.reduce(0, +)
        
        // Retour en lettres
        return ESGNoteResult(
            noteELettre: ESGNoteConverter.toNote(noteEVal),
            noteSLettre: ESGNoteConverter.toNote(noteSVal),
            noteGLettre: ESGNoteConverter.toNote(noteGVal)
        )
    }
}

func couleurPourNoteESG(_ note: String) -> Color {
    switch note {
    case "A", "B":
        return .green
    case "C", "D":
        return .orange
    case "E", "F", "G":
        return .red
    default:
        return .secondary
    }
}


// MARK: - Calcul de la note ESG globale (50/30/20)

func noteESGGlobale(
    noteE: String?,
    noteS: String?,
    noteG: String?
) -> String {
    // Conversion lettres -> valeurs
    let valE = ESGNoteConverter.toValue(noteE) ?? 0
    let valS = ESGNoteConverter.toValue(noteS) ?? 0
    let valG = ESGNoteConverter.toValue(noteG) ?? 0
    
    // Pondération
    let valeurGlobale = (0.5 * valE) + (0.3 * valS) + (0.2 * valG)
    
    // Conversion valeur -> lettre
    return ESGNoteConverter.toNote(valeurGlobale)
}

// MARK: - Commentaires automatiques

func commentairePourNoteESG(_ note: String) -> String {
    switch note {
    case "A": return "Excellente performance ESG"
    case "B": return "Bonne performance ESG"
    case "C": return "Correct, mais améliorable"
    case "D": return "Moyen, vigilance requise"
    case "E": return "Faible, actions nécessaires"
    case "F": return "Très faible, risque ESG élevé"
    case "G": return "Critique, non conforme"
    default:  return "Note ESG indisponible"
    }
}


struct ESGGaugeView: View {
    let noteE: String?
    let noteS: String?
    let noteG: String?
    let showComment: Bool
    
    private var noteGlobale: String {
        noteESGGlobale(noteE: noteE, noteS: noteS, noteG: noteG)
    }
    
    private var commentaire: String {
        commentairePourNoteESG(noteGlobale)
    }
    
    private var positionX: CGFloat {
        let value = ESGNoteConverter.toValue(noteGlobale) ?? 0
        return CGFloat(value / 4.67) * UIScreen.main.bounds.width * 0.9
        // ici : 4.67 = max médiane de A, 0.9 = marges
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note ESG : \(noteGlobale)")
                .font(.footnote)
                .bold()
                .foregroundColor(couleurPourNoteESG(noteGlobale))
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    LinearGradient(
                        gradient: Gradient(colors: [.green, .yellow, .orange, .red]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 6)
                    .cornerRadius(3)
                    
                    Circle()
                        .fill(couleurPourNoteESG(noteGlobale))
                        .frame(width: 12, height: 12)
                        .offset(x: (ESGNoteConverter.toValue(noteGlobale) ?? 0) / 4.67 * geo.size.width - 6)
                }
            }
            .frame(height: 16)
            
            if showComment {
                Text(commentaire)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ESGGaugeView(noteE: "B", noteS: "C", noteG: "A", showComment: true)
}


#Preview {
    VStack {
        ESGGaugeView(noteE: "B", noteS: "C", noteG: "A", showComment: true)   // avec commentaire
        ESGGaugeView(noteE: "E", noteS: "D", noteG: "C", showComment: false)  // sans commentaire
    }
}
