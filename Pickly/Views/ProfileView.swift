import SwiftUI

struct ProfileView: View {
    @Binding var preferences: UserPreferences
    @ObservedObject var savedStore: SavedProductsStore
    @ObservedObject var authStore: AuthStore
    var onAccountDeleted: () -> Void = {}

    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @State private var activeSheet: ProfileSheet?

    var body: some View {
        List {
            PicklyContentHeader(title: "Profile")
                .picklyContentHeaderRow()

            Section {
                ProfileSummaryCard(
                    savedCount: savedStore.savedProducts.count,
                    historyCount: savedStore.recentProducts.count,
                    accountEmail: authStore.currentEmail
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }
            .listRowBackground(Color.clear)

            Section("Account") {
                Button {
                    activeSheet = .account
                } label: {
                    SettingsActionRow(
                        icon: .system("person.badge.key"),
                        tone: .account,
                        title: authStore.currentEmail == nil ? "Sign in" : "Account",
                        subtitle: authStore.currentEmail ?? "Continue with Apple, Google, or email"
                    )
                }
                .buttonStyle(.plain)

                if subscriptionStore.isPlus {
                    Link(destination: URL(string: "itms-apps://apps.apple.com/account/subscriptions")!) {
                        SettingsActionRow(
                            icon: .system("arrow.up.right.square"),
                            tone: .pro,
                            title: "Manage Subscription",
                            subtitle: "Open Apple ID subscription settings"
                        )
                    }
                }
            }

            Section("Preferences") {
                PreferenceToggleRow(
                    icon: .system(GroceryGoal.lowSugar.preferenceIcon),
                    tone: .sugar,
                    title: "Low sugar",
                    subtitle: "Prefer products with less added sugar",
                    isOn: $preferences.lowSugar
                )

                PreferenceToggleRow(
                    icon: .system(GroceryGoal.lowSodium.preferenceIcon),
                    tone: .sodium,
                    title: "Low sodium",
                    subtitle: "Prefer lower-sodium options",
                    isOn: $preferences.lowSodium
                )

                PreferenceToggleRow(
                    icon: .system(GroceryGoal.sensitiveDigestion.preferenceIcon),
                    tone: .digestion,
                    title: "Gentler picks",
                    subtitle: "Prefer simpler options that may feel easier to digest",
                    isOn: $preferences.sensitiveDigestion
                )

                PreferenceToggleRow(
                    icon: .system(GroceryGoal.vegetarian.preferenceIcon),
                    tone: .vegetarian,
                    title: "Vegetarian",
                    subtitle: "Prioritize vegetarian-friendly products",
                    isOn: $preferences.vegetarian
                )

                PreferenceToggleRow(
                    icon: .system(GroceryGoal.vegan.preferenceIcon),
                    tone: .vegan,
                    title: "Vegan",
                    subtitle: "Prefer products without animal ingredients",
                    isOn: $preferences.vegan
                )

                PreferenceToggleRow(
                    icon: .system(GroceryGoal.glutenFree.preferenceIcon),
                    tone: .glutenFree,
                    title: "Gluten-free",
                    subtitle: "Flag products that may not fit this preference",
                    isOn: $preferences.glutenFree
                )

                PreferenceToggleRow(
                    icon: .system(GroceryGoal.lactoseFree.preferenceIcon),
                    tone: .lactoseFree,
                    title: "Lactose-free",
                    subtitle: "Flag products that may not fit this preference",
                    isOn: $preferences.lactoseFree
                )
            }

            Section("Subscription") {
                Button {
                    activeSheet = .paywall
                } label: {
                    SettingsActionRow(
                        icon: .system("sparkles"),
                        tone: .pro,
                        title: "Pickly Plus",
                        subtitle: subscriptionStore.isPlus
                            ? "Your subscription is active"
                            : "Compare more products and alternatives"
                    )
                }
                .buttonStyle(.plain)
            }

            Section("Data & privacy") {
                SettingsInfoRow(
                    icon: .system("camera"),
                    tone: .camera,
                    title: "Camera",
                    subtitle: "Camera access is used only when you scan a barcode."
                )

                SettingsInfoRow(
                    icon: .system("lock.shield"),
                    tone: .privacy,
                    title: "Personal data",
                    subtitle: "Saved products and preferences stay on this device."
                )

                Button {
                    activeSheet = .privacyPolicy
                } label: {
                    SettingsActionRow(
                        icon: .system("doc.text"),
                        tone: .privacy,
                        title: "Privacy Policy",
                        subtitle: "How Pickly handles camera, account, and local data"
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
        .contentMargins(.top, PicklyLayout.rootTopPadding, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(PicklyColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .account:
                AccountAuthView(
                    authStore: authStore,
                    onAccountDeleted: onAccountDeleted
                )
            case .paywall:
                PicklyPaywallView()
            case .privacyPolicy:
                PrivacyPolicyView()
            }
        }
    }
}

private enum ProfileSheet: String, Identifiable {
    case account
    case paywall
    case privacyPolicy

    var id: String { rawValue }
}

private struct ProfileSummaryCard: View {
    let savedCount: Int
    let historyCount: Int
    let accountEmail: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if dynamicTypeSize.isAccessibilitySize {
                summaryContent
            } else {
                HStack(spacing: 12) {
                    summaryIcon
                    summaryText
                }
            }

            HStack(spacing: 10) {
                ProfileStatPill(value: savedCount, title: "Saved")
                ProfileStatPill(value: historyCount, title: "Recent")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .picklyCardSurface(cornerRadius: 20)
        .accessibilityElement(children: .combine)
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryIcon
            summaryText
        }
    }

    private var summaryIcon: some View {
        PicklyIconImage(
            systemName: "person.crop.circle.fill",
            size: 40,
            scalesWithDynamicType: false
        )
        .foregroundStyle(PicklyColor.primary)
    }

    private var summaryText: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your Pickly")
                .font(.title3.bold())

            Text(accountEmail ?? "Calm grocery guidance, tuned to you.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
        }
    }
}

private struct ProfileStatPill: View {
    let value: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number)
                .font(.headline.monospacedDigit())

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PicklyColor.mint, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(PicklyColor.stroke.opacity(0.55), lineWidth: 1)
        )
    }
}

