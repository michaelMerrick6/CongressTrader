
import Foundation

struct Trade: Identifiable, Decodable {
    var id = UUID()
    let ticker: String
    let company: String
    let date: Date
    let type: TradeType
    let amount: String
    let representative: String
    let party: String
    let chamber: String
    
    enum TradeType: String, Decodable {
        case purchase = "Purchase"
        case sale = "Sale"
        case exchange = "Exchange"
        case unknown
    }
}
