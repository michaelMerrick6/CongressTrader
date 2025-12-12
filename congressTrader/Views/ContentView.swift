import SwiftUI

// 1. time range enum
enum TimeRange: String, CaseIterable {
    case sixMonths = "6M"
    case oneYear = "1Y"
    case fiveYears = "5Y"
    case max = "All"
}

struct ContentView: View {
    @StateObject var viewModel = TradeViewModel()
    
    @State private var feedLimit = 100
    @State private var searchLimit = 100
    
    var body: some View {
        if viewModel.isLoading {
            VStack(spacing: 15) {
                ProgressView().scaleEffect(1.5)
                Text("Loading Market Data...").font(.headline).foregroundColor(.secondary)
            }
        } else {
            TabView {
                // TAB 1: the feed
                NavigationStack {
                    List {
                        Section {
                            NavigationLink(destination: FollowingListView(viewModel: viewModel)) {
                                HStack {
                                    Text("\(viewModel.savedPoliticians.count + viewModel.savedTickers.count)").font(.headline).bold()
                                    Text("Following").foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Section(header: Text("Latest Activity")) {
                            if viewModel.savedTickers.isEmpty && viewModel.savedPoliticians.isEmpty {
                                VStack(alignment: .leading) {
                                    Text("Your Personal Feed").font(.headline)
                                    Text("Bookmark stocks or politicians in the Search tab to see their trades here.").font(.caption).foregroundColor(.secondary)
                                }.padding(.vertical, 8)
                            }
                            
                            ForEach(viewModel.personalizedFeed.prefix(feedLimit)) { trade in
                                TradeRow(trade: trade)
                                    .onAppear {
                                        if trade.id == viewModel.personalizedFeed.prefix(feedLimit).last?.id {
                                            if feedLimit < viewModel.personalizedFeed.count { feedLimit += 50 }
                                        }
                                    }
                            }
                        }
                    }
                    .navigationTitle("My Feed")
                    .listStyle(.plain)
                }
                .tabItem { Label("Feed", systemImage: "star.fill") }
                
                // tab 2: search. search polticains and stocks.
                NavigationStack {
                    VStack {
                        Picker("Type", selection: $viewModel.searchScope) {
                            Text("Politicians").tag(0); Text("Stocks").tag(1)
                        }
                        .pickerStyle(.segmented).padding(.horizontal).padding(.top)
                        .onChange(of: viewModel.searchScope) {
                            viewModel.updateSearch(text: viewModel.searchText)
                        }
                        List {
                            if viewModel.searchScope == 0 {
                                ForEach(viewModel.filteredTrades.prefix(searchLimit)) { trade in
                                    NavigationLink(destination: PoliticianDetailView(name: trade.representative, viewModel: viewModel)) {
                                        TradeRow(trade: trade)
                                    }
                                    .onAppear {
                                        if trade.id == viewModel.filteredTrades.prefix(searchLimit).last?.id {
                                            if searchLimit < viewModel.filteredTrades.count { searchLimit += 50 }
                                        }
                                    }
                                }
                            } else {
                                ForEach(viewModel.filteredStocks) { stock in
                                    NavigationLink(destination: StockDetailView(ticker: stock.ticker, company: stock.company, viewModel: viewModel)) {
                                        HStack {
                                            Text(stock.ticker).bold().frame(width: 60, alignment: .leading)
                                            Text(stock.company).font(.caption).foregroundColor(.secondary)
                                            Spacer()
                                            if viewModel.isTickerSaved(stock.ticker) {
                                                Image(systemName: "star.fill").foregroundColor(.yellow)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                    }
                    .navigationTitle("Search")
                    .searchable(text: $viewModel.searchText, prompt: "Search...")
                    .onChange(of: viewModel.searchText) { oldValue, newValue in
                        viewModel.updateSearch(text: newValue)
                    }                }
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                
                //  TAB 3: Leaderboards
                NavigationStack {
                    List {
                        ForEach(Array(viewModel.leaderboard.enumerated()), id: \.element.id) { index, person in
                            NavigationLink(destination: PoliticianDetailView(name: person.name, viewModel: viewModel)) {
                                HStack(spacing: 12) {
                                    Text("\(index + 1)").font(.headline).foregroundColor(.secondary).frame(width: 30, alignment: .leading)
                                    Text(person.name).lineLimit(1)
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text("+\(formatMoney(person.buyVolume))").font(.caption).bold().foregroundColor(.green)
                                        Text("-\(formatMoney(person.sellVolume))").font(.caption).foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .navigationTitle("Leaderboard")
                    .listStyle(.plain)
                }
                .tabItem { Label("Leaderboard", systemImage: "trophy.fill") }
            }
        }
    }
    
    func formatMoney(_ amount: Double) -> String {
        if amount > 1_000_000 { return String(format: "$%.1fM", amount / 1_000_000) }
        else if amount > 1_000 { return String(format: "$%.0fK", amount / 1_000) }
        return "$0"
    }
}
#Preview {
    ContentView()
}
