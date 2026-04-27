# Pickly - AGENTS.md

## Communication

- Talk to the project owner in Russian by default, unless they explicitly ask for another language.
- All user-facing app UI strings must be in English.
- Keep product, design, and engineering recommendations concrete, Apple-native, and realistic for production.

## Apple Platform Source Of Truth

Use this priority order when making product, design, or implementation decisions:

1. Current Apple Human Interface Guidelines and platform-specific guidance.
2. Official Apple documentation for SwiftUI, UIKit, AppKit, AVFoundation, StoreKit, and system APIs.
3. App Review Guidelines.
4. Official Apple Design Resources, SF Symbols, and system components.

If a beautiful idea conflicts with native Apple behavior, choose the native platform behavior.

## Product Overview

Pickly is a grocery scanner iOS app.

Users can:

- Scan a supermarket product barcode.
- Search for a grocery product manually.
- See a calm, clear product verdict.
- Understand the score in plain language.
- Compare better alternatives quickly.
- Save products for later.

Tagline:

- "Scan better. Choose smarter."

Pickly is not a panic app. It must not scare, shame, or manipulate the user.

Pickly is a clarity app. It helps people make better grocery decisions quickly and calmly.

## MVP Goal

Build a simple, fast, polished iOS MVP with:

- Clear grocery product scoring.
- Explainable, human-readable reasons.
- A strong alternatives feature.
- Minimal but premium SwiftUI UI.
- Mock data only, with an architecture that can accept a real API later.

The MVP should validate the core user flow before any complex backend, social layer, or expanded category support.

## Target Platform

Primary platform:

- iPhone, because the main use case is scanning products while shopping in a supermarket.

Secondary consideration:

- iPad is supported by the current project target, but the MVP should be designed iPhone-first.
- If iPad-specific work is added later, do not simply stretch the iPhone UI. Use native iPad patterns such as sidebars, split navigation, pointer support, keyboard shortcuts, and multiwindow only when they add real value.

## Current Project State

The project is currently a fresh SwiftUI app:

- `PicklyApp.swift` launches `ContentView`.
- `ContentView.swift` still contains the default placeholder UI.
- No domain models, services, view models, navigation shell, scanner, persistence, or mock product data exist yet.
- The Xcode project targets iPhone and iPad.
- The current deployment target in the project file is iOS 26.4.

## Strict MVP Scope

Only support:

- Grocery and supermarket food products.
- Barcode scan and product search.
- Product result, explanation, alternatives, saved/history, profile/preferences, onboarding, and paywall placeholder.
- Local mock data for the first prototype.

Do not add:

- Community features.
- Social feed.
- Followers, likes, comments, or chat.
- Non-food categories such as cosmetics, water quality, air quality, supplements, or household products.
- Complex backend.
- Heavy third-party dependencies.
- AI-generated fake facts.
- Panic-driven UX.

## Core Screens

1. Onboarding
2. Home / Search
3. Scan barcode
4. Product Result
5. Alternatives
6. Saved / History
7. Profile
8. Paywall placeholder

Do not add a Community tab or Community screen.

## Navigation

Use a native SwiftUI tab bar with four tabs:

- Search
- Scan
- Saved
- Profile

Recommended structure:

- Each tab owns its own `NavigationStack`.
- Product Result is pushed from Search, Scan, Saved, and Alternatives.
- Alternatives can appear as a section inside Product Result and also have a focused list/detail route when needed.
- Paywall is a placeholder sheet or pushed screen only when a gated action is intentionally tested.

Avoid web-like landing pages inside the app. The first useful app surface should support searching or scanning.

## Product Result Screen

This is the most important screen in the MVP.

It must show:

- Product image.
- Product name.
- Brand.
- Verdict: "Great", "Good", "Okay", or "Not great".
- Score from 0 to 100.
- Short summary in 1-2 lines.
- "Why this score".
- "What to watch".
- "For you".
- "Better alternatives".
- Confidence indicator, for example "Confidence: Medium".
- Save button.

Hierarchy rule:

- The verdict and plain-language explanation are more important than the numeric score.
- The score should support the verdict, not dominate the screen.
- Alternatives should be visible without making the result feel alarmist.

## Tone Of Voice

Never use:

- "dangerous"
- "toxic"
- "harmful"
- "harmful for you"
- fear-based or shame-based copy

Use calm wording:

- "Contains more added sugar than similar products"
- "May not be the best choice if you're reducing sugar"
- "Better as an occasional option"
- "You might prefer one of the alternatives below"
- "May not be ideal for sensitive digestion"
- "Better option if you're limiting sugar"

No medical claims. Pickly can guide grocery choices, but it must not diagnose, treat, or imply clinical certainty.

## Alternatives Feature

Alternatives are core value, not a secondary nice-to-have.

When a product is not ideal, show better options when possible.

Each alternative card must include:

- Image.
- Name.
- Brand.
- Verdict and/or score.
- Short reason in English.

Example reasons:

- "Less added sugar"
- "Shorter ingredient list"
- "Higher protein"
- "Lower sodium"

Alternatives should compare against explainable product facts, not invented claims.

## Personalization

User preferences can include:

- Sensitive digestion.
- Low sugar.
- Low sodium.
- Vegetarian.
- Vegan.
- Gluten-free.
- Lactose-free.

Use preferences softly in the "For you" section.

Good examples:

- "May not be ideal for sensitive digestion"
- "Better option if you're limiting sugar"

Avoid:

- Medical claims.
- Absolute promises.
- Fear wording.
- Hidden or manipulative preference defaults.

## Data Models

Minimum MVP models:

### Product

