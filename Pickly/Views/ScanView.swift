import SwiftUI
import UIKit

struct ScanView: View {
    @StateObject private var viewModel: ScanViewModel

    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    let isTabActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var isFrameBreathing = false
    @State private var isManualBarcodeEntryPresented = false
    @State private var requestContext: ProductRequestContext?

    init(
        productLookupService: any ProductLookupService,
        productService: any ProductService,
        savedStore: SavedProductsStore,
        preferences: UserPreferences,
        isTabActive: Bool = true
    ) {
        _viewModel = StateObject(
            wrappedValue: ScanViewModel(productLookupService: productLookupService)
        )
        self.productService = productService
        self.savedStore = savedStore
        self.preferences = preferences
        self.isTabActive = isTabActive
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PicklyContentHeader(
                title: "Scan barcode",
                subtitle: "Point your camera at a product barcode"
            )

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
        .padding(.top, PicklyLayout.rootTopPadding)
        .padding(.bottom, 16)
        .background(PicklyColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: isTabActive) {
            if isTabActive && scenePhase == .active {
                viewModel.requestCameraAccess()
            }
        }
        .sheet(isPresented: $isManualBarcodeEntryPresented) {
            ManualBarcodeEntrySheet { barcode in
                isManualBarcodeEntryPresented = false
                viewModel.submitManualBarcode(barcode)
            }
        }
        .sheet(item: $requestContext, onDismiss: {
            viewModel.scanAgain()
        }) { context in
            ProductRequestPlaceholderView(barcode: context.barcode)
        }
        .navigationDestination(item: $viewModel.scannedProduct) { product in
            ProductResultView(
                product: product,
                productService: productService,
                savedStore: savedStore,
                preferences: preferences,
                onScanAnotherProduct: viewModel.scanAnotherProduct
            )
        }
        .onChange(of: viewModel.scannedProduct) { oldValue, newValue in
            if oldValue != nil && newValue == nil {
                viewModel.handleProductResultClosed()
            }
        }
        .onChange(of: viewModel.state) { _, newState in
            playHaptic(for: newState)
        }
        .onChange(of: isTabActive) { _, isActive in
            viewModel.setScannerVisible(isActive && scenePhase == .active)
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.setScannerVisible(isTabActive && newPhase == .active)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .idle, .checkingPermission:
            ScanStandaloneStateView(
                systemImage: "camera.viewfinder",
                title: "Preparing scanner",
                message: "Checking camera access.",
                primaryTitle: nil,
                primarySystemImage: nil,
                primaryAction: nil,
                secondaryTitle: nil,
                secondaryAction: nil
            )
        case .permissionDenied:
            ScanStandaloneStateView(
                systemImage: "camera",
                title: "Camera access is off",
                message: "Enable camera access in Settings to scan product barcodes.",
                primaryTitle: "Enter barcode manually",
                primarySystemImage: "keyboard",
                primaryAction: { isManualBarcodeEntryPresented = true },
                secondaryTitle: "Open Settings",
                secondaryAction: openAppSettings
            )
        case .cameraUnavailable:
            ScanStandaloneStateView(
                systemImage: "camera.fill",
                title: "Camera unavailable",
                message: "Barcode scanning works best on a physical iPhone. You can still enter a barcode manually.",
                primaryTitle: "Enter barcode manually",
                primarySystemImage: "keyboard",
                primaryAction: { isManualBarcodeEntryPresented = true },
                secondaryTitle: "Try again",
                secondaryAction: viewModel.scanAgain
            )
        default:
            scannerFlow
        }
    }

