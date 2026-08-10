import SwiftUI

struct OnboardingResultPage: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var productVisible = false
    @State private var overviewVisible = false
    @State private var copyVisible = false
    @State private var displayedScore = 0
    @State private var scoreProgress = 0.0
    @State private var scanProgress: CGFloat = 0
    @State private var scannerIlluminated = true

    private let score = 48

    private var scorePalette: PicklyColor.StatusPalette {
        PicklyColor.ratingPalette(forScore: score)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 700
            let copySpacing: CGFloat = compact ? 24 : 36
            let sharedCTATopSpacing: CGFloat = 24
            let pageBottomSpacing = max(0, copySpacing - sharedCTATopSpacing)
            let productHeight: CGFloat = compact ? 292 : 344

            ScrollView {
                VStack(spacing: 0) {
                    productImage(height: productHeight)

                    resultOverview(compact: compact)
                        .padding(.top, compact ? 8 : 12)

                    copyBlock(compact: compact)
                        .padding(.top, copySpacing)
                }
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, compact ? 72 : 86)
                // The shared CTA already contributes 24 pt above its button.
                // Keep the visible copy-to-button gap equal to card-to-copy.
                .padding(.bottom, pageBottomSpacing)
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .task(id: isActive) {
            await runEntranceSequence()
        }
        .task(id: isActive) {
            await runScanLoop()
        }
    }

    private func productImage(height: CGFloat) -> some View {
        ZStack {
            Image("OnboardingProduct02ChocolateCereal")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.12),
                    radius: 11,
                    y: 7
                )

            ScannerOverlay(
                accent: PicklyColor.ratingGoodAccent,
                isIlluminated: scannerIlluminated,
                scanProgress: scanProgress
            )
            // The barcode sits in the lower part of the square source image.
            // Keep the scanner wider than the package and center its window on
            // that barcode instead of the image's geometric center.
            .frame(width: height * 0.96, height: height * 0.36)
            .offset(y: height * 0.30)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .opacity(productVisible ? 1 : 0)
        .scaleEffect(productVisible ? 1 : 0.96)
        .offset(y: reduceMotion || productVisible ? 0 : 12)
        .accessibilityLabel("Chocolate Cereal package")
    }

    @ViewBuilder
    private func resultOverview(compact: Bool) -> some View {
        ResultOverviewCardContent(
            title: "Worth comparing",
            subtitle: "Higher added sugar for an everyday cereal.",
            confidence: "Confidence: Medium",
            verdict: "Not great",
            displayedScore: displayedScore,
            scoreProgress: scoreProgress,
            scoreColor: scorePalette.accent,
            verdictFill: scorePalette.fill,
            verdictForeground: scorePalette.foreground,
            isLimitedData: false,
            scoreAccessibilityLabel: "Score 48 out of 100"
        )
        .resultPreviewSurface(padding: compact ? 22 : 24)
        .resultPreviewEntrance(isVisible: overviewVisible, reduceMotion: reduceMotion)
    }

    private func copyBlock(compact: Bool) -> some View {
        VStack(spacing: 8) {
            Text("Understand every result")
                .font(dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .title.bold())
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("See the facts behind every verdict.")
                .font(compact ? .body : .title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .opacity(copyVisible ? 1 : 0)
        .offset(y: reduceMotion || copyVisible ? 0 : 10)
    }

    @MainActor
    private func runEntranceSequence() async {
        resetEntranceState()

        guard isActive else { return }

        if reduceMotion {
            revealFinalState()
            return
        }

        withAnimation(.spring(response: 0.38, dampingFraction: 0.92)) {
            productVisible = true
        }

        guard await pause(milliseconds: 130) else { return }

        withAnimation(.spring(response: 0.40, dampingFraction: 0.94)) {
            overviewVisible = true
        }
        withAnimation(.easeOut(duration: 0.52)) {
            scoreProgress = Double(score) / 100
        }
        await animateDisplayedScore()

        guard isActive, !Task.isCancelled else { return }

        withAnimation(.easeOut(duration: 0.28)) {
            copyVisible = true
        }
    }

    @MainActor
    private func runScanLoop() async {
        guard isActive, !reduceMotion else {
            scanProgress = 0.5
            scannerIlluminated = true
            return
        }

        scannerIlluminated = true

        while isActive && !Task.isCancelled {
            withAnimation(.smooth(duration: 0.8)) {
                scanProgress = 1
            }

            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }

            withAnimation(.smooth(duration: 0.8)) {
                scanProgress = 0
            }

            do { try await Task.sleep(for: .milliseconds(800)) } catch { return }
        }
    }

    @MainActor
    private func resetEntranceState() {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            productVisible = false
            overviewVisible = false
            copyVisible = false
            displayedScore = 0
            scoreProgress = 0
        }
    }

    @MainActor
    private func revealFinalState() {
        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            productVisible = true
            overviewVisible = true
            copyVisible = true
            displayedScore = score
            scoreProgress = Double(score) / 100
        }
    }

    @MainActor
    private func animateDisplayedScore() async {
        let steps = 16

        for step in 1...steps {
            guard isActive, !Task.isCancelled else { return }

            displayedScore = Int((Double(score) * Double(step) / Double(steps)).rounded())

            guard await pause(milliseconds: 27) else { return }
        }
    }

    private func pause(milliseconds: Int) async -> Bool {
        do {
            try await Task.sleep(for: .milliseconds(milliseconds))
            return isActive && !Task.isCancelled
        } catch {
            return false
        }
    }
}

private extension View {
    func resultPreviewSurface(padding: CGFloat) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .picklyCardSurface(
                cornerRadius: 28,
                fill: PicklyColor.card,
                stroke: PicklyColor.stroke.opacity(0.42)
            )
    }

    func resultPreviewEntrance(isVisible: Bool, reduceMotion: Bool) -> some View {
        opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .offset(y: reduceMotion || isVisible ? 0 : 12)
    }
}

#Preview {
    OnboardingResultPage(isActive: true)
        .background(PicklyColor.background)
}