- `id`
- `barcode`
- `name`
- `brand`
- `category`
- `image`
- `ingredients`
- `nutrition`
- `score`
- `verdict`
- `reasons`
- `warnings`
- `positives`
- `alternatives`
- `confidence`

### Nutrition

- Added sugar.
- Sodium.
- Saturated fat.
- Protein.
- Fiber.
- Serving size, if available in the fixture.

### ProductAlternative

- Product id or embedded lightweight product reference.
- Reason.
- Score/verdict snapshot if needed for display.

### UserPreferences

- Sensitivities.
- Dietary preferences.

### SavedProduct

- `productId`
- `date`

## Scoring Rules

The MVP score must be explainable and deterministic.

Base scoring on:

- Added sugar.
- Sodium.
- Saturated fat.
- Ingredient list length.
- Additives.
- Positives such as protein and fiber.

Rules:

- AI must not generate product scores.
- AI must not invent nutrition, ingredients, warnings, or product facts.
- Every score should map to visible reasons in "Why this score", "What to watch", and "For you".
- Verdict mapping should be stable and easy to understand.

Suggested verdict mapping:

- 85-100: "Great"
- 70-84: "Good"
- 50-69: "Okay"
- 0-49: "Not great"

Adjust thresholds only when the scoring model is intentionally revised.

## AI Usage Rules

AI may be used only for:

- Generating or simplifying explanation text from verified product facts.
- Rewriting explanations into calmer, clearer English.

AI must not:

- Generate scores.
- Invent ingredients.
- Invent nutrition values.
- Invent allergens.
- Invent product availability.
- Invent alternatives.
- Make medical claims.
- Present mock data as real catalog truth.

Mock data is allowed for MVP as explicit local fixtures, but it must be clearly treated as prototype data.

## Design Principles

Pickly should feel:

- Calm.
- Fast.
- Clean.
- Trustworthy.
- Premium but not decorative.
- More polished than Oasis.

Use:

- SwiftUI-native components.
- System typography.
- SF Symbols where appropriate.
- System colors and semantic color roles.
- Calm success/attention colors, not aggressive warning colors.
- Clear spacing, readable hierarchy, and strong content grouping.
- System materials and Liquid Glass only when they improve depth, hierarchy, focus, or context.

Do not:

- Use glass effects for decoration.
- Reduce contrast for style.
- Make the app feel like a web page inside a native shell.
- Overload screens with controls.
- Prioritize the numeric score over understandable guidance.

## Architecture Rules

Default architecture:

- SwiftUI.
- MVVM where it helps separate UI state from product logic.
- Models / ViewModels / Services.
- Local mock services for MVP.
- No heavy dependencies.

Recommended folders:

- `Models`
- `Services`
- `ViewModels`
- `Views`
- `Views/Components`
- `Resources` or `MockData`

Recommended services:

- `ProductService` protocol.
- `MockProductService`.
- `ScoringService`.
- `PreferencesStore`.
- `SavedProductsStore`.
- `BarcodeScannerService` abstraction when scanner work begins.

Implementation guidance:

- Keep scoring logic out of SwiftUI views.
- Keep mock data separate from views.
- Prefer dependency injection over global singletons.
- Keep views preview-friendly with fixture data.
- Use local state for local UI concerns.
- Use async APIs for service interfaces even if mock data returns immediately.
- Add real networking later behind the service protocols.
- Do not rewrite architecture without a concrete need.

## Privacy And App Review

Respect privacy by design:

- Ask for camera permission only when the user starts scanning or clearly enters scanner setup.
- Explain camera access in plain language.
- Do not collect unnecessary personal data.
- Store preferences locally for MVP.
- Avoid dark patterns around permissions, paywall, or saved products.

App Review risk areas:

- Do not imply medical advice.
- Do not misrepresent mock data as real product catalog coverage.
- Do not use fear-based claims.
- Do not gate basic clarity behind a misleading paywall in the MVP.
- If payments are added later, use StoreKit and Apple-compliant subscription/paywall patterns.

## Accessibility And Localization

Accessibility is required, not optional.

Support:

- VoiceOver labels for key controls and product result sections.
- Dynamic Type.
- Sufficient contrast.
- Touch targets that meet platform expectations.
- Reduce Motion where animations are introduced.
- Clear focus order.
- Keyboard and pointer behavior if iPad support becomes meaningful.

Localization readiness:

- MVP UI strings are English.
- Layout must tolerate longer strings.
- Avoid hard-coded truncation that hides key guidance.
- Keep copy centralized enough to migrate to string catalogs later.
- Avoid text baked into images.

## User-Facing UI Strings

Use English strings such as:

- "Search products"
- "Scan barcode"
- "Great"
- "Good"
- "Okay"
- "Not great"
- "Why this score"
- "What to watch"
- "For you"
- "Better alternatives"
- "Save"
- "Saved"
- "Profile"
- "Settings"
- "Confidence: Medium"

## Development Strategy

1. Start with local mock data.
2. Build the full core flow.
3. Validate UX in simulator.
4. Add scanner behavior behind an abstraction.
5. Add persistence for saved products and preferences.
6. Connect real product data later.

Before implementing large features:

- Propose a plan.
- Keep scope minimal.
- Focus on a working prototype first.
- Avoid unrelated refactors.

## Definition Of Done

A feature is complete only when:

- It matches the grocery-only MVP scope.
- It uses native iOS SwiftUI patterns.
- It works in the simulator.
- UI strings are in English.
- It avoids panic-driven language.
- Logic is separated from UI.
- Mock data is used correctly and transparently.
- Scores are explainable from product facts.
- Alternatives are shown when possible.
- Accessibility basics are handled.
- Layout is localization-ready.
- Privacy and App Review risks are considered.
- Code is clean, modular, preview-friendly, and not over-engineered.
