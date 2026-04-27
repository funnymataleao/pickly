import Foundation

struct SavedProduct: Identifiable, Hashable {
    let productId: String
    let date: Date

    var id: String { productId }
}
