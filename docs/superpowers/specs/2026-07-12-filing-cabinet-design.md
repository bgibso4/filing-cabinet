# Filing Cabinet — Design Spec

- **Status:** Draft. Next: mock-driven design phase in Claude Design (see §15).
- **Requirements:** `2026-10-10-filing-cabinet-requirements.html` defines what v1 does. Where the two documents conflict, the requirements document wins.
- **Date:** 2026-07-12
- **Name:** **Filing Cabinet** (chosen 2026-10-10; formerly the working title "DocuScan", which is taken). The cabinet keeps what matters; the cleanup clears out the rest. An old, unmaintained "Filing Cabinet" iPad app exists. App Store names must be unique, so a release would use a longer store name (e.g. "Filing Cabinet: Self-Cleaning Docs") unless that listing is gone. Run a trademark check before any release.
- **Destination:** Personal tool first (build for the author's own use); possible App Store release later.

---

## 1. Summary

Filing Cabinet is a private, Photos-style library **just for personal documents** — IDs, receipts, notes, cards, and forms. It scans them with Apple's built-in document camera, understands them on-device with the iOS 26 Vision engine, auto-files them into smart collections, and **cleans itself up** over time.

The pitch is **organized + self-cleaning + private** — *not* "a scanner." Apple gives away scanning for free; the value here is the tidy, self-maintaining, personal-life gallery around it.

## 2. Positioning & market context

Condensed from competitive research (see conversation history for sourced detail):

- **Scanning is a commodity.** The capture engine (`VNDocumentCameraViewController`, VisionKit) has existed since iOS 13 and is what Notes, Files, and the new iOS 26 Preview app all use. We cannot out-scan Apple because we *are* calling Apple's scanner.
- **The genuinely new iOS 26 capability is document *understanding*:** `RecognizeDocumentsRequest` (Vision) — on-device OCR (26 languages), table/list structure, and entity detection (dates, currency, emails, phone numbers). This is our smart layer.
- **"Separate from the camera roll" is table stakes** — nearly every dedicated scanner already sandboxes scans. The differentiated combination nobody ships together is: **self-cleaning library + personal-life gallery + iCloud-native privacy.**
- **Tailwinds:** Microsoft Lens retired (Dec 2025); iOS 26 Photos redesign is drawing clutter complaints.
- **Direct competitors found while naming (2026-10-10):** *Tuck — Save Anything* (iOS 26, private, on-device OCR, keyword smart collections, iCloud sync), *Sift: PDF Scanner & OCR* (auto-names and files scans by type, no servers), *SafeKeep*, *Fold & File*, *fileee*, and an old *Filing Cabinet* iPad app. None of them advertises automatic cleanup, which is still our wedge.
- **Risks:** Apple sherlocking (Preview app; Digital ID in Wallet for official IDs); crowded/commoditized category; AI "declutter" startups (Filex AI, Captr) circling the same wedge. Our moat is the *organization + cleanup + UX*, not the scan.

## 3. Goals & non-goals

**Goals (MVP):**
- Capture multi-page documents with Apple's document camera.
- Understand each scan on-device (OCR + entity extraction) and auto-classify it into a smart collection.
- Present a fast, memory-efficient, Photos-style gallery.
- Let scans auto-clean when their expiry passes: a collection-default lifespan, overridable per scan. Expired scans go to Trash, which keeps them 30 days.
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

- **Platform:** **iOS 27 minimum** (decided 2026-10-10; see the requirements doc §4). iPhone only for MVP.
- **Auto-filing:** Foundation Models (`SystemLanguageModel`), used only when its availability check passes. Otherwise the user picks the collection.
- **UI:** SwiftUI.
- **Capture:** `VNDocumentCameraViewController` (VisionKit) via `UIViewControllerRepresentable`. Handles de-skew, crop, lighting correction, multi-page.
- **Understanding:** `RecognizeDocumentsRequest` (Vision, iOS 26) per page → OCR text + detected entities.
- **Persistence:** SwiftData for metadata (CloudKit-ready, enabling the phase-2 sync path). Image files stored on disk; the DB holds file references + metadata + OCR text.
- **Images:** HEIC on disk for originals; separate downsampled thumbnails for the grid.

## 6. Architecture overview

Four cooperating units, each with one job and a clear interface:

1. **Capture** — presents the document camera, returns an ordered set of corrected page images. Knows nothing about storage or classification.
2. **Understanding** — takes page images, runs Vision, returns `{ fullText, detectedEntities }` per scan. Pure, testable, no UI.
3. **Classification** — takes `{ fullText, detectedEntities, pageAspectRatio }` and returns an optional suggested `collection`. v1 has one implementation backed by Foundation Models, and it returns nil when the model is unavailable. Callers depend on a protocol, so hand-written rules (needed before an App Store release) and Core ML can be added later without changing callers.
4. **Library** — owns the SwiftData store, on-disk image files, thumbnail cache, collection queries, and the cleanup engine. Everything else talks to it through a narrow store interface.

Flow: **Capture → Understanding → Classification → Library (persist) → UI (browse)**. The cleanup engine is a background process inside Library.

**Cleanup engine — extensible by design (open/closed).** New rule *types* must drop in without modifying existing code. MVP ships exactly one rule type, but the seams are built now:

- A **`CleanupTrigger`** is a `Codable` value describing *when* a rule fires. MVP ships one case, `.expired`. It matches scans whose effective expiry (the scan's override, otherwise its collection's default lifespan from `createdAt`) has passed. Future cases (`.count(keepNewest:)`, `.size(...)`) are purely additive.
- Each trigger maps to a **`CleanupEvaluating`** strategy — `func matches(_ scans: [Scan], on date: Date) -> [Scan]` — a pure, unit-testable function with no persistence or UI.
- A small **factory/registry** resolves `CleanupTrigger → CleanupEvaluating`. Adding a rule type = add an enum case + one evaluator + register it; the `CleanupEngine`, the store, and the rule-editing UI are untouched.
- The **`CleanupEngine`** only orchestrates: load enabled rules → resolve each rule's evaluator via the factory → collect matched scans (never "Forever" ones) → move them to Trash → schedule one batched notification → purge Trash items older than 30 days. It never references a concrete trigger type.

## 7. Data model (SwiftData)

- **Scan**
  - `id`, `createdAt`
  - `title` (auto-derived from OCR, user-editable)
  - `collection` (enum: `wallet`, `receipts`, `notes`, `documents`, `throwaways`)
  - `expiryOverride` (nil = follow the collection's default lifespan; otherwise a custom date or `forever`)
  - `fullText` (concatenated OCR, for search)
  - `extractedData` (structured entities: dates, amounts, etc.)
  - `pages` (to-many `Page`, ordered)
  - `isFavorite`, `trashedAt` (nil unless in Trash)
- **Page**
  - `order`, `imageFileName` (full-res HEIC on disk), `thumbnailFileName`, `width`, `height`
- **CollectionSettings**
  - `collection`, `defaultLifespan` (a number of days or `forever`). Editing it changes the effective expiry of every scan whose `expiryOverride` is nil, because effective expiry is computed and never stored.
- **CleanupRule**
  - `trigger` (Codable `CleanupTrigger`; MVP: `.expired`), `enabled`, `lastRun`. MVP has one built-in rule. The type exists so future triggers are additive (§6).

**Collections** and the **Recent** / **All** views are **dynamic queries** over `collection` / `createdAt`, not stored rows. There are no tags and no archive in v1 (see the requirements doc).

## 8. Key flows

1. **Scan → understand → file**
   Tap **+** → document camera → multi-page corrected images → background OCR + entity extraction → generate thumbnails → if Foundation Models is available, suggest a collection → **review sheet** (title, collection, expiry; all editable; the collection is a required pick when there's no suggestion) → save to Library.
2. **Browse**
   Home (layout decided in the mocks) → a collection, Recent, All, or Favorites → grid of thumbnails → tap → **detail** (swipe pages, zoom, see the expiry status, copy text, edit title/collection/expiry, favorite, share/export, delete to Trash).
3. **Self-cleanup**
   The cleanup engine runs on launch and via background refresh. Scans whose effective expiry has passed move to **Trash** (`trashedAt` set), and one batched local notification says something like "4 scans moved to Trash, restore within 30 days". Trash supports restore, which sets the expiry to Forever, plus delete-now and empty. Items are permanently purged 30 days after entering Trash.
4. **Integrate back out**
   Export a scan as **PDF** or **images** via the share sheet; **Save to Photos** / **Save to Files** when the user explicitly wants it in the camera roll or filesystem.

## 9. Smart classification approach (honest note)

Vision gives us OCR and entities, not a "receipt vs. ID" classifier. In v1 the **Classification** unit uses the on-device **Foundation Models** model with guided generation constrained to the `collection` enum. It is called only when `SystemLanguageModel.default.availability` is `.available`.

- When the model is unavailable (ineligible device, Apple Intelligence off, model not ready), there's no suggestion and the user picks.
- A throwaway experiment on 20–30 of the author's real scans checks accuracy before the implementation plan.
- Before an App Store release, a hand-written rules implementation fills the gap on non-AI devices. Examples: Wallet from the ID-1 card aspect ratio (~1.59:1) plus keywords; Receipts from currency amounts plus "TOTAL"/"TAX" plus a date. It sits behind the same protocol.

## 10. Memory & storage strategy

This is the real engineering (it's effectively a Photos-style app):

- Store originals as **HEIC files on disk** (app container). The DB never holds image blobs — only file references.
- Generate a small (~400 px) **thumbnail per page** on import; the grid renders **thumbnails only**.
- Downsample using `CGImageSource` / ImageIO on a background queue — decodes thumbnails **without** loading full-res into RAM.
- Two-tier thumbnail cache: `NSCache` in memory + on-disk cache.
- `LazyVGrid` for the gallery; never decode full-res for grid cells.
- Full-text search runs over stored OCR `fullText`.

## 11. MVP scope (Phase 1 — iPhone, personal)

See the requirements doc §3 (user stories) and §4 (non-functional requirements). In brief:

- Multi-page scan capture (VisionKit).
- On-device OCR + entity extraction (`RecognizeDocumentsRequest`) + full-text search.
- Five collections (Wallet, Receipts, Notes, Documents, Throwaways), auto-suggested when Apple Intelligence is available, with one-tap override.
- Photos-style gallery: home → collection → grid → detail. Favorites.
- Per-scan expiry from collection defaults (editable in Settings) with per-scan overrides. Expired scans go to Trash, are purged after 30 days, and trigger a batched notification. Engine built for additive rule types per §6.
- Export: PDF / images via share sheet; Save to Photos / Save to Files.
- Local, on-device storage; memory-efficient thumbnails. iCloud device backup only; SwiftData model kept CloudKit-ready.

## 12. Later phases (Phase 2+)

See the requirements doc §6 for the full future list. It is split into "Before App Store release" (hand-written classification rules, per-scan document lock) and "Someday" (field search, tags, custom collections, an Expiring view, iCloud sync, camera-roll backlog import, Files app visibility, more cleanup rule types, widgets/Shortcuts/share extension, Core ML). Monetization, *if* released: favor a one-time purchase or a generous free tier (research flagged subscription fatigue).

## 13. Testing strategy

- **Unit tests** for the pure units: Classification (an unavailable model yields no suggestion; the model is behind a protocol so tests use a stub), Understanding output shape, effective-expiry calculation (collection default vs. override vs. Forever, Settings changes), and each `CleanupEvaluating` strategy in isolation (expiry boundaries, Forever exemption) plus the engine's 30-day Trash purge. Real-model accuracy is measured by the pre-plan experiment, not unit tests. The evaluator/registry seam means new rule types get their own focused tests without touching the engine's.
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

Settled 2026-10-10: minimum OS (iOS 27), the collection set, and the cleanup flow. See the requirements doc §5 for the decisions log.

Still open:

- Whether the home screen leads with Collections or a Recent stream. Settled in the Claude Design mocks, built from a Filing Cabinet design system.
- Accuracy of automatic filing. Settled by the real-scan experiment before the implementation plan.
