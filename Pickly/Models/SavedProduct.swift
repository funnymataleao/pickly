import Foundation

struct SavedProduct: Identifiable, Hashable, Codable {
    let productId: String
    let date: Date

    var id: String { productId }
}
