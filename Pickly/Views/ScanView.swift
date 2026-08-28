import SwiftUI
import UIKit

struct ScanView: View {
    @StateObject private var viewModel: ScanViewModel

    let productService: any ProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences
    let isTabActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    @State private var isFrameBreathing = false
    @State private var isScanLineTraveling = false
    @State private var isScannerPresented = false
    @State private var isManualBarcodeEntryPresented = false

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
        Group {
            if usesCameraCanvas {
                scannerCanvas
            } else {
                standaloneContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(usesCameraCanvas ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(PicklyColor.background), for: .tabBar)
        .toolbarBackground(usesCameraCanvas ? .hidden : .visible, for: .tabBar)
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

    private var usesCameraCanvas: Bool {
        switch viewModel.state {
        case .idle, .checkingPermission, .permissionDenied, .cameraUnavailable:
            false
        default:
            true
        }
    }

    private var standaloneContent: some View {
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
            EmptyView()
        }
    }

    private var scannerCanvas: some View {
        GeometryReader { proxy in
            let scanFrame = scannerFrame(in: proxy.size)
            let canvasFrame = proxy.frame(in: .global)
            let scanFrameInGlobalCoordinates = scanFrame.offsetBy(
                dx: canvasFrame.minX,
                dy: canvasFrame.minY
            )

            ZStack {
                scannerPreview

                ScannerCameraBackdrop(
                    scanFrameInGlobalCoordinates: scanFrameInGlobalCoordinates,
                    reduceTransparency: reduceTransparency
                )
                .ignoresSafeArea(.container, edges: [.top, .bottom])

                ScannerTargetOverlay(
                    scanFrame: scanFrame,
                    isActive: viewModel.state == .scanning,
                    isBreathing: isFrameBreathing && !reduceMotion,
                    isScanLineTraveling: isScanLineTraveling && !reduceMotion,
                    reduceTransparency: reduceTransparency
                )
                .scaleEffect(isScannerPresented ? 1 : 0.975)
                .opacity(isScannerPresented ? 1 : 0)

                cameraStatusOverlay
                    .position(x: scanFrame.midX, y: scanFrame.midY)

                scannerChrome
            }
            .background(.black)
        }
        .background(.black)
        .accessibilityLabel("Barcode scanner")
        .onAppear {
            startScannerAnimations()
        }
        .onChange(of: reduceMotion) { _, _ in
            startScannerAnimations()
        }
    }

    private var scannerPreview: some View {
        BarcodeScannerView(
            onCodeScanned: viewModel.handleScannedBarcode,
            onFailure: viewModel.handleScannerFailure,
            isActive: isTabActive && scenePhase == .active && viewModel.state == .scanning
        )
        .id(viewModel.scannerToken)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.top, .bottom])
        .accessibilityHidden(true)
    }

    private var scannerChrome: some View {
        VStack(spacing: 16) {
            ScannerGlassHeader(reduceTransparency: reduceTransparency)

            Spacer(minLength: 0)

            if viewModel.state == .scanning {
                ManualBarcodeGlassButton(
                    reduceTransparency: reduceTransparency
                ) {
                    isManualBarcodeEntryPresented = true
                }
            } else {
                statePanel
                    .frame(maxHeight: 310)
            }
        }
        .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }

    private func scannerFrame(in size: CGSize) -> CGRect {
        let horizontalMargin: CGFloat = 30
        let width = min(max(size.width - (horizontalMargin * 2), 260), 356)
        let height = min(max(width * 0.66, 188), 238)

        return CGRect(
            x: (size.width - width) / 2,
            y: (size.height - height) / 2,
            width: width,
            height: height
        )
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
                message: "This barcode isn't in our data yet. Try another barcode or search by product name.",
                barcode: barcode,
                primaryTitle: "Scan again",
                primarySystemImage: "arrow.clockwise",
                primaryAction: viewModel.scanAgain,
                secondaryTitle: "Enter barcode manually",
                secondaryAction: { isManualBarcodeEntryPresented = true },
                tertiaryTitle: nil,
                tertiarySystemImage: nil,
                tertiaryAction: nil
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

    private func startScannerAnimations() {
        isScannerPresented = false
        isFrameBreathing = false
        isScanLineTraveling = false

        guard !reduceMotion else {
            isScannerPresented = true
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.94)) {
            isScannerPresented = true
        }

        withAnimation(.easeInOut(duration: 1.75).repeatForever(autoreverses: true)) {
            isFrameBreathing = true
        }

        withAnimation(.linear(duration: 2.15).repeatForever(autoreverses: true)) {
            isScanLineTraveling = true
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

private struct ScannerCameraBackdrop: View {
    let scanFrameInGlobalCoordinates: CGRect
    let reduceTransparency: Bool

    var body: some View {
        GeometryReader { proxy in
            let backdropFrame = proxy.frame(in: .global)
            let scanFrame = scanFrameInGlobalCoordinates.offsetBy(
                dx: -backdropFrame.minX,
                dy: -backdropFrame.minY
            )

            ZStack {
                if reduceTransparency {
                    ScannerCutoutShape(scanFrame: scanFrame)
                        .fill(
                            Color.black.opacity(0.74),
                            style: FillStyle(eoFill: true)
                        )
                } else {
                    ScannerCutoutShape(scanFrame: scanFrame)
                        .fill(
                            .ultraThinMaterial,
                            style: FillStyle(eoFill: true)
                        )
                }

                ScannerCutoutShape(scanFrame: scanFrame)
                    .fill(
                        Color.black.opacity(reduceTransparency ? 0.08 : 0.24),
                        style: FillStyle(eoFill: true)
                    )

                LinearGradient(
                    colors: [
                        .black.opacity(0.5),
                        .clear,
                        .clear,
                        .black.opacity(0.42)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScannerCutoutShape: Shape {
    let scanFrame: CGRect

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        path.addRoundedRect(
            in: scanFrame,
            cornerSize: CGSize(width: 30, height: 30)
        )
        return path
    }
}

private struct ScannerTargetOverlay: View {
    let scanFrame: CGRect
    let isActive: Bool
    let isBreathing: Bool
    let isScanLineTraveling: Bool
    let reduceTransparency: Bool

    var body: some View {
        ZStack {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(isActive ? 0.26 : 0.16), lineWidth: 1)

                ScannerCornerBrackets()
                    .stroke(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .padding(1)
                    .shadow(color: .black.opacity(0.28), radius: 10, x: 0, y: 5)
                    .shadow(color: PicklyColor.primary.opacity(isActive ? 0.28 : 0), radius: 12)
                    .scaleEffect(isBreathing ? 1.012 : 1)
                    .opacity(isBreathing ? 0.82 : 1)

                if isActive {
                    GeometryReader { proxy in
                        let travel = max((proxy.size.height - 54) / 2, 0)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.78),
                                        .white,
                                        .white.opacity(0.78),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 2)
                            .padding(.horizontal, 34)
                            .offset(y: isScanLineTraveling ? travel : -travel)
                            .shadow(color: PicklyColor.primary.opacity(0.48), radius: 10)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
            .frame(width: scanFrame.width, height: scanFrame.height)
            .position(x: scanFrame.midX, y: scanFrame.midY)

            if isActive {
                Text("Align the barcode inside the frame")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background {
                        Capsule()
                            .fill(
                                reduceTransparency
                                    ? AnyShapeStyle(Color.black.opacity(0.82))
                                    : AnyShapeStyle(.ultraThinMaterial)
                            )
                    }
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
                    .position(x: scanFrame.midX, y: scanFrame.maxY + 34)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ScannerCornerBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = min(28, min(rect.width, rect.height) * 0.14)
        let arm: CGFloat = min(52, min(rect.width, rect.height) * 0.28)
        var path = Path()

        path.move(to: CGPoint(x: 0, y: arm))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(
            to: CGPoint(x: radius, y: 0),
            control: CGPoint(x: 0, y: 0)
        )
        path.addLine(to: CGPoint(x: arm, y: 0))

        path.move(to: CGPoint(x: rect.maxX - arm, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: radius),
            control: CGPoint(x: rect.maxX, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: arm))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - arm))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - arm, y: rect.maxY))

        path.move(to: CGPoint(x: arm, y: rect.maxY))
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - radius),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - arm))

        return path
    }
}

private struct ScannerGlassHeader: View {
    let reduceTransparency: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Scan barcode")
                .font(.largeTitle.bold())
                .tracking(-0.7)
                .foregroundStyle(.white)

            Text("Point your camera at a product barcode")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    reduceTransparency
                        ? AnyShapeStyle(Color.black.opacity(0.82))
                        : AnyShapeStyle(.ultraThinMaterial)
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        .accessibilityElement(children: .combine)
    }
}

private struct ManualBarcodeGlassButton: View {
    let reduceTransparency: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Enter barcode manually", picklyIcon: "keyboard", iconSize: 17)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .frame(minHeight: 50)
                .frame(maxWidth: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background {
            Capsule()
                .fill(
                    reduceTransparency
                        ? AnyShapeStyle(Color.black.opacity(0.82))
                        : AnyShapeStyle(.regularMaterial)
                )
        }
        .overlay {
            Capsule()
                .stroke(.white.opacity(0.16), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 9)
        .accessibilityHint("Opens manual barcode entry.")
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
            PicklyIconImage(
                systemName: "checkmark.circle.fill",
                size: 38,
                scalesWithDynamicType: false
            )
                .foregroundStyle(PicklyColor.primary)
        }
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
                PicklyIconImage(systemName: systemImage, size: 21)
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
                    Label(primaryTitle, picklyIcon: primarySystemImage)
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
                        Label(tertiaryTitle, picklyIcon: tertiarySystemImage)
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

            PicklyIconImage(
                systemName: systemImage,
                size: 44,
                scalesWithDynamicType: false
            )
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
                    Label(primaryTitle, picklyIcon: primarySystemImage)
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
            return "\(product.name), \(product.brand), \(product.localizedVerdict), \(PicklyCopy.localized("score")) \(score)"
        }

        return PicklyCopy.format("%@, %@, %@", product.name, product.brand, PicklyCopy.localized("Limited data"))
    }
}

private struct BarcodeChip: View {
    let barcode: String

    var body: some View {
        HStack(spacing: 8) {
            PicklyIconImage(systemName: "number", size: 14)
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
    .environmentObject(SubscriptionStore(loadProducts: false))
}
