import AVFoundation
import Foundation
import Combine

@MainActor
final class ScanViewModel: ObservableObject {
    enum ScanState: Equatable {
        case idle
        case checkingPermission
        case scanning
        case barcodeDetected(String)
        case loading(String)
        case productFound(Product)
        case multipleMatches([Product])
        case unknownProduct(String)
        case unreadable
        case failed(String)
        case permissionDenied
        case cameraUnavailable
    }

    @Published private(set) var state: ScanState = .idle
    @Published var scannedProduct: Product?
    @Published private(set) var scannerToken = UUID()
    @Published private(set) var lastDetectedBarcode: String?

    private let productLookupService: any ProductLookupService
    private var lookupTask: Task<Void, Never>?
    private var permissionTask: Task<Void, Never>?
    private var isLookupInProgress = false
    private let successFeedbackDelay: UInt64 = 650_000_000

    init(productLookupService: any ProductLookupService) {
        self.productLookupService = productLookupService
    }

    func requestCameraAccess() {
        guard state == .idle || state == .checkingPermission else {
            return
        }

        state = .checkingPermission

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            state = .scanning
        case .notDetermined:
            permissionTask?.cancel()
            permissionTask = Task {
                let granted = await AVCaptureDevice.requestAccess(for: .video)
                guard !Task.isCancelled else { return }
                state = granted ? .scanning : .permissionDenied
            }
        case .denied, .restricted:
            state = .permissionDenied
        @unknown default:
            state = .permissionDenied
        }
    }

    func setScannerVisible(_ isVisible: Bool) {
        if isVisible {
            requestCameraAccess()
        } else {
            pauseScanner()
        }
    }

    func pauseScanner() {
        permissionTask?.cancel()
        lookupTask?.cancel()
        isLookupInProgress = false

        guard scannedProduct == nil else {
            return
        }

        state = .idle
        scannerToken = UUID()
    }

    func handleScannedBarcode(_ barcode: String) {
        guard state == .scanning else {
            return
        }

        startLookup(for: barcode)
    }

    func submitManualBarcode(_ barcode: String) {
        startLookup(for: barcode)
    }

    func retryLastBarcode() {
        guard let lastDetectedBarcode else {
            scanAnotherProduct()
            return
        }

        startLookup(for: lastDetectedBarcode)
    }

    func selectMatchedProduct(_ product: Product) {
        lookupTask?.cancel()
        isLookupInProgress = false
        showProductFound(product)
    }

    func handleProductResultClosed() {
        guard scannedProduct == nil else {
            return
        }

        resetScanner()
    }

    func scanAnotherProduct() {
        scannedProduct = nil
        lastDetectedBarcode = nil
        lookupTask?.cancel()
        isLookupInProgress = false
        resetScanner()
    }

    func scanAgain() {
        lookupTask?.cancel()
        isLookupInProgress = false
        resetScanner()
    }

    func handleScannerFailure(_ error: BarcodeScannerView.ScannerError) {
        guard state == .scanning else {
            return
        }

        switch error {
        case .cameraUnavailable:
            state = .cameraUnavailable
        case .configurationFailed:
            state = .unreadable
        }
    }

    private func startLookup(for rawBarcode: String) {
        guard let barcode = BarcodeValidator.normalize(rawBarcode) else {
            state = .unreadable
            return
        }

        guard !isLookupInProgress else {
            return
        }

        isLookupInProgress = true
        lastDetectedBarcode = barcode
        state = .barcodeDetected(barcode)
        lookupTask?.cancel()

        lookupTask = Task { [productLookupService] in
            try? await Task.sleep(nanoseconds: 120_000_000)

            guard !Task.isCancelled else {
                return
            }

            state = .loading(barcode)

            do {
                let product = try await productLookupService.fetchProduct(barcode: barcode)

                guard !Task.isCancelled else {
                    return
                }

                isLookupInProgress = false

                if shouldTreatAsUnknown(product) {
                    state = .unknownProduct(barcode)
                } else {
                    showProductFound(product)
                }
            } catch OpenFoodFactsService.ServiceError.productNotFound {
                guard !Task.isCancelled else {
                    return
                }

                isLookupInProgress = false
                state = .unknownProduct(barcode)
            } catch ProductCatalogStore.CatalogError.notFound {
                guard !Task.isCancelled else {
                    return
                }

                isLookupInProgress = false
                state = .unknownProduct(barcode)
            } catch OpenFoodFactsService.ServiceError.invalidBarcode {
                guard !Task.isCancelled else {
                    return
                }

                isLookupInProgress = false
                state = .unreadable
            } catch {
                guard !Task.isCancelled else {
                    return
                }

                isLookupInProgress = false
                state = .failed("Please check your connection and try again.")
            }
        }
    }

    private func showProductFound(_ product: Product) {
        state = .productFound(product)

        lookupTask = Task {
            try? await Task.sleep(nanoseconds: successFeedbackDelay)

            guard !Task.isCancelled else {
                return
            }

            scannedProduct = product
        }
    }

    private func shouldTreatAsUnknown(_ product: Product) -> Bool {
        product.name == "Unknown product"
            && product.ingredients.isEmpty
            && product.nutrition.knownFieldCount == 0
            && product.imageURL == nil
    }

    private func resetScanner() {
        state = .scanning
        scannerToken = UUID()
    }
}
