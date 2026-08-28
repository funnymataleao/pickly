import Foundation

struct ProductRequestDraft: Equatable {
    let barcode: String?
    let name: String?
    let brand: String?
    let note: String?

    init(barcode: String, name: String, brand: String, note: String) throws {
        let trimmedBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        let normalizedBarcode: String?
        if trimmedBarcode.isEmpty {
            normalizedBarcode = nil
        } else if let barcode = BarcodeValidator.normalize(trimmedBarcode) {
            normalizedBarcode = barcode
        } else {
            throw ProductRequestError.invalidBarcode
        }

        guard normalizedBarcode != nil || !trimmedName.isEmpty else {
            throw ProductRequestError.missingProductDetails
        }

        self.barcode = normalizedBarcode
        self.name = trimmedName.isEmpty ? nil : trimmedName
        self.brand = trimmedBrand.isEmpty ? nil : trimmedBrand
        self.note = trimmedNote.isEmpty ? nil : trimmedNote
    }
}

enum ProductRequestError: LocalizedError, Equatable {
    case missingConfiguration
    case missingProductDetails
    case invalidBarcode
    case unauthorized
    case requestFailed

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return PicklyCopy.localized("Product requests are unavailable right now.")
        case .missingProductDetails:
            return PicklyCopy.localized("Add a product name or a valid barcode.")
        case .invalidBarcode:
            return PicklyCopy.localized("Enter a valid 8, 12, 13, or 14 digit barcode.")
        case .unauthorized:
            return PicklyCopy.localized("Your session expired. Sign in again and retry.")
        case .requestFailed:
            return PicklyCopy.localized("The request could not be sent. Please try again.")
        }
    }
}

struct ProductRequestService {
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func submit(_ draft: ProductRequestDraft, session: AuthSession) async throws {
        guard
            let baseURL = PicklyAPIConfiguration.baseURL
        else {
            throw ProductRequestError.missingConfiguration
        }

        let payload = Payload(
            barcode: draft.barcode,
            name: draft.name,
            brand: draft.brand,
            note: draft.note
        )

        var request = URLRequest(url: baseURL.appending(path: "v1/product-requests"))
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(payload)

        let response: URLResponse
        do {
            (_, response) = try await urlSession.data(for: request)
        } catch {
            throw ProductRequestError.requestFailed
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProductRequestError.requestFailed
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw ProductRequestError.unauthorized
        default:
            throw ProductRequestError.requestFailed
        }
    }
}

private extension ProductRequestService {
    struct Payload: Encodable {
        let barcode: String?
        let name: String?
        let brand: String?
        let note: String?

    }
}
