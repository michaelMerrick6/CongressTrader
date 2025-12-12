import Foundation

struct PoliticianStats: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let buyVolume: Double
    let sellVolume: Double
}

struct StockSummary: Identifiable {
    let id = UUID()
    let ticker: String
    let company: String
}

class TradeViewModel: ObservableObject {
    // UI Data
    @Published var filteredTrades: [Trade] = []
    @Published var filteredStocks: [StockSummary] = []
    @Published var leaderboard: [PoliticianStats] = []
    @Published var searchText: String = ""
    @Published var searchScope: Int = 0
    @Published var isLoading = true
    
    // Bookmarks
    @Published var savedTickers: Set<String> = []
    @Published var savedPoliticians: Set<String> = []
    
    // Internal Data
    private var allTrades: [Trade] = []
    private var uniqueStocks: [String: String] = [:]
    
    init() {
        loadBookmarks()
        loadData()
    }
    
    // HELPERS FOR FOLLOWING LIST. Remeber we want to
    func getCompanyName(_ ticker: String) -> String {
        return uniqueStocks[ticker] ?? "Unknown Company"
    }
    
    // main search logic. 
    func updateSearch(text: String) {
        self.searchText = text
        
        if searchText.isEmpty {
            self.filteredTrades = Array(allTrades.prefix(100))
            self.filteredStocks = Array(uniqueStocks.map { StockSummary(ticker: $0.key, company: $0.value) }.prefix(100))
            return
        }
        
        if searchScope == 0 {
            self.filteredTrades = allTrades.filter {
                $0.representative.localizedCaseInsensitiveContains(text) ||
                $0.ticker.localizedCaseInsensitiveContains(text)
            }
        } else {
            let stocks = uniqueStocks.map { StockSummary(ticker: $0.key, company: $0.value) }
            self.filteredStocks = stocks.filter {
                $0.ticker.localizedCaseInsensitiveContains(text) ||
                $0.company.localizedCaseInsensitiveContains(text)
            }.sorted { $0.ticker < $1.ticker }
        }
    }
    
    // feed logic. if no one is being followed show nothing, if the user is following someone only show followers.
        var personalizedFeed: [Trade] {
            // If the user isn't following anyone, return an EMPTY list
            if savedTickers.isEmpty && savedPoliticians.isEmpty {
                return []
            }
            
            // Otherwise, show only what they follow
            return allTrades.filter {
                savedTickers.contains($0.ticker) || savedPoliticians.contains($0.representative)
            }
        }
    
    func getTrades(for person: String) -> [Trade] {
        return allTrades.filter { $0.representative == person }
    }
    
    func getStockDetails(ticker: String) -> [Trade] {
        return allTrades.filter { $0.ticker == ticker }
    }
    
    // --- BOOKMARKING ---
    func toggleTicker(_ ticker: String) {
        if savedTickers.contains(ticker) { savedTickers.remove(ticker) } else { savedTickers.insert(ticker) }
        saveBookmarks()
    }
    func togglePolitician(_ name: String) {
        if savedPoliticians.contains(name) { savedPoliticians.remove(name) } else { savedPoliticians.insert(name) }
        saveBookmarks()
    }
    func isTickerSaved(_ ticker: String) -> Bool { savedTickers.contains(ticker) }
    func isPoliticianSaved(_ name: String) -> Bool { savedPoliticians.contains(name) }
    
    private func saveBookmarks() {
        UserDefaults.standard.set(Array(savedTickers), forKey: "savedTickers")
        UserDefaults.standard.set(Array(savedPoliticians), forKey: "savedPoliticians")
    }
    private func loadBookmarks() {
        if let t = UserDefaults.standard.array(forKey: "savedTickers") as? [String] { savedTickers = Set(t) }
        if let p = UserDefaults.standard.array(forKey: "savedPoliticians") as? [String] { savedPoliticians = Set(p) }
    }

