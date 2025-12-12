import SwiftUI

struct PoliticianDetailView: View {
    let name: String
    @ObservedObject var viewModel: TradeViewModel
    
    @State private var limit = 50
    @State private var selectedRange: TimeRange = .max
    
    var trades: [Trade] { viewModel.getTrades(for: name) }
    var stats: PoliticianStats? { viewModel.leaderboard.first(where: { $0.name == name }) }
    
    // Filtered Trades Logic
    var filteredTrades: [Trade] {
        let cutoff: Date
        switch selectedRange {
        case .sixMonths: cutoff = Calendar.current.date(byAdding: .month, value: -6, to: Date())!
        case .oneYear: cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
        case .fiveYears: cutoff = Calendar.current.date(byAdding: .year, value: -5, to: Date())!
        case .max: return trades
        }
        return trades.filter { $0.date >= cutoff }
    }
    
    var currentHoldings: [(ticker: String, amount: Double)] {
        var h: [String: Double] = [:]
        for t in trades {
            let v = parseAmount(t.amount)
            if t.type == .purchase { h[t.ticker, default: 0] += v } else if t.type == .sale { h[t.ticker, default: 0] -= v }
        }
        return h.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
    
    var body: some View {
        List {
            // 1. Header
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.largeTitle)
                        .bold()
                    
                    // Combine colored Party text with White Chamber text
                    (Text(getPartyName(name))
                        .foregroundColor(getPartyColor(name))
                     + Text(" • \(getChamberName(name))")
                        .foregroundColor(.white))
                        .font(.headline)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0))
                .padding(.top, 10)
            }
            
            // 2. Summary Card
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Volume").font(.caption).foregroundColor(.secondary)
                        if let s = stats {
                            HStack {
                                Text("Buy: \(formatMoney(s.buyVolume))").bold().foregroundColor(.green)
                                Text("Sell: \(formatMoney(s.sellVolume))").bold().foregroundColor(.red)
                            }
                        }
                    }
                    Spacer()
                    Button(action: { viewModel.togglePolitician(name) }) {
                        Image(systemName: viewModel.isPoliticianSaved(name) ? "star.fill" : "star").font(.title).foregroundColor(.yellow)
                    }.buttonStyle(PlainButtonStyle())
                }.padding(.vertical, 8)
            }
            
            // Top Holdings
            if !currentHoldings.isEmpty {
                Section(header: Text("Top 5 Holdings")) {
                    VStack(alignment: .leading, spacing: 12) {
                        let maxVal = currentHoldings.map { $0.amount }.max() ?? 1.0
                        ForEach(currentHoldings.prefix(5), id: \.ticker) { item in
                            HStack {
                                Text(item.ticker).font(.caption).bold().frame(width: 45, alignment: .leading)
                                GeometryReader { geo in
                                    RoundedRectangle(cornerRadius: 4).fill(Color.blue.gradient).frame(width: max(0, geo.size.width * (item.amount / maxVal)))
                                }.frame(height: 8)
                                Text(formatMoney(item.amount)).font(.caption).foregroundColor(.secondary).frame(width: 60, alignment: .trailing)
                            }
                        }
                    }.padding(.vertical, 8)
                }
            }
            
            // History
            Section(header: Text("History")) {
                VStack(spacing: 0) {
                    Picker("Range", selection: $selectedRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text("Showing \(filteredTrades.count) transactions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                }
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                
                if filteredTrades.isEmpty {
                    Text("No transactions in this period.").foregroundColor(.secondary)
                } else {
                    ForEach(filteredTrades.prefix(limit)) { trade in
                        TradeRow(trade: trade)
                            .onAppear {
                                if trade.id == filteredTrades.prefix(limit).last?.id {
                                    if limit < filteredTrades.count { limit += 50 }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .listStyle(.plain)
    }
    
    // --- HELPERS ---
    func formatMoney(_ amount: Double) -> String {
        if amount > 1_000_000 { return String(format: "$%.1fM", amount / 1_000_000) }
        return String(format: "$%.0fK", amount / 1_000)
    }
    func parseAmount(_ s: String) -> Double {
        let c = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let p = c.components(separatedBy: "-")
        if p.count == 2, let l = Double(p[0].trimmingCharacters(in: .whitespaces)), let h = Double(p[1].trimmingCharacters(in: .whitespaces)) { return (l + h)/2 }
        return Double(c) ?? 0.0
    }
    
    //  split helpers
    func getPartyName(_ name: String) -> String {
        guard let firstTrade = trades.first else { return "Congress" }
        let p = firstTrade.party.uppercased()
        return (p == "D" || p.contains("DEM")) ? "Democrat" : (p == "R" || p.contains("REP")) ? "Republican" : p
    }
    
    func getChamberName(_ name: String) -> String {
        guard let firstTrade = trades.first else { return "" }
        return firstTrade.chamber
    }
    
    func getPartyColor(_ name: String) -> Color {
        guard let firstTrade = trades.first else { return .secondary }
        let p = firstTrade.party.uppercased()
        if p == "D" || p.contains("DEM") { return Color.blue.opacity(0.7) }
        if p == "R" || p.contains("REP") { return Color.red.opacity(0.7) }
        return .secondary
    }
}