    private var scannerFlow: some View {
        VStack(spacing: 14) {
            scannerPreview
                .layoutPriority(viewModel.state == .scanning ? 1 : 0)

            if viewModel.state == .scanning {
                Spacer(minLength: 0)

                ManualBarcodeTextLink {
                    isManualBarcodeEntryPresented = true
                }
                .padding(.bottom, 2)
            } else {
                statePanel
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
        }
    }

    private var scannerPreview: some View {
        let scannerCornerRadius: CGFloat = 28

        return ZStack {
            BarcodeScannerView(
                onCodeScanned: viewModel.handleScannedBarcode,
                onFailure: viewModel.handleScannerFailure,
                isActive: isTabActive && scenePhase == .active && viewModel.state == .scanning
            )
            .id(viewModel.scannerToken)
            .clipShape(RoundedRectangle(cornerRadius: scannerCornerRadius, style: .continuous))

            ScannerFrameOverlay(
                isActive: viewModel.state == .scanning,
                isBreathing: isFrameBreathing && !reduceMotion
            )

            cameraStatusOverlay
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(scannerAspectRatio, contentMode: .fit)
        .background(.black, in: RoundedRectangle(cornerRadius: scannerCornerRadius, style: .continuous))
        .accessibilityLabel("Barcode scanner")
        .onAppear {
            startFrameBreathing()
        }
    }

    @ViewBuilder
    private var cameraStatusOverlay: some View {
        switch viewModel.state {
        case .barcodeDetected, .loading:
            ScanCameraStatusOverlay(
                style: .loading,
                title: "Checking product...",
                subtitle: "This usually takes a moment"
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        case .productFound(let product):
            ScanCameraStatusOverlay(
                style: .success,
                title: "Product found",
                subtitle: product.name == "Unknown product" ? nil : product.name
            )
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var statePanel: some View {
        switch viewModel.state {
        case .scanning:
            EmptyView()
        case .unknownProduct(let barcode):
            ScanStateCard(
                systemImage: "barcode.viewfinder",
                title: "Product not found",
                message: "This barcode isn't in our data yet. You can request it with photos so it can be reviewed later.",
                barcode: barcode,
                primaryTitle: "Request product",
                primarySystemImage: "plus.viewfinder",
                primaryAction: {
                    requestContext = ProductRequestContext(barcode: barcode)
                },
                secondaryTitle: "Scan again",
                secondaryAction: viewModel.scanAgain,
                tertiaryTitle: "Enter barcode manually",
                tertiarySystemImage: "keyboard",
                tertiaryAction: { isManualBarcodeEntryPresented = true }
            )
        case .unreadable:
            ScanStateCard(
                systemImage: "barcode",
                title: "Barcode not clear",
                message: "Try again or enter it manually.",
                barcode: nil,
                primaryTitle: "Enter barcode manually",
                primarySystemImage: "keyboard",
                primaryAction: { isManualBarcodeEntryPresented = true },
                secondaryTitle: "Try again",
                secondaryAction: viewModel.scanAgain
            )
        case .failed(let message):
            ScanStateCard(
                systemImage: "wifi.exclamationmark",
                title: "Couldn't check this product",
                message: message,
                barcode: viewModel.lastDetectedBarcode,
                primaryTitle: "Try again",
                primarySystemImage: "arrow.clockwise",
                primaryAction: viewModel.retryLastBarcode,
                secondaryTitle: "Scan another",
                secondaryAction: viewModel.scanAnotherProduct
            )
        case .multipleMatches(let products):
            MultipleProductsFoundPanel(
                products: products,
                savedStore: savedStore,
                onSelect: viewModel.selectMatchedProduct
            )
        default:
            EmptyView()
        }
    }

    private var scannerAspectRatio: CGFloat {
        switch viewModel.state {
        case .unknownProduct, .unreadable, .failed, .multipleMatches:
            1.52
        default:
            1
        }
    }

    private func startFrameBreathing() {
        guard !reduceMotion else {
            isFrameBreathing = false
            return
        }

        isFrameBreathing = false

        withAnimation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true)) {
            isFrameBreathing = true
        }
    }

    private func playHaptic(for state: ScanViewModel.ScanState) {
        switch state {
        case .barcodeDetected:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .productFound:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .unknownProduct, .unreadable:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .failed:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        default:
            break
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(url)
    }
}

private struct ProductRequestContext: Identifiable {
    let barcode: String

    var id: String { barcode }
}

private struct ScannerFrameOverlay: View {
    let isActive: Bool
    let isBreathing: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(isActive ? 0.92 : 0.56), lineWidth: 2)
                .padding(24)
                .scaleEffect(isBreathing ? 1.018 : 1)
                .opacity(isBreathing ? 0.72 : 1)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)

            if isActive {
                Capsule()
                    .fill(.white.opacity(0.72))
                    .frame(height: 2)
                    .padding(.horizontal, 54)
                    .offset(y: isBreathing ? 58 : -58)
                    .shadow(color: PicklyColor.primary.opacity(0.32), radius: 10, x: 0, y: 0)

                VStack {
                    Spacer()

                    Text("Align the barcode inside the frame")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.36), in: Capsule())
                        .padding(.bottom, 26)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct ScanCameraStatusOverlay: View {
    enum Style {
        case loading
        case success
    }

    let style: Style
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(spacing: 12) {
            statusIcon

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: 260)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 22, x: 0, y: 12)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch style {
        case .loading:
            ProgressView()
                .controlSize(.large)
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(PicklyColor.primary)
        }
    }
}

private struct ManualBarcodeTextLink: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Enter barcode manually")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .underline()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityHint("Opens manual barcode entry.")
    }
}

