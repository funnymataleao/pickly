import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct OnboardingCarouselPage: View {
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @State private var activeIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    @State private var loopResetToken = 0
    @State private var scanProgress: CGFloat = 0
    @State private var scannerIlluminated = false
    @State private var verdictVisible = false

    private let items = OnboardingCarouselItem.all

    var body: some View {
        GeometryReader { pageProxy in
            // Accessibility text sizes need a shorter visual stage so the
            // headline and supporting copy remain above the shared CTA.
            let topPadding: CGFloat = dynamicTypeSize.isAccessibilitySize ? 36 : 76
            // The action bar owns the bottom safe area. Keep only the same
            // 20pt visual inset used by the horizontal content margins.
            let bottomPadding: CGFloat = 20
            let contentHeight = max(0, pageProxy.size.height - topPadding - bottomPadding)
            let copyRegionHeight = max(0, contentHeight - carouselHeight)

            ScrollView {
                VStack(spacing: 0) {
                    carousel

                    copyBlock
                        .frame(
                            minHeight: dynamicTypeSize.isAccessibilitySize
                                ? nil
                                : copyRegionHeight
                        )
                        .padding(.top, dynamicTypeSize.isAccessibilitySize ? 20 : 0)
                }
                .frame(width: min(pageProxy.size.width, 520))
                .frame(width: pageProxy.size.width)
                .frame(minHeight: contentHeight, alignment: .top)
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
            }
            .frame(width: pageProxy.size.width, height: pageProxy.size.height)
            .scrollIndicators(.hidden)
        }
        .task(id: loopKey) {
            await runAutoplay(using: loopKey)
        }
        .task(id: scanKey) {
            await runScanFeedback(using: scanKey)
        }
    }

    private var copyBlock: some View {
        VStack(spacing: 12) {
            Text("Scan better.\nChoose smarter.")
                .font(
                    dynamicTypeSize.isAccessibilitySize
                        ? .title2.weight(.bold)
                        : .largeTitle.weight(.bold)
                )
                .multilineTextAlignment(.center)
                .lineSpacing(-2)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            Text("Scan once to understand what matters and find a better option.")
                .font(dynamicTypeSize.isAccessibilitySize ? .body : .title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
    }

    private var carousel: some View {
        GeometryReader { proxy in
            let productSize = min(min(proxy.size.width * 0.74, proxy.size.height * 0.84), 310)
            let cardSpacing = min(proxy.size.width * 0.54, 214)

            ZStack {
                ForEach(items.indices, id: \.self) { index in
                    let distance = circularDistance(from: activeIndex, to: index)

                    if abs(distance) <= 2 {
                        productView(
                            for: items[index],
                            distance: distance,
                            productSize: productSize,
                            cardSpacing: cardSpacing
                        )
                    }
                }

                ScannerOverlay(
                    accent: activeItem.verdict.accent,
                    isIlluminated: scannerIlluminated,
                    scanProgress: scanProgress
                )
                .frame(width: productSize * 0.78, height: productSize * 0.32)
                .offset(y: productSize * 0.24)
                .zIndex(20)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack {
                    Spacer()

                    VerdictBadge(
                        item: activeItem,
                        reduceTransparency: reduceTransparency
                    )
                    .opacity(verdictVisible && abs(dragOffset) < 10 ? 1 : 0)
                    .scaleEffect(verdictVisible && abs(dragOffset) < 10 ? 1 : 0.92)
                    .padding(.bottom, 4)
                }
                .zIndex(30)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .highPriorityGesture(carouselDrag(cardSpacing: cardSpacing))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(activeItem.name))
            .accessibilityValue(Text(activeItem.verdict.title))
            .accessibilityHint("Swipe left or right to preview another product.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    move(by: 1, userInitiated: true)
                case .decrement:
                    move(by: -1, userInitiated: true)
                @unknown default:
                    break
                }
            }
        }
        .frame(height: carouselHeight)
    }

    private var carouselHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 220 : 360
    }

    private func productView(
        for item: OnboardingCarouselItem,
        distance: Int,
        productSize: CGFloat,
        cardSpacing: CGFloat
    ) -> some View {
        let horizontalPosition = CGFloat(distance) * cardSpacing + dragOffset
        let progress = min(abs(horizontalPosition) / max(cardSpacing, 1), 1.5)
        let scale = max(0.68, 1 - progress * 0.18)
        let opacity = max(0.22, 1 - progress * 0.34)

        return Image(item.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: productSize, height: productSize)
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.11),
                radius: 10,
                y: 7
            )
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(x: horizontalPosition, y: -18 + progress * 8)
            .zIndex(Double(10 - abs(distance)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func carouselDrag(cardSpacing: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let projected = value.predictedEndTranslation.width
                let threshold = max(54, cardSpacing * 0.30)
                let step: Int

                if projected < -threshold {
                    step = 1
                } else if projected > threshold {
                    step = -1
                } else {
                    step = 0
                }

                if reduceMotion {
                    if step != 0 {
                        activeIndex = wrappedIndex(activeIndex + step)
                        playSelectionHaptic()
                    }
                    dragOffset = 0
                    isDragging = false
                } else {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                        if step != 0 {
                            activeIndex = wrappedIndex(activeIndex + step)
                        }
                        dragOffset = 0
                        isDragging = false
                    }

                    if step != 0 {
                        playSelectionHaptic()
                    }
                }

                loopResetToken += 1
            }
    }

    private var activeItem: OnboardingCarouselItem {
        items[activeIndex]
    }

    private var loopKey: CarouselLoopKey {
        CarouselLoopKey(
            enabled: isActive && scenePhase == .active && !reduceMotion && !isDragging,
            resetToken: loopResetToken
        )
    }

    private var scanKey: CarouselScanKey {
        CarouselScanKey(
            index: activeIndex,
            enabled: isActive,
            reduceMotion: reduceMotion
        )
    }

    private func runAutoplay(using key: CarouselLoopKey) async {
        guard key.enabled else { return }

        while !Task.isCancelled {
            do {
                try await Task.sleep(for: .milliseconds(2_800))
            } catch {
                return
            }

            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.90)) {
                activeIndex = wrappedIndex(activeIndex + 1)
            }
        }
    }

    private func runScanFeedback(using key: CarouselScanKey) async {
        guard key.enabled else {
            scanProgress = 0
            scannerIlluminated = false
            verdictVisible = false
            return
        }

        if key.reduceMotion {
            scanProgress = 0.5
            scannerIlluminated = true
            verdictVisible = true
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(80))
        } catch {
            return
        }

        withAnimation(.easeOut(duration: 0.16)) {
            scannerIlluminated = true
        }

        var shouldRevealVerdict = true

        while !Task.isCancelled {
            withAnimation(.smooth(duration: 0.68)) {
                scanProgress = 1
            }

            do {
                try await Task.sleep(for: .milliseconds(680))
            } catch {
                return
            }

            if shouldRevealVerdict {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                    verdictVisible = true
                }
                shouldRevealVerdict = false
            }

            withAnimation(.smooth(duration: 0.68)) {
                scanProgress = 0
            }

            do {
                try await Task.sleep(for: .milliseconds(680))
            } catch {
                return
            }
        }
    }

    private func move(by step: Int, userInitiated: Bool) {
        let update = {
            activeIndex = wrappedIndex(activeIndex + step)
            dragOffset = 0
        }

        if reduceMotion {
            update()
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.84)) {
                update()
            }
        }

        if userInitiated {
            playSelectionHaptic()
            loopResetToken += 1
        }
    }

    private func wrappedIndex(_ index: Int) -> Int {
        (index % items.count + items.count) % items.count
    }

    private func circularDistance(from activeIndex: Int, to index: Int) -> Int {
        var distance = index - activeIndex
        let half = items.count / 2

        if distance > half {
            distance -= items.count
        } else if distance < -half {
            distance += items.count
        }

        return distance
    }

    private func playSelectionHaptic() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

