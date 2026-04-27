import SwiftUI

struct ProductResultView: View {
    let product: Product
    let productService: MockProductService
    @ObservedObject var savedStore: SavedProductsStore
    let preferences: UserPreferences

    private var alternatives: [Product] {
        productService.alternatives(for: product)
    }

    private var forYouItems: [String] {
        var items = product.forYouNotes

        if preferences.sensitiveDigestion && product.ingredients.count > 6 {
            items.append("May not be ideal for sensitive digestion")
        }

        if preferences.lowSugar && product.warnings.contains(where: { $0.localizedCaseInsensitiveContains("sugar") }) {
            items.append("You might prefer one of the lower sugar alternatives below")
        }

        return Array(Set(items)).sorted()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroSection
                saveButton

                ResultSectionView(
                    title: "Why this score",
                    systemImage: "list.bullet.clipboard",
                    items: product.reasons
                )

                ResultSectionView(
                    title: "What to watch",
                    systemImage: "eye",
                    items: product.warnings
                )

                ResultSectionView(
                    title: "For you",
                    systemImage: "person.crop.circle",
                    items: forYouItems.isEmpty ? ["No preference-specific notes for this product."] : forYouItems
                )

                alternativesSection
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(product.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ProductThumbnailView(product: product, size: 92)

                VStack(alignment: .leading, spacing: 8) {
                    Text(product.brand)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(product.name)
                        .font(.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Text(product.verdict)
                            .font(.headline.bold())
                            .foregroundStyle(product.verdictColor)

                        Text("\(product.score)/100")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(product.verdict), score \(product.score) out of 100")
                }
            }

            Text(product.summary)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label("Confidence: \(product.confidence)", systemImage: "checkmark.shield")
                Spacer()
                Text(product.nutritionSummary)
                    .multilineTextAlignment(.trailing)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var saveButton: some View {
        Button {
            savedStore.toggle(product)
        } label: {
            Label(savedStore.isSaved(product) ? "Saved" : "Save", systemImage: savedStore.isSaved(product) ? "bookmark.fill" : "bookmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(.green)
        .accessibilityHint(savedStore.isSaved(product) ? "Removes this product from Saved." : "Adds this product to Saved.")
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Better alternatives", systemImage: "arrow.triangle.branch")
                .font(.headline)

            if alternatives.isEmpty {
                Text("This is already one of the better options in the mock set.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                ForEach(alternatives) { alternative in
                    NavigationLink(value: alternative) {
                        VStack(alignment: .leading, spacing: 8) {
                            ProductRowView(
                                product: alternative,
                                isSaved: savedStore.isSaved(alternative)
                            )

                            if let reason = alternative.positives.first {
                                Text(reason)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 64)
                            }
                        }
                        .padding(14)
                        .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct ResultSectionView: View {
    let title: String
    let systemImage: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.green)
                            .padding(.top, 1)

                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

#Preview {
    NavigationStack {
        ProductResultView(
            product: MockProductService().products[1],
            productService: MockProductService(),
            savedStore: SavedProductsStore(),
            preferences: .prototype
        )
    }
}