    // Data loader that we load from the csv Trades. In the future wed move this to a json and put in a github link, and call it. But for now the csv wworks fine.
    func loadData() {
        guard let filepath = Bundle.main.path(forResource: "trades", ofType: "csv") else { return }
        
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                let content = try String(contentsOfFile: filepath, encoding: .utf8)
                let rows = content.components(separatedBy: "\n")
                
                var tempTrades: [Trade] = []
                var statsMap: [String: (buy: Double, sell: Double)] = [:]
                var stockMap: [String: String] = [:]
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                
                // Process EVERY row
                for row in rows.dropFirst() {
                    if row.count < 5 { continue }
                    let cols = self.smartSplit(line: row)
                    
                    if cols.count > 12 {
                        let ticker = self.clean(cols[0])
                        let company = self.clean(cols[2])
                        let dateString = self.clean(cols[3])
                        let typeString = self.clean(cols[4])
                        let amountStr = self.clean(cols[5])
                        let rawName = self.clean(cols[9])
                        let party = self.clean(cols[12])
                        let chamber = self.clean(cols[14])
                        let name = self.normalizeName(rawName)
                        
                        if !name.isEmpty {
                            let date = formatter.date(from: dateString) ?? Date()
                            
                            var type: Trade.TradeType = .unknown
                            let lowerType = typeString.lowercased()
                            if lowerType.contains("purchase") { type = .purchase }
                            else if lowerType.contains("sale") { type = .sale }
                            else if lowerType.contains("exchange") { type = .exchange }
                            
                            let trade = Trade(ticker: ticker, company: company, date: date, type: type, amount: amountStr, representative: name, party: party, chamber: chamber)
                            tempTrades.append(trade)
                            
                            let val = self.parseAmount(amountStr)
                            
                            // Only update stats if we got a valid parsed amount
                            if val > 0 {
                                var stat = statsMap[name] ?? (buy: 0.0, sell: 0.0)
                                if type == .purchase { stat.buy += val } else if type == .sale { stat.sell += val }
                                statsMap[name] = stat
                            }
                            
                            stockMap[ticker] = company
                        }
                    }
                }
                
                let leaders = statsMap.map { key, value in
                    PoliticianStats(name: key, buyVolume: value.buy, sellVolume: value.sell)
                }.sorted { $0.buyVolume > $1.buyVolume }
                
                DispatchQueue.main.async {
                    self.allTrades = tempTrades
                    self.filteredTrades = tempTrades
                    self.leaderboard = leaders
                    self.uniqueStocks = stockMap
                    self.filteredStocks = Array(stockMap.map { StockSummary(ticker: $0.key, company: $0.value) }.prefix(100))
                    self.isLoading = false
                }
            } catch { print(error) }
        }
    }
    
    // helpers.
    func smartSplit(line: String) -> [String] {
        var result: [String] = []; var current = ""; var quote = false
        for char in line {
            if char == "\"" { quote.toggle() }
            else if char == "," && !quote { result.append(current); current = "" }
            else { current.append(char) }
        }
        result.append(current)
        return result
    }
    //The mr mrs and these titles kept messing with the data. So we are going to remove those. Also was having issues with pelosi and greene. So we are normalizing those as well.
    func clean(_ s: String) -> String { s.replacingOccurrences(of: "\"", with: "").trimmingCharacters(in: .whitespacesAndNewlines) }
    func normalizeName(_ name: String) -> String {
        var n = clean(name)
        let titles = ["Mrs. ", "Mr. ", "Ms. ", "Dr. ", "Hon. ", "Rep. ", "Sen. "]
        for t in titles { if n.hasPrefix(t) { n = String(n.dropFirst(t.count)) } }
        if n.contains(",") { let p = n.components(separatedBy: ","); if p.count >= 2 { n = "\(p[1]) \(p[0])".trimmingCharacters(in: .whitespaces) } }
        if n.lowercased().contains("pelosi") { return "Nancy Pelosi" }
        if n.lowercased().contains("taylor greene") { return "Marjorie Taylor Greene" }
        if n.lowercased().contains("mccaul") { return "Michael T. McCaul" } // Normalize McCaul
        return n
    }
    
    // Parser to help with amount.
    func parseAmount(_ s: String) -> Double {
        // Enforce range check: Valid trades usually come in ranges "$1,001 - $15,000"
        // Single large numbers are often Filing IDs or garbage data.
        if !s.contains("-") { return 0.0 }
        
        let c = s.replacingOccurrences(of: "$", with: "").replacingOccurrences(of: ",", with: "")
        let p = c.components(separatedBy: "-")
        if p.count == 2,
           let l = Double(p[0].trimmingCharacters(in: .whitespaces)),
           let h = Double(p[1].trimmingCharacters(in: .whitespaces)) {
            
            // Extra sanity check: If the upper bound is absurdly high (e.g. > 50M for a single trade bracket), treat as error.
            if h > 50_000_000 { return 0.0 }
            
            return (l + h)/2
        }
        return 0.0
    }
}