struct ScannerOverlay: View {
    let accent: Color
    let isIlluminated: Bool
    let scanProgress: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let normalizedProgress = min(max(scanProgress, 0), 1)
            let travelInset = proxy.size.height * 0.22
            let travelDistance = proxy.size.height - travelInset * 2
            let lineY = travelInset + travelDistance * normalizedProgress

            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.white.opacity(0.035))

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.82), lineWidth: 2)

                ScannerCorners()
                    .stroke(
                        accent,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                    )

                Capsule()
                    .fill(accent)
                    .frame(width: proxy.size.width * 0.76, height: isIlluminated ? 4 : 2)
                    .scaleEffect(x: isIlluminated ? 1 : 0.84)
                    .opacity(isIlluminated ? 1 : 0.52)
                    .shadow(
                        color: accent.opacity(isIlluminated ? 0.88 : 0.20),
                        radius: isIlluminated ? 10 : 2
                    )
                    .position(x: proxy.size.width / 2, y: lineY)
            }
        }
    }
}

struct ScannerCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 4
        let radius: CGFloat = 18
        let length = min(rect.width, rect.height) * 0.16
        var path = Path()

        path.move(to: CGPoint(x: inset, y: inset + length))
        path.addLine(to: CGPoint(x: inset, y: inset + radius))
        path.addQuadCurve(
            to: CGPoint(x: inset + radius, y: inset),
            control: CGPoint(x: inset, y: inset)
        )
        path.addLine(to: CGPoint(x: inset + length, y: inset))

        path.move(to: CGPoint(x: rect.maxX - inset - length, y: inset))
        path.addLine(to: CGPoint(x: rect.maxX - inset - radius, y: inset))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset, y: inset + radius),
            control: CGPoint(x: rect.maxX - inset, y: inset)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: inset + length))

        path.move(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset - length))
        path.addLine(to: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - inset - radius, y: rect.maxY - inset),
            control: CGPoint(x: rect.maxX - inset, y: rect.maxY - inset)
        )
        path.addLine(to: CGPoint(x: rect.maxX - inset - length, y: rect.maxY - inset))

        path.move(to: CGPoint(x: inset + length, y: rect.maxY - inset))
        path.addLine(to: CGPoint(x: inset + radius, y: rect.maxY - inset))
        path.addQuadCurve(
            to: CGPoint(x: inset, y: rect.maxY - inset - radius),
            control: CGPoint(x: inset, y: rect.maxY - inset)
        )
        path.addLine(to: CGPoint(x: inset, y: rect.maxY - inset - length))

        return path
    }
}

