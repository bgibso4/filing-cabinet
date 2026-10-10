# DocuScan — Design Spec

- **Status:** Draft. Next: mock-driven design phase (see §15).
- **Date:** 2026-07-12
- **Working title:** DocuScan (**taken** — confirmed 2026-10-09: at least four App Store apps use "DocuScan" and a live US "DOCUSCAN" service mark exists. A new name is required.)
- **Destination:** Personal tool first (build for the author's own use); possible App Store release later.

---

## 1. Summary

DocuScan is a private, Photos-style library **just for personal documents** — IDs, receipts, notes, cards, and forms. It scans them with Apple's built-in document camera, understands them on-device with the iOS 26 Vision engine, auto-files them into smart collections, and **cleans itself up** over time.

The pitch is **organized + self-cleaning + private** — *not* "a scanner." Apple gives away scanning for free; the value here is the tidy, self-maintaining, personal-life gallery around it.

## 2. Positioning & market context

Condensed from competitive research (see conversation history for sourced detail):

- **Scanning is a commodity.** The capture engine (`VNDocumentCameraViewController`, VisionKit) has existed since iOS 13 and is what Notes, Files, and the new iOS 26 Preview app all use. We cannot out-scan Apple because we *are* calling Apple's scanner.
- **The genuinely new iOS 26 capability is document *understanding*:** `RecognizeDocumentsRequest` (Vision) — on-device OCR (26 languages), table/list structure, and entity detection (dates, currency, emails, phone numbers). This is our smart layer.
- **"Separate from the camera roll" is table stakes** — nearly every dedicated scanner already sandboxes scans. The differentiated combination nobody ships together is: **self-cleaning library + personal-life gallery + iCloud-native privacy.**
- **Tailwinds:** Microsoft Lens retired (Dec 2025); iOS 26 Photos redesign is drawing clutter complaints.
- **Risks:** Apple sherlocking (Preview app; Digital ID in Wallet for official IDs); crowded/commoditized category; AI "declutter" startups (Filex AI, Captr) circling the same wedge. Our moat is the *organization + cleanup + UX*, not the scan.

## 3. Goals & non-goals

**Goals (MVP):**
- Capture multi-page documents with Apple's document camera.
- Understand each scan on-device (OCR + entity extraction) and auto-classify it into a smart collection.
- Present a fast, memory-efficient, Photos-style gallery.
- Let scans auto-clean via age-based rules (soft-delete with a safety net).
- Keep everything on-device and private.

**Non-goals (for now):**
- Not a business/PDF-workflow tool (no sign/annotate/fax/OCR-export pipelines).
- Not a cloud service or multi-user product.
- Not trying to beat Apple on raw scan quality — we build on it.
- No account/login. No third-party cloud.

## 4. Users & primary use cases

Primary user: the author. Real jobs-to-be-done:
- "Scan my driver's license / insurance card and find it instantly later."
- "Snap receipts that quietly disappear after they stop mattering."
- "Photograph class notes / forms without polluting my camera roll."
- "Grab a throwaway doc (coat-check tag) that auto-deletes in a week."

## 5. Tech stack & platform

- **Platform:** target **iOS 27**; **iOS 26 is the hard minimum** (required for `RecognizeDocumentsRequest`). iPhone only for MVP.
- **UI:** SwiftUI.
- **Capture:** `VNDocumentCameraViewController` (VisionKit) via `UIViewControllerRepresentable`. Handles de-skew, crop, lighting correction, multi-page.
- **Understanding:** `RecognizeDocumentsRequest` (Vision, iOS 26) per page → OCR text + detected entities.
- **Persistence:** SwiftData for metadata (CloudKit-ready, enabling the phase-2 sync path). Image files stored on disk; the DB holds file references + metadata + OCR text.
- **Images:** HEIC on disk for originals; separate downsampled thumbnails for the grid.

## 6. Architecture overview

Four cooperating units, each with one job and a clear interface:

1. **Capture** — presents the document camera, returns an ordered set of corrected page images. Knows nothing about storage or classification.
2. **Understanding** — takes page images, runs Vision, returns `{ fullText, detectedEntities }` per scan. Pure, testable, no UI.
3. **Classification** — takes `{ fullText, detectedEntities }`, returns `{ inferredType, confidence, suggestedTags }` via a heuristics ruleset. Pure and unit-testable; upgradeable to Core ML later without changing callers.
4. **Library** — owns the SwiftData store, on-disk image files, thumbnail cache, smart-collection queries, tags, and the cleanup engine. Everything else talks to it through a narrow store interface.

Flow: **Capture → Understanding → Classification → Library (persist) → UI (browse)**. The cleanup engine is a background process inside Library.

**Cleanup engine — extensible by design (open/closed).** New rule *types* must drop in without modifying existing code. MVP ships exactly one rule type, but the seams are built now:

- A **`CleanupTrigger`** is a `Codable` value describing *when* a rule fires. MVP ships one case, `.age(thresholdDays:)`; future cases (`.count(keepNewest:)`, `.size(...)`) are purely additive.
- Each trigger maps to a **`CleanupEvaluating`** strategy — `func matches(_ scans: [Scan], on date: Date) -> [Scan]` — a pure, unit-testable function with no persistence or UI.
- A small **factory/registry** resolves `CleanupTrigger → CleanupEvaluating`. Adding a rule type = add an enum case + one evaluator + register it; the `CleanupEngine`, the store, and the rule-editing UI are untouched.
- The **`CleanupEngine`** only orchestrates: load enabled rules → resolve each rule's evaluator via the factory → collect matched non-pinned scans → apply the rule's `action` → schedule the notification. It never references a concrete trigger type.

## 7. Data model (SwiftData)

- **Scan**
  - `id`, `createdAt`
  - `title` (auto-derived from OCR, user-editable)
  - `inferredType` (enum: `id`, `receipt`, `note`, `card`, `document`, `other`) + `confidence`
  - `fullText` (concatenated OCR, for search)
  - `extractedData` (structured entities: dates, amounts, etc.)
  - `tags` (to-many `Tag`)
  - `pages` (to-many `Page`, ordered)
  - `isArchived`, `trashedAt` (nil unless in Trash), `isPinned` (exempt from cleanup)
- **Page**
  - `order`, `imageFileName` (full-res HEIC on disk), `thumbnailFileName`, `width`, `height`
- **Tag**
  - `name`, `color`, `isSmart` (auto-applied) vs. user-created
- **CleanupRule**
  - `name`, `scope` (a type and/or tag), `trigger` (Codable `CleanupTrigger`; MVP: `.age(thresholdDays:)`), `action` (`archive` | `softDelete`), `enabled`, `lastRun`
  - Storing `trigger` as a `Codable` value (persisted as `Data`) means new rule types add cases, not schema columns — no SwiftData migration churn per rule type. See §6 for the evaluator/registry pattern.

**Smart Collections** (IDs, Receipts, Notes, Recent, All) are **dynamic queries** over `inferredType` / `createdAt`, not stored rows — cheap and self-updating. Tags are the user-extensible layer on top.

## 8. Key flows

1. **Scan → understand → file**
   Tap **+** → document camera → multi-page corrected images → background OCR + entity extraction → classification assigns `inferredType` + suggested tags → generate thumbnails → **review sheet** (title / type / tags, all editable) → save to Library.
2. **Browse**
   Home = Collections (IDs · Receipts · Notes · Recent · All) → tap → grid of thumbnails → tap → **detail** (swipe pages, view extracted data, copy text, edit tags, pin, share/export, toggle cleanup exemption).
3. **Self-cleanup**
   Cleanup engine runs on launch and via background refresh → for each enabled rule, matching non-pinned scans move to **Trash** (`trashedAt` set) → a **local notification** warns before permanent removal ("12 receipts will be deleted in 7 days — review?"). Trash view supports restore. Permanent purge happens only after the grace period.
4. **Integrate back out**
   Export a scan as **PDF** or **images** via the share sheet; **Save to Photos** / **Save to Files** when the user explicitly wants it in the camera roll or filesystem.

## 9. Smart classification approach (honest note)

iOS 26 does **not** provide a "receipt vs. ID" classifier. Our **Classification** unit is *our* heuristics layer over the OCR text + detected entities:

- Keyword/entity rules → a document type (e.g. currency amounts + merchant-like line → `receipt`; "DRIVER LICENSE" / "DL No" → `id`; mostly handwriting / no structured entities → `note`).
- Returns a type + confidence + suggested tags; the review sheet lets the user override in one tap.
- Designed as a pure function so it can later be swapped for / augmented by a small Core ML text classifier without touching callers.

## 10. Memory & storage strategy

This is the real engineering (it's effectively a Photos-style app):

- Store originals as **HEIC files on disk** (app container). The DB never holds image blobs — only file references.
- Generate a small (~400 px) **thumbnail per page** on import; the grid renders **thumbnails only**.
- Downsample using `CGImageSource` / ImageIO on a background queue — decodes thumbnails **without** loading full-res into RAM.
- Two-tier thumbnail cache: `NSCache` in memory + on-disk cache.
- `LazyVGrid` for the gallery; never decode full-res for grid cells.
- Full-text search runs over stored OCR `fullText`.

## 11. MVP scope (Phase 1 — iPhone, personal)

- Multi-page scan capture (VisionKit).
- On-device OCR + entity extraction (`RecognizeDocumentsRequest`) + full-text search.
- Heuristic auto-classification into ~5 smart collections + suggested tags, with one-tap override.
- Photos-style gallery: Collections → grid → detail.
- Tags (create, apply, filter).
- **Age-based cleanup rules only** (one rule *type*; multiple rules allowed), action = archive or soft-delete, with grace period + local notification + Trash/restore. Pinned scans exempt. Engine built for additive rule types per §6 — only `.age` is implemented now.
- Export: PDF / images via share sheet; Save to Photos / Save to Files.
- Local, on-device storage; memory-efficient thumbnails.
- SwiftData model designed **CloudKit-ready** for phase 2.

## 12. Later phases (Phase 2+)

- **CloudKit sync** (iPhone + iPad + Mac).
- **Face ID / biometric app-lock** for the sensitive-docs use case.
- **Batch-import & classify the existing camera-roll backlog** (the "clean up my old school album" feature).
- Additional cleanup rule *types* (count-based, size-based) — add a `CleanupTrigger` case + one `CleanupEvaluating` strategy + register it; no changes to the engine, store, or UI (see §6).
- Core ML classifier to improve accuracy.
- Shortcuts, share-extension (scan from other apps), widgets.
- Monetization *if* released — favor one-time purchase or a generous free tier (research flagged subscription fatigue).

## 13. Testing strategy

- **Unit tests** for the pure units: Classification heuristics (fixture document images → expected types/tags), Understanding output shape, and each `CleanupEvaluating` strategy in isolation (threshold boundaries, pinned exemption) plus the engine's grace-period purge. The evaluator/registry seam means new rule types get their own focused tests without touching the engine's.
- **Data-model tests** for SwiftData relationships and smart-collection queries.
- UI verification stays mostly manual for a personal app.

## 14. Risks & mitigations

| Risk | Mitigation |
|---|---|
| Classification accuracy (heuristics) | Start simple; make override one tap; upgrade to Core ML later. |
| Apple sherlocking (Preview, Wallet Digital ID) | Compete on organization + cleanup + UX, not scanning. |
| Sensitive data (IDs) stored unlocked in MVP | On-device only; device passcode protects; add Face ID lock in phase 2. |
| Memory blowups on large libraries | Thumbnails-only grid, ImageIO downsampling, disk-backed originals, lazy loading. |
| Category is crowded | Lean, personal, private niche; not competing on business PDF features. |

## 15. Open questions

- **App name** — DocuScan is taken (see header). Needs a naming pass.
- **Minimum OS** — ship iOS 27-only, or keep iOS 26 support?

**Settled in the design phase, not here.** Next we work mock-first: flow diagrams, then high-fidelity mocks, then interactive mocks (Claude Design). These questions are answered there:

- The exact smart-collection set for v1 (ID / Receipt / Note / Card / Other?). This needs a proper decision, not a default.
- The cleanup flow end to end: what a rule looks like to the user, archive vs. soft-delete, grace-period length, and whether it's per-rule or global. This walkthrough re-examines §6 and §8.3.
- Whether the home screen leads with Collections or a single Recent stream.
