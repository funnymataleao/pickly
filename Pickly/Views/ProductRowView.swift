import SwiftUI
import Foundation
import Combine

#if canImport(UIKit)
import ImageIO
import UIKit
#endif

extension Product {
    var verdictColor: Color {
        verdictPalette.accent
    }

    var verdictFillColor: Color {
        verdictPalette.fill
    }

    var verdictForegroundColor: Color {
        verdictPalette.foreground
    }

    private var verdictPalette: PicklyColor.StatusPalette {
        PicklyColor.ratingPalette(forScore: score, isLimitedData: isLimitedData)
    }
}

struct ProductRowView: View {
    let product: Product
    let isSaved: Bool

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ProductThumbnailView(product: product, size: 48)
                        productDetails
                    }

                    HStack(spacing: 10) {
                        ScorePill(product: product)

                        if isSaved {
                            Label("Saved", picklyIcon: "bookmark.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(PicklyColor.primary)
                        }
                    }
                }
            } else {
                HStack(spacing: 12) {
                    ProductThumbnailView(product: product, size: 52)
                    productDetails
                    Spacer(minLength: 8)

                    VStack(alignment: .center, spacing: 5) {
                        ScorePill(product: product)

                        if isSaved {
                            PicklyIconImage(
                                systemName: "bookmark.fill",
                                size: 14,
                                isDecorative: false
                            )
                                .foregroundStyle(PicklyColor.primary)
                                .accessibilityLabel("Saved")
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var productDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(product.name)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)

            Text(product.brand)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                .fixedSize(horizontal: false, vertical: true)

            Text(product.category)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

}

struct ProductRowsCard: View {
    let products: [Product]
    let isSaved: (Product) -> Bool
    let accessibilityLabel: (Product) -> String
    let onSelect: (Product) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(products.enumerated()), id: \.element.id) { index, product in
                Button {
                    onSelect(product)
                } label: {
                    ProductRowView(
                        product: product,
                        isSaved: isSaved(product)
                    )
                    .padding(.leading, 14)
                    .padding(.trailing, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PicklyPressableButtonStyle())
                .accessibilityLabel(accessibilityLabel(product))

                if index < products.count - 1 {
                    Divider()
                        .padding(.leading, dynamicTypeSize.isAccessibilitySize ? 14 : 80)
                        .padding(.trailing, 14)
                }
            }
        }
        .picklyGlassCardSurface(cornerRadius: 22)
    }
}

struct ProductThumbnailView: View {
    let product: Product
    let size: CGFloat
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 14

    var body: some View {
        Group {
            if let imageURL = product.imageURL {
                remoteImage(url: imageURL)
            } else {
                fallbackImage
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private func remoteImage(url: URL) -> some View {
        let optimizedURL = optimizedImageURL(url)

        #if canImport(UIKit)
        return CachedProductImage(
            url: optimizedURL,
            size: size,
            contentMode: contentMode,
            fallback: { fallbackImage }
        )
        #else
        return AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: size, height: size)
                    .clipped()
            case .failure, .empty:
                fallbackImage
            @unknown default:
                fallbackImage
            }
        }
        #endif
    }

    private func optimizedImageURL(_ url: URL) -> URL {
        guard url.host?.caseInsensitiveCompare("images.openfoodfacts.org") == .orderedSame else {
            return url
        }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var path = components?.path ?? url.path
        path = path.replacingOccurrences(of: ".400.", with: ".200.")
        components?.path = path
        return components?.url ?? url
    }

    private var fallbackImage: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(product.verdictFillColor.opacity(0.22))

            PicklyIconImage(
                systemName: product.imageName,
                size: size * 0.42,
                scalesWithDynamicType: false
            )
                .foregroundStyle(product.verdictColor)
        }
    }
}

#if canImport(UIKit)
private struct CachedProductImage<Fallback: View>: View {
    let url: URL
    let size: CGFloat
    let contentMode: ContentMode
    let fallback: Fallback

    @StateObject private var loader: ProductImageLoader