private struct VerdictBadge: View {
    let item: OnboardingCarouselItem
    let reduceTransparency: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 10) {
            PicklyIconImage(
                systemName: item.verdict.systemImage,
                size: 17,
                scalesWithDynamicType: false
            )
                .foregroundStyle(item.verdict.iconForeground)
                .frame(width: 36, height: 36)
                .background(item.verdict.accent, in: Circle())

            Text(item.verdict.title)
                .font(dynamicTypeSize.isAccessibilitySize ? .body.weight(.bold) : .headline.weight(.bold))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.vertical, 8)
        .padding(.leading, 9)
        .padding(.trailing, 18)
        .background {
            if reduceTransparency {
                Capsule()
                    .fill(item.verdict.fill)
            } else {
                Capsule()
                    .fill(.thinMaterial)
                    .overlay {
                        Capsule()
                            .fill(item.verdict.fill.opacity(0.78))
                    }
            }
        }
        .overlay {
            Capsule()
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: item.verdict.accent.opacity(0.20), radius: 14, y: 8)
    }
}

private struct CarouselLoopKey: Hashable {
    let enabled: Bool
    let resetToken: Int
}

private struct CarouselScanKey: Hashable {
    let index: Int
    let enabled: Bool
    let reduceMotion: Bool
}

private struct OnboardingCarouselItem: Identifiable {
    enum Verdict {
        case good
        case notGreat

        var title: LocalizedStringKey {
            switch self {
            case .good:
                "Good"
            case .notGreat:
                "Not great"
            }
        }

        var systemImage: String {
            switch self {
            case .good:
                "checkmark"
            case .notGreat:
                "minus"
            }
        }

        var accent: Color {
            switch self {
            case .good:
                PicklyColor.ratingGoodAccent
            case .notGreat:
                PicklyColor.ratingNotGreatAccent
            }
        }

        var fill: Color {
            switch self {
            case .good:
                PicklyColor.ratingGoodFill
            case .notGreat:
                PicklyColor.ratingNotGreatFill
            }
        }

        var iconForeground: Color {
            switch self {
            case .good:
                PicklyColor.statusGoodForeground
            case .notGreat:
                .white
            }
        }
    }

    let id: String
    let assetName: String
    let name: LocalizedStringKey
    let verdict: Verdict

    static let all: [OnboardingCarouselItem] = [
        OnboardingCarouselItem(
            id: "greek-yogurt",
            assetName: "OnboardingProduct01GreekYogurt",
            name: "Plain Greek Yogurt",
            verdict: .good
        ),
        OnboardingCarouselItem(
            id: "chocolate-cereal",
            assetName: "OnboardingProduct02ChocolateCereal",
            name: "Chocolate Cereal",
            verdict: .notGreat
        ),
        OnboardingCarouselItem(
            id: "rolled-oats",
            assetName: "OnboardingProduct03RolledOats",
            name: "Rolled Oats",
            verdict: .good
        ),
        OnboardingCarouselItem(
            id: "cheese-potato-chips",
            assetName: "OnboardingProduct04CheesePotatoChips",
            name: "Cheese Potato Chips",
            verdict: .notGreat
        ),
        OnboardingCarouselItem(
            id: "almond-drink",
            assetName: "OnboardingProduct05AlmondDrink",
            name: "Unsweetened Almond Drink",
            verdict: .good
        ),
        OnboardingCarouselItem(
            id: "fruit-gummies",
            assetName: "OnboardingProduct06FruitGummies",
            name: "Fruit Gummies",
            verdict: .notGreat
        ),
        OnboardingCarouselItem(
            id: "chickpea-pasta",
            assetName: "OnboardingProduct07ChickpeaPasta",
            name: "Chickpea Pasta",
            verdict: .good
        ),
        OnboardingCarouselItem(
            id: "cherry-soda",
            assetName: "OnboardingProduct08CherrySoda",
            name: "Cherry Soda",
            verdict: .notGreat
        )
    ]
}

#Preview {
    OnboardingCarouselPage(isActive: true)
        .background(PicklyColor.background)
}
