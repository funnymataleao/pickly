# Pickly — AGENTS.md

## 🧠 Project Overview

Pickly is a grocery scanner iOS app.

Users:
- scan a product barcode
- or search for a product
- receive a clear score
- get simple explanations
- see better alternatives

Pickly is NOT a panic app.
We do NOT use fear or manipulation.

Pickly is a clarity app:
We help users make better grocery decisions quickly and calmly.

---

## 🎯 MVP Goal

Build a simple, fast, clean iOS app with:

- clear product scoring
- human-readable explanations
- strong alternatives feature
- minimal but polished UI

---

## ❌ Strict MVP Scope

DO NOT add:

- ❌ Community features
- ❌ Social feed
- ❌ Followers / likes
- ❌ Chat
- ❌ Water / cosmetics / air / etc.
- ❌ Complex backend
- ❌ AI-generated fake data

ONLY grocery / supermarket products.

---

## 🧱 Core Screens

1. Onboarding
2. Home / Search
3. Scan (barcode)
4. Product Result (most important)
5. Alternatives
6. Saved
7. Profile
8. Paywall (placeholder)

---

## 🔥 Product Philosophy

- Explain, don’t scare
- Clarity over fear
- Fast decisions
- Trust through transparency
- Alternatives are core value

---

## 🧾 Product Result Screen (Critical)

Must show:

- product image
- name
- brand
- verdict (Great / Good / Okay / Not great)
- score (0–100)
- short summary
- "Why this score"
- "What to watch"
- "For you" (personalized)
- "Better alternatives"
- confidence indicator
- save button

---

## 🗣 Tone of Voice (IMPORTANT)

NEVER use:
- "dangerous"
- "toxic"
- "harmful"

USE:
- "Contains more sugar than similar products"
- "May not be the best choice if you're reducing sugar"
- "Better as an occasional option"
- "You might prefer one of the alternatives below"

---

## 🔄 Alternatives Feature

Always suggest better products when possible.

Each alternative must include:
- name
- brand
- score
- short reason

Examples:
- "Less added sugar"
- "Shorter ingredient list"
- "Higher protein"
- "Lower sodium"

---

## 🧍 Personalization

User preferences may include:
- sensitive digestion
- low sugar
- low sodium
- vegetarian / vegan
- gluten-free

Use softly in UI:
- "May not be ideal for sensitive digestion"

NO medical claims.

---

## 📊 Data Model

### Product
- id
- barcode
- name
- brand
- category
- image
- ingredients
- nutrition
- score
- verdict
- reasons
- warnings
- positives
- alternatives
- confidence

### UserPreferences
- sensitivities
- dietary preferences

### SavedProduct
- productId
- date

---

## 🧮 Scoring Rules (MVP)

Based on:
- added sugar
- sodium
- saturated fat
- ingredient count
- additives
- positives (protein, fiber)

Score MUST be explainable.

---

## 🤖 AI Usage Rules

AI is used ONLY for:
- explanation generation
- text simplification

AI MUST NOT:
- generate scores
- invent facts
- hallucinate ingredients

---

## 🎨 UI Guidelines

- SwiftUI
- clean and modern
- calm colors
- not alarmist
- minimal but premium
- readable typography
- strong hierarchy

Better visual quality than Oasis.

---

## 🧭 Navigation

Tab bar:
- Search
- Scan
- Saved
- Profile

NO Community tab.

---

## 🏗 Architecture

- SwiftUI
- MVVM
- Models / ViewModels / Services
- MockProductService for MVP
- No heavy dependencies

---

## 🚫 Hard Rules

DO NOT:

- add Community
- expand scope
- introduce backend prematurely
- over-engineer
- add unnecessary frameworks
- rewrite architecture without reason

---

## ✅ Definition of Done

A feature is complete when:

- UI works in simulator
- logic is separated from UI
- mock data is used correctly
- code is clean and modular
- feature matches MVP scope
- no scope creep introduced

---

## 🧪 Development Strategy

1. Start with mock data
2. Build full user flow
3. Validate UX
4. Then connect real data later

---

## ⚠️ Important Instruction

Before implementing large features:
- propose a plan
- keep scope minimal
- focus on working prototype first