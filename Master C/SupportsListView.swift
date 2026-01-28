// SupportsListView.swift - Nouvelle vue pour les supports
import SwiftUI

struct SupportsListView: View {
    @State private var searchText: String = ""
    @State private var supports: [Support] = []
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            HStack {
                TextField("Rechercher un support…", text: $searchText, onCommit: load)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Filtrer") { load() }
            }
            .padding(.horizontal)
            
            if isLoading {
                ProgressView("Chargement…")
                    .padding()
            } else if supports.isEmpty {
                Text("Aucun support")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                List(supports, id: \.id) { s in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(s.nom ?? "(sans nom)")
                            .font(.headline)
                        if let isin = s.codeIsin {
                            Text("ISIN: \(isin)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        HStack(spacing: 16) {
                            if let cat = s.catPrincipale {
                                Text("Cat: \(cat)").font(.caption)
                            }
                            if let geo = s.catGeo {
                                Text("Geo: \(geo)").font(.caption)
                            }
                            if let taux = s.tauxRetro {
                                Text(String(format: "Rétro: %.2f%%", taux)).font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                
                .listStyle(.plain)
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Supports")
        .onAppear { load() }
    }
    
    private func load() {
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let data = DatabaseManager.shared.querySupports(filter: searchText, limit: 1000)
            DispatchQueue.main.async {
                self.supports = data
                self.isLoading = false
            }
        }
    }
}
