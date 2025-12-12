import SwiftUI

struct StockDetailView: View {
    let ticker: String
    let company: String
    @ObservedObject var viewModel: TradeViewModel
    
    @State private var limit = 50
    @State private var selectedRange: TimeRange = .max
    
    var trades: [Trade] { viewModel.getStockDetails(ticker: ticker) }
    
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
    
    var stats: (buys: Double, sells: Double) {
        var b: Double = 0, s: Double = 0
        for t in trades {
            let v = parseAmount(t.amount)
            if t.type == .purchase { b += v } else if t.type == .sale { s += v }
        }
        return (b, s)
    }
    
    var body: some View {
        List {
            Section {
                HStack {
                    VStack(alignment: .leading) { Text(ticker).font(.largeTitle).bold(); Text(company).font(.caption).foregroundColor(.secondary) }
                    Spacer()
                    Button(action: { viewModel.toggleTicker(ticker) }) {
                        Image(systemName: viewModel.isTickerSaved(ticker) ? "star.fill" : "star").font(.title).foregroundColor(.yellow)
                    }.buttonStyle(PlainButtonStyle())
                }.padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sentiment").font(.headline)
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            let total = stats.buys + stats.sells
                            if total > 0 {
                                Rectangle().fill(Color.green).frame(width: geo.size.width * (stats.buys / total))
                                Rectangle().fill(Color.red).frame(width: geo.size.width * (stats.sells / total))
                            }
                        }
                    }.frame(height: 25).cornerRadius(12)
                    HStack {
                        Text("Buys: \(formatMoney(stats.buys))").font(.caption).foregroundColor(.green).bold()
                        Spacer()
                        Text("Sells: \(formatMoney(stats.sells))").font(.caption).foregroundColor(.red).bold()
                    }
                }.padding(.vertical)
            }
            
            // HISTORY
            Section(header: Text("Transactions")) {
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
        .navigationTitle(ticker)
        .listStyle(.plain)
    }
    
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
}