private enum SettingsIcon {
    case system(String)
    case text(String)
}

private struct PreferenceToggleRow: View {
    let icon: SettingsIcon
    let tone: PicklyColor.ProfileTone
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            SettingsLabel(
                icon: icon,
                tone: tone,
                title: title,
                subtitle: subtitle
            )
        }
        .tint(PicklyColor.primary)
    }
}

private struct SettingsActionRow: View {
    let icon: SettingsIcon
    let tone: PicklyColor.ProfileTone
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            SettingsLabel(icon: icon, tone: tone, title: title, subtitle: subtitle)

            Spacer(minLength: 8)

            PicklyIconImage(systemName: "chevron.right", size: 12)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsInfoRow: View {
    let icon: SettingsIcon
    let tone: PicklyColor.ProfileTone
    let title: String
    let subtitle: String

    var body: some View {
        SettingsLabel(icon: icon, tone: tone, title: title, subtitle: subtitle)
    }
}

private struct SettingsLabel: View {
    let icon: SettingsIcon
    let tone: PicklyColor.ProfileTone
    let title: String
    let subtitle: String

    private var palette: PicklyColor.StatusPalette {
        PicklyColor.profilePalette(tone)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsIconView(icon: icon, palette: palette)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct SettingsIconView: View {
    let icon: SettingsIcon
    let palette: PicklyColor.StatusPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(palette.fill)

            iconContent
                .foregroundStyle(palette.foreground)
        }
        .frame(width: 32, height: 32)
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(palette.border.opacity(0.32), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var iconContent: some View {
        switch icon {
        case .system(let name):
            PicklyIconImage(systemName: name, size: 18)
        case .text(let value):
            Text(value)
                .font(.caption.weight(.black))
                .tracking(0.2)
        }
    }
}

private enum EmailAuthMode: String, CaseIterable, Identifiable {
    case create
    case signIn

    var id: String { rawValue }

    var title: String {
        switch self {
        case .create:
            return "Create"
        case .signIn:
            return "Sign in"
        }
    }

    var buttonTitle: String {
        switch self {
        case .create:
            return "Create account"
        case .signIn:
            return "Sign in"
        }
    }
}

private enum AccountFocusedField {
    case email
    case password
}

struct AccountAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var authStore: AuthStore
    let onAccountDeleted: () -> Void
    var showsSocialProviders = true

    @State private var mode: EmailAuthMode = .create
    @State private var email = ""
    @State private var password = ""
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deletionErrorMessage: String?
    @FocusState private var focusedField: AccountFocusedField?

    private var canSubmit: Bool {
        authStore.isConfigured && !authStore.isWorking && email.contains("@") && password.count >= 8
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        AccountHero(showsSocialProviders: showsSocialProviders)

                        if authStore.isRestoringSession {
                            ProgressView("Restoring account session...")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            switch authStore.state {
                            case .signedOut:
                                emailForm
                            case .signedIn:
                                signedInCard
                            case .needsEmailConfirmation(let email):
                                confirmationCard(email: email)
                            case .recoveringPassword:
                                ProgressView("Preparing password reset…")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(
                        width: max(
                            0,
                            geometry.size.width - PicklyLayout.screenHorizontalPadding * 2
                        ),
                        alignment: .leading
                    )
                    .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(PicklyColor.background)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await authStore.restoreSessionIfNeeded()
            }
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            if showsSocialProviders {
                AuthProviderButtons(authStore: authStore)

                HStack(spacing: 12) {
                    Divider()
                    Text("or continue with email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    Divider()
                }
                .accessibilityElement(children: .combine)
            }

            Picker("Account mode", selection: $mode) {
                ForEach(EmailAuthMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 14) {
                AccountTextField(
                    title: "Email",
                    prompt: "you@example.com",
                    text: $email,
                    contentType: .emailAddress,
                    keyboardType: .emailAddress,
                    focusedField: $focusedField,
                    focus: .email,
                    submitLabel: .next
                ) {
                    focusedField = .password
                }

                AccountTextField(
                    title: "Password",
                    prompt: "At least 8 characters",
                    text: $password,
                    contentType: .password,
                    keyboardType: .default,
                    focusedField: $focusedField,
                    focus: .password,
                    submitLabel: .go,
                    isSecure: true
                ) {
                    submit()
                }
            }

            if mode == .signIn {
                Button("Forgot password?") {
                    focusedField = nil
                    Task {
                        await authStore.requestPasswordReset(
                            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)
                .disabled(
                    !authStore.isConfigured
                        || authStore.isWorking
                        || !email.contains("@")
                )
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityHint("Sends a password reset link to the entered email address.")
            }

            if !authStore.isConfigured {
                AccountStatusMessage(
                    icon: "exclamationmark.triangle.fill",
                    text: "Account sync is not available yet."
                )
            } else if let statusMessage = authStore.statusMessage {
                AccountStatusMessage(
                    icon: "info.circle.fill",
                    text: statusMessage
                )
            } else {
                Text("Account access is optional. Saved products and preferences stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                submit()
            } label: {
                HStack(spacing: 10) {
                    if authStore.isWorking {
                        ProgressView()
                            .tint(.black)
                    } else {
                        PicklyIconImage(systemName: "envelope.fill", size: 18)
                    }

                    Text(authStore.isWorking ? "Working..." : mode.buttonTitle)
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AccountPrimaryButtonStyle())
            .disabled(!canSubmit)
            .accessibilityHint("Uses your email and password to create or open your Pickly account.")
        }
    }

    private var signedInCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccountStatusIcon(systemName: "checkmark.circle.fill")

            VStack(alignment: .leading, spacing: 6) {
                Text("You're signed in")
                    .font(.title2.bold())

                if let email = authStore.currentEmail {
                    Text(email)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Button("Sign out") {
                Task {
                    await authStore.signOut()
                }
            }
            .buttonStyle(AccountSecondaryButtonStyle())

            Button(role: .destructive) {
                deletionErrorMessage = nil
                showDeleteConfirmation = true
            } label: {
                HStack(spacing: 10) {
                    if isDeletingAccount {
                        ProgressView()
                            .tint(.red)
                    }

                    Text(isDeletingAccount ? "Deleting account…" : "Delete account")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(authStore.isWorking || isDeletingAccount)
            .confirmationDialog(
                "Delete your Pickly account?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Account", role: .destructive) {
                    Task {
                        isDeletingAccount = true
                        deletionErrorMessage = nil
                        defer { isDeletingAccount = false }

                        if await authStore.deleteAccount() {
                            onAccountDeleted()
                            dismiss()
                        } else {
                            deletionErrorMessage = authStore.statusMessage
                                ?? "Your account could not be deleted. Please try again."
                        }
                    }
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes your account and server-side profile data. Local saved products will also be cleared. App Store subscriptions are separate and must be canceled in Apple ID settings.")
            }

            if let errorMessage = deletionErrorMessage {
                AccountStatusMessage(
                    icon: "exclamationmark.triangle.fill",
                    text: errorMessage
                )

                Button("Try again") {
                    deletionErrorMessage = nil
                    showDeleteConfirmation = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PicklyColor.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .picklyCardSurface(cornerRadius: 24, stroke: PicklyColor.stroke.opacity(0.5))
    }

    private func confirmationCard(email: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AccountStatusIcon(systemName: "envelope.badge.fill")

            VStack(alignment: .leading, spacing: 6) {
                Text("Check your email")
                    .font(.title2.bold())

                Text("We sent a confirmation link to \(email).")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Back to sign in") {
                mode = .signIn
                Task {
                    await authStore.signOut()
                }
            }
            .buttonStyle(AccountSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .picklyCardSurface(cornerRadius: 24, stroke: PicklyColor.stroke.opacity(0.5))
    }

    private func submit() {
        focusedField = nil

        Task {
            switch mode {
            case .create:
                await authStore.signUp(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            case .signIn:
                await authStore.signIn(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
            }
        }
    }
}

private enum PasswordRecoveryField {
    case password
    case confirmation
}

struct PasswordRecoveryView: View {
    @ObservedObject var authStore: AuthStore

    @State private var password = ""
    @State private var confirmation = ""
    @State private var validationMessage: String?
    @FocusState private var focusedField: PasswordRecoveryField?

    private var canSubmit: Bool {
        password.count >= 8
            && password == confirmation
            && !authStore.isWorking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    AccountStatusIcon(systemName: "key.fill")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose a new password")
                            .font(.largeTitle.bold())
                            .accessibilityAddTraits(.isHeader)

                        Text("Use at least 8 characters. After saving, you’ll stay signed in on this device.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(spacing: 14) {
                        recoveryField(
                            title: "New password",
                            prompt: "At least 8 characters",
                            text: $password,
                            focus: .password,
                            submitLabel: .next
                        ) {
                            focusedField = .confirmation
                        }

                        recoveryField(
                            title: "Confirm password",
                            prompt: "Enter it again",
                            text: $confirmation,
                            focus: .confirmation,
                            submitLabel: .done
                        ) {
                            submit()
                        }
                    }

                    if let message = validationMessage ?? authStore.statusMessage {
                        AccountStatusMessage(icon: "info.circle.fill", text: message)
                    }

                    Button(action: submit) {
                        HStack(spacing: 10) {
                            if authStore.isWorking {
                                ProgressView().tint(.black)
                            }
                            Text(authStore.isWorking ? "Saving…" : "Update password")
                                .font(.headline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AccountPrimaryButtonStyle())
                    .disabled(!canSubmit)
                }
                .padding(PicklyLayout.screenHorizontalPadding)
            }
            .background(PicklyColor.background)
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        Task { await authStore.cancelPasswordRecovery() }
                    }
                }
            }
            .interactiveDismissDisabled(authStore.isWorking)
        }
    }

    private func recoveryField(
        title: String,
        prompt: String,
        text: Binding<String>,
        focus: PasswordRecoveryField,
        submitLabel: SubmitLabel,
        onSubmit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            SecureField(prompt, text: text)
                .textContentType(.newPassword)
                .focused($focusedField, equals: focus)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
                .padding(.horizontal, 14)
                .frame(minHeight: 52)
                .background(PicklyColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(PicklyColor.stroke.opacity(0.6), lineWidth: 1)
                }
        }
    }

    private func submit() {
        focusedField = nil
        validationMessage = nil

        guard password.count >= 8 else {
            validationMessage = "Use at least 8 characters."
            return
        }
        guard password == confirmation else {
            validationMessage = "Passwords don’t match."
            return
        }

        Task {
            _ = await authStore.updatePassword(password)
        }
    }
}

private struct AccountHero: View {
    let showsSocialProviders: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AccountStatusIcon(systemName: "person.badge.key.fill")

            VStack(alignment: .leading, spacing: 8) {
                Text(showsSocialProviders ? "Sign in to Pickly" : "Continue with email")
                    .font(dynamicTypeSize.isAccessibilitySize ? .title2.bold() : .title.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(
                    showsSocialProviders
                        ? "Use Apple, Google, or email. Account access is optional, and your local grocery data stays on this device."
                        : "Create an account or sign in with your email and password."
                )
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AccountStatusIcon: View {
    let systemName: String

    var body: some View {
        PicklyIconImage(
            systemName: systemName,
            size: 46,
            scalesWithDynamicType: false
        )
            .foregroundStyle(PicklyColor.primary)
            .accessibilityHidden(true)
    }
}

private struct AccountTextField: View {
    let title: String
    let prompt: String
    @Binding var text: String
    let contentType: UITextContentType
    let keyboardType: UIKeyboardType
    let focusedField: FocusState<AccountFocusedField?>.Binding
    let focus: AccountFocusedField
    let submitLabel: SubmitLabel
    var isSecure = false
    var onSubmit: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            field
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                .background(PicklyColor.card, in: fieldShape)
                .overlay {
                    fieldShape
                        .stroke(
                            focusedField.wrappedValue == focus ? PicklyColor.primary : PicklyColor.stroke.opacity(0.62),
                            lineWidth: focusedField.wrappedValue == focus ? 1.4 : 1
                        )
                }
                .contentShape(fieldShape)
                .onTapGesture {
                    focusedField.wrappedValue = focus
                }
        }
    }

    private var fieldShape: some Shape {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    @ViewBuilder
    private var field: some View {
        if isSecure {
            SecureField(prompt, text: $text)
                .textContentType(contentType)
                .focused(focusedField, equals: focus)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
        } else {
            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .focused(focusedField, equals: focus)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)
        }
    }
}

private struct AccountStatusMessage: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            PicklyIconImage(systemName: icon, size: 18)
                .foregroundStyle(PicklyColor.primary)

            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PicklyColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(PicklyColor.stroke.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct AccountPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(minHeight: 52)
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .foregroundStyle(isEnabled ? Color.black : Color.secondary)
            .background(
                isEnabled ? PicklyColor.primary : PicklyColor.stroke.opacity(0.7),
                in: Capsule()
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

private struct AccountSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, PicklyLayout.screenHorizontalPadding)
            .foregroundStyle(PicklyColor.primary)
            .background(PicklyColor.stroke.opacity(0.45), in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.snappy(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ProfileView(
            preferences: .constant(.prototype),
            savedStore: SavedProductsStore(),
            authStore: AuthStore()
        )
    }
    .environmentObject(SubscriptionStore(loadProducts: false))
}
