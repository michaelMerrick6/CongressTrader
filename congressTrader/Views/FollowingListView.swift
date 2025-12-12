import SwiftUI

struct FollowingListView: View {
    @ObservedObject var viewModel: TradeViewModel
    
    var body: some View {
        List {
            Section(header: Text("Politicians")) {
                if viewModel.savedPoliticians.isEmpty { Text("None").foregroundColor(.secondary) }
                ForEach(Array(viewModel.savedPoliticians).sorted(), id: \.self) { name in
                    NavigationLink(destination: PoliticianDetailView(name: name, viewModel: viewModel)) {
                        Text(name).font(.headline)
                    }
                }
            }
            Section(header: Text("Stocks")) {
                if viewModel.savedTickers.isEmpty { Text("None").foregroundColor(.secondary) }
                ForEach(Array(viewModel.savedTickers).sorted(), id: \.self) { ticker in
                    NavigationLink(destination: StockDetailView(ticker: ticker, company: viewModel.getCompanyName(ticker), viewModel: viewModel)) {
                        Text(ticker).font(.headline)
                    }
                }
            }
        }
        .navigationTitle("Following")
        .listStyle(.grouped)
    }
}