    init(
        url: URL,
        size: CGFloat,
        contentMode: ContentMode,
        @ViewBuilder fallback: () -> Fallback
    ) {
        self.url = url
        self.size = size
        self.contentMode = contentMode
        self.fallback = fallback()
        _loader = StateObject(wrappedValue: ProductImageLoader(url: url))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .frame(width: size, height: size)
                    .clipped()
                    .transition(.opacity)
            } else {
                fallback
                    .overlay {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.secondary)
                            .opacity(0.72)
                    }
            }
        }
        .task(id: url) {
            await loader.load()
        }
    }
}

@MainActor
private final class ProductImageLoader: ObservableObject {
    @Published private(set) var image: UIImage?

    private static let imageCache = NSCache<NSURL, UIImage>()
    private static let diskCacheDirectory: URL? = {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }

        let directory = cachesDirectory.appendingPathComponent("pickly-product-images", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 32 * 1024 * 1024,
            diskCapacity: 128 * 1024 * 1024,
            diskPath: "pickly-product-images"
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        return URLSession(configuration: configuration)
    }()

    private let url: URL
    private var hasLoaded = false

    init(url: URL) {
        self.url = url
        image = Self.imageCache.object(forKey: url as NSURL)
    }

    func load() async {
        guard !hasLoaded, image == nil else { return }
        hasLoaded = true

        if
            let cachedData = await Self.cachedData(for: url),
            let cachedImage = UIImage(data: cachedData)
        {
            Self.imageCache.setObject(cachedImage, forKey: url as NSURL)
            image = cachedImage
            return
        }

        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await Self.session.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                (200..<300).contains(httpResponse.statusCode),
                let preparedData = await Self.preparedImageData(data),
                let decodedImage = UIImage(data: preparedData)
            else {
                return
            }

            Self.imageCache.setObject(decodedImage, forKey: url as NSURL)
            Self.persist(preparedData, for: url)
            image = decodedImage
        } catch {
            // Keep the deterministic product fallback when the network is
            // slow or unavailable.
        }
    }

    private static func preparedImageData(_ data: Data) async -> Data? {
        await Task.detached(priority: .utility) {
            downsample(data: data)?.jpegData(compressionQuality: 0.82)
        }.value
    }

    nonisolated private static func downsample(data: Data, maxPixelSize: Int = 320) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            return nil
        }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary

        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else {
            return nil
        }

        return UIImage(cgImage: thumbnail)
    }

    private static func cachedData(for url: URL) async -> Data? {
        guard let diskURL = diskURL(for: url) else { return nil }
        return await Task.detached(priority: .utility) {
            try? Data(contentsOf: diskURL, options: .mappedIfSafe)
        }.value
    }

    private static func persist(_ data: Data, for url: URL) {
        guard let diskURL = diskURL(for: url) else { return }
        Task.detached(priority: .utility) {
            try? data.write(to: diskURL, options: .atomic)
        }
    }

    private static func diskURL(for url: URL) -> URL? {
        guard let diskCacheDirectory else { return nil }

        let key = Data(url.absoluteString.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return diskCacheDirectory.appendingPathComponent(key).appendingPathExtension("jpg")
    }
}
#endif

struct ScorePill: View {
    let product: Product
    private let size: CGFloat = 54

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 8) {
                    Text(product.verdict)
                        .font(.caption.bold())

                    if !product.isLimitedData, let score = product.score {
                        Text("\(score) / 100")
                            .font(.caption.monospacedDigit().weight(.semibold))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    product.verdictFillColor,
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(product.verdictColor.opacity(0.22), lineWidth: 1)
                }
            } else {
                VStack(spacing: 1) {
                    Text(product.verdict)
                        .font(.caption2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    if !product.isLimitedData, let score = product.score {
                        Text("\(score)")
                            .font(.caption2.monospacedDigit())
                            .lineLimit(1)
                    }
                }
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(product.verdictFillColor)
                )
                .overlay {
                    Circle()
                        .stroke(product.verdictColor.opacity(0.22), lineWidth: 1)
                }
            }
        }
        .foregroundStyle(product.verdictForegroundColor)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if !product.isLimitedData, let score = product.score {
            return "\(product.verdict), score \(score)"
        }

        return "Limited data, no reliable score"
    }
}

#Preview {
    List {
        ProductRowView(
            product: MockProductService().products[1],
            isSaved: true
        )
    }
}
