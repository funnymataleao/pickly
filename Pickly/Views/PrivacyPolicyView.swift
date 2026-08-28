import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What Pickly uses") {
                    Text("Pickly uses the camera only after you start barcode scanning. Camera frames are processed for barcode recognition and are not stored by Pickly.")
                    Text("Search queries and barcodes may be sent to Pickly's Cloudflare service and Open Food Facts to look up product information. Those services receive the request metadata needed to provide a response.")
                    Text("If you are signed in and request a missing product, the barcode, product name, brand, and optional note you submit are stored in Pickly's Cloudflare service with your user ID so the request can be reviewed.")
                    Text("When you use optional account sign-in, Firebase processes your email address, user ID, and any name supplied by Apple or Google. Firebase Authentication's bundled privacy manifest also declares other diagnostic data used for analytics; this data is not linked to your identity and is not used for tracking. Pickly keeps the local session managed by Firebase, while account-linked product requests are stored in Pickly's Cloudflare service. Pickly does not store long-lived Apple authorization codes or refresh tokens.")
                    Text("When you choose Google Sign-In, Google's SDK may process account and service data described by its bundled privacy manifest, including name, email address, user ID, phone number when present on the selected Google account, coarse location, device identifiers, and other service usage data. Google declares these uses for sign-in functionality and limited SDK analytics, not advertising tracking. Pickly does not request location permission or use this data for advertising.")
                    Text("If you use Pickly Plus, Apple processes the purchase. Pickly checks the verified subscription status on this device through StoreKit and does not send your transaction or purchase history to Pickly's servers.")
                }

                Section("Your choices") {
                    Text("Camera access is optional. You can search the product catalog or enter a barcode manually instead.")
                    Text("You can delete your Pickly account from the Account screen. Deleting the account also clears local saved products and preferences.")
                    Text("If you have Pickly Plus, use Manage Subscription before deleting your account if you do not want Apple billing to renew. Deleting a Pickly account does not cancel an App Store subscription.")
                }

                Section("Data retention") {
                    Text("Local saved products, history, and preferences remain on this device until you remove them, delete the app, or delete your account from Pickly.")
                    Text("Submitted product requests remain in Pickly's Cloudflare service while your account is active and are removed with the account.")
                    Text("Firebase account data remains while your account is active. Deleting your account removes account-linked data from Pickly's Cloudflare service, revokes the Apple connection when applicable, removes the Firebase account, and clears local Pickly data. Apple may ask you to confirm your identity again before deletion. If a server request is unavailable, your account stays active so you can retry. App Store subscription billing is separate and must be managed through Apple.")
                    Text("Pickly does not sell personal information or use it for advertising tracking. Camera access is optional, and no contacts are requested.")
                }

                Section("Scoring and guidance") {
                    Text(ScoringMethodology.scorePurpose)
                    Text(ScoringMethodology.dataSources)
                    Text(ScoringMethodology.medicalDisclaimer)
                    NavigationLink("Read the scoring methodology") {
                        ScoringMethodologyView()
                    }
                }

                Section("Product data sources") {
                    Text("Product facts and some product images may come from Open Food Facts. Availability and accuracy can vary by product and region.")
                    Text("Open Food Facts data is provided under ODbL/DBCL terms, and images may be provided under CC BY-SA. Review the source licenses before reusing catalog data.")
                    Link("Open Food Facts licenses", destination: URL(string: "https://openfoodfacts.github.io/openfoodfacts-server/api/tutorials/license-be-on-the-legal-side/")!)
                }

                Section("Support") {
                    Link("Pickly support page", destination: URL(string: "https://funnymataleao.github.io/pickly/support.html")!)
                }

                Section {
                    Text("Last updated August 28, 2026")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
