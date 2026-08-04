import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What Pickly uses") {
                    Text("Pickly uses the camera only after you start barcode scanning. Camera frames are processed for barcode recognition and are not stored by the MVP.")
                    Text("A barcode may be sent to Open Food Facts to look up product information. Open Food Facts may receive the barcode and the request metadata needed to provide the response.")
                    Text("If you create an account, Pickly processes your email address for sign-in. The MVP keeps saved products, history, and preferences on this device.")
                }

                Section("Your choices") {
                    Text("Camera access is optional. You can search the sample catalog or enter a barcode manually instead.")
                    Text("You can delete your Pickly account from the Account screen. Deleting the account also clears local saved products and preferences.")
                }

                Section("Data retention") {
                    Text("Local saved products, history, and preferences remain on this device until you remove them, delete the app, or delete your account from Pickly.")
                    Text("This MVP does not use advertising identifiers, location, contacts, or a social profile.")
                }

                Section {
                    Text("Last updated August 4, 2026")
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
