import SwiftUI
import Foundation

struct DocumentClientItem: Identifiable {
    let id = UUID()
    
    // Champs Documents_client
    let idClient: Int
    let nomClient: String
    let idDocumentBase: Int
    let nomDocument: String
    let dateCreation: Date?
    let dateObsolescence: Date?
    let statutObsolescence: String?
    
    // Champs Documents
    let documentRef: String
    let niveau: String?
    let obsolescenceAnnees: Int?
    let risque: String?
}

struct DocumentsClientView: View {
    let clientId: Int
    @State private var documents: [DocumentClientItem] = []
    @State private var showObsoletes = false
    @State private var showActifs = false
    
    private var obsoletes: [DocumentClientItem] {
        documents.filter { $0.statutObsolescence == "Oui" }
    }
    
    private var actifs: [DocumentClientItem] {
        documents.filter { $0.statutObsolescence == "Non" }
    }
    
    var body: some View {
        List {
            Section(header: Text("📄 Documents")) {
                DisclosureGroup(isExpanded: $showObsoletes) {
                    if obsoletes.isEmpty {
                        Text("Aucun document obsolète")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(obsoletes) { doc in
                            DocumentRow(doc: doc, color: .red)
                        }
                    }
                } label: {
                    Label("Documents obsolètes", systemImage: "xmark.octagon.fill")
                        .foregroundColor(.red)
                }
                
                DisclosureGroup(isExpanded: $showActifs) {
                    if actifs.isEmpty {
                        Text("Aucun document à jour")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(actifs) { doc in
                            DocumentRow(doc: doc, color: .green)
                        }
                    }
                } label: {
                    Label("Documents à jour", systemImage: "checkmark.seal.fill")
                        .foregroundColor(.green)
                }
            }
        }
        .navigationTitle("Documents client")
        .onAppear {
            let docs = DatabaseManager.shared.getDocumentsClients(for: clientId)
            print("DEBUG => \(docs.count) documents trouvés pour clientId=\(clientId)")
            documents = docs
        }
    }
}

// Une ligne de document avec un indicateur coloré
struct DocumentRow: View {
    let doc: DocumentClientItem
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 14, height: 14)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(doc.nomDocument).font(.headline)
                Text("Type : \(doc.niveau ?? "-")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let d = doc.dateCreation {
                    Text("Créé le \(dateFormatter.string(from: d))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let niveau = doc.niveau {
                    Text("Niveau : \(niveau)").font(.caption)
                }
                if let risque = doc.risque {
                    Text("Risque : \(risque)").font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