private struct ScanStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    let barcode: String?
    let primaryTitle: String
    let primarySystemImage: String
    let primaryAction: () -> Void
    let secondaryTitle: String
    let secondaryAction: () -> Void
    let tertiaryTitle: String?
    let tertiarySystemImage: String?
    let tertiaryAction: (() -> Void)?

    init(
        systemImage: String,
        title: String,
        message: String,
        barcode: String?,
        primaryTitle: String,
        primarySystemImage: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String,
        secondaryAction: @escaping () -> Void,
        tertiaryTitle: String? = nil,
        tertiarySystemImage: String? = nil,
        tertiaryAction: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.barcode = barcode
        self.primaryTitle = primaryTitle
        self.primarySystemImage = primarySystemImage
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.tertiaryTitle = tertiaryTitle
        self.tertiarySystemImage = tertiarySystemImage
        self.tertiaryAction = tertiaryAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PicklyColor.primary)
                    .frame(width: 42, height: 42)
                    .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let barcode {
                BarcodeChip(barcode: barcode)
            }

            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PicklyColor.primary)
                .picklyProminentButtonForeground()

                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(PicklyColor.primary)

                if let tertiaryTitle, let tertiarySystemImage, let tertiaryAction {
                    Button(action: tertiaryAction) {
                        Label(tertiaryTitle, systemImage: tertiarySystemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(PicklyColor.primary)
                }
            }
            .controlSize(.large)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 22, stroke: PicklyColor.stroke.opacity(0.65))
        .accessibilityElement(children: .contain)
    }
}

private struct ScanStandaloneStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let primaryTitle: String?
    let primarySystemImage: String?
    let primaryAction: (() -> Void)?
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 10)

            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(PicklyColor.primary)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let primaryTitle, let primarySystemImage, let primaryAction {
                Button(action: primaryAction) {
                    Label(primaryTitle, systemImage: primarySystemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PicklyColor.primary)
                .picklyProminentButtonForeground()
                .controlSize(.large)
            }

            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(PicklyColor.primary)
                .controlSize(.large)
            }

            Spacer(minLength: 10)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .picklyCardSurface(cornerRadius: 24, stroke: PicklyColor.stroke.opacity(0.65))
    }
}

private struct MultipleProductsFoundPanel: View {
    let products: [Product]
    @ObservedObject var savedStore: SavedProductsStore
    let onSelect: (Product) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Multiple products found")
                    .font(.headline)

                Text("Choose the closest match.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ProductRowsCard(
                products: products,
                isSaved: { product in
                    savedStore.isSaved(product)
                },
                accessibilityLabel: accessibilityLabel(for:),
                onSelect: onSelect
            )
        }
    }

    private func accessibilityLabel(for product: Product) -> String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.name), \(product.brand), \(product.verdict), score \(score)"
        }

        return "\(product.name), \(product.brand), Limited data"
    }
}

private struct BarcodeChip: View {
    let barcode: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "number")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(barcode)
                .font(.footnote.monospacedDigit().weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PicklyColor.stroke.opacity(0.45), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Barcode \(barcode)")
    }
}

private struct ManualBarcodeEntrySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var barcode = ""

    let onSearch: (String) -> Void

    private var trimmedBarcode: String {
        barcode.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enter barcode")
                        .font(.title.bold())

                    Text("Type a valid 8, 12, 13, or 14 digit barcode from the product package.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("Barcode number", text: $barcode)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3.monospacedDigit())
                    .padding(14)
                    .background(PicklyColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PicklyColor.stroke, lineWidth: 1)
                    }
                    .accessibilityLabel("Barcode number")

                Button {
                    submit()
                } label: {
                    Text("Search")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(PicklyColor.primary)
                .picklyProminentButtonForeground()
                .controlSize(.large)
                .disabled(trimmedBarcode.isEmpty)

                Spacer()
            }
            .padding(20)
            .background(PicklyColor.background)
            .navigationTitle("Enter barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() {
        guard !trimmedBarcode.isEmpty else {
            return
        }

        onSearch(trimmedBarcode)
    }
}

#Preview {
    NavigationStack {
        ScanView(
            productLookupService: ProductCatalogStore.preview,
            productService: ProductCatalogStore.preview,
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
}
