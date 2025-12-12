
import SwiftUI

struct TradeRow: View {
    let trade: Trade
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(trade.ticker).bold()
                HStack {
                    Text(trade.representative); Text("•"); Text(trade.date, style: .date)
                }
                .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(trade.amount).font(.caption2)
                Text(trade.type.rawValue.prefix(1))
                    .bold().padding(6)
                    .background(trade.type == .purchase ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                    .foregroundColor(.white).clipShape(Circle())
            }
        }
    }
}
