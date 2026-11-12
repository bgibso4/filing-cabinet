# Plan 5 · Apple Intelligence: smart filing and search · design

2026-11-11 · brainstorm with Ben (agent `plan5`). Demo: https://claude.ai/artifact/E6NGvA4p6DxXM343GF3dmo ·
tile and search-row options: https://claude.ai/artifact/6CX5ocZEi1cRpeC2fjPCyk. Requirements
(`docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html`) still hold except where this document changes
them; the changes are listed in §8.

## 1 · Intent

Scanning should feel seamless: when the camera closes, the scan already has a good name and the right collection, and
you tap Save. Later you should find it by what it is, not only by the words printed on it ("ID" finds a driver's
license that never prints "ID"). Ben: Apple Intelligence "could add the most value for us"; the two things it offers
are "improved naming, and collection identification, so that scans are seamless" and search that does "inference of
what the doc is especially if there is not much text on it".

## 2 · Goals

1. **One read per scan, at save time.** The on-device model reads each new scan once and returns three things: a
   title, one collection from the collections that exist at that moment, and a handful of hidden search words. Ben:
   "you would need to do it at scan time to have the app be able to scale properly and stay performative". The model
   never runs while you search.
2. **Better titles.** Who and what, the way you'd say it: "City Pharmacy receipt", "Driver's license",
   "2025 W-2 · Northwind", "Biology notes · cell respiration", "Coat check ticket". Short (about 40 characters at most).
3. **Collection from whatever collections exist.** The model is handed the current list (name and description of
   each) on every read, never a fixed five. Ben: "it should just easily support that in the future" (custom
   collections). Today the list is the five built-ins.
4. **The review card from the requirements, built.** Today review opens the full sheet. Plan 5 builds the slim card:
   shimmer and "Reading your scan…", the sweep, rows fade in, Save turns on, light haptic, VoiceOver reads the
   suggestion; tap the card to open the full sheet; your own pick wins if you choose before it lands. **You always tap
   Save** (Ben: "you still should save though"). With no suggestion within about 5 s, the card grows into the full sheet
   with the text-rule title and "Choose a collection" (requirements' mock ULgeFhB5rS6qNzMwLebT5N, option 3). Reduce
   Motion as the requirements say.
5. **Search by what a scan is.** The hidden words are stored with the scan and matched by Search alongside title and
   page text, using Plan 4's folded byte matching (no model at search time, same speed budget).
6. **Older scans get search words too**, in the background, while the app is open. Their titles and collections are
   never changed (my call).
7. **Scan date on every grid tile**, with or without Apple Intelligence (§4).
8. **A test set of made-up scans** with an evaluation report (§6).
9. **Settings switch** "Apple Intelligence · Names, files and finds your scans" (§5).

## 3 · Non-goals and anti-goals

- **Not** natural-language sentence search. Ben: "not very often are you going to describe a doc ... with more than 1-2
  words".
- **Not** auto-saving or filing without the Save tap.
- **Not** the date printed on a document, or backfilled expiry (issue #88).
- **Not** a visible tags feature: the hidden words are never listed or edited anywhere (tags are out of v1).
- **No "kind" field.** The model returns title, collection and words only.
- **Not** Private Cloud Compute or any network model: requirements say automatic filing runs on-device and documents
  never leave the phone. No document content in analytics (counts only).
- **Not** custom collections themselves (later); only the readiness for them.
- **Not** the 20–30 real-scan experiment (Ben: "I dont want to do the 20-30 scan test right now"). Replaced by §6.
- **Anti-goals (a failure even if it works):** an error message when the model is slow, unavailable or refuses; Search
  getting slower; any scan ending up without a title or unsaveable because of the model; the model renaming or
  re-filing a scan you already saved; a suggestion overwriting a collection or title you chose or typed.

## 4 · The tile's second line

At the default text size the tile stays at two lines (Ben: "i dont want to see it wrap to 3 usually"). The second line
becomes the scan date, a middot, then the time left in short units (Ben: "the d and mo and yr could be good
abreviations"):

| Case | Shows |
|---|---|
| a year or more | `Sep 28 · 2 yr left` |
| 60 days to a year | `Nov 11 · 3 mo left` |
| under 60 days | `Sep 28 · 59d left` |
| last week | `Sep 28 · 7d left` in orange semibold, as today |
| no expiry | `Mar 4 · Forever` |

Measured at 12 pt SF Pro against a 114 pt tile: the widest, `May 28 · 11 mo left`, is about 104 pt. The date is the
scan date, month and day only (my call: no year, matching Search's rows). Keeping "left" and spacing ("7d", "3 mo",
"2 yr") are my calls. Details and Trash keep their full wording. Accessibility sizes may wrap. Every grid gets this
(collections, Recent, All Scans, Favorites); Trash tiles keep their days-left line (my call).

## 5 · Behaviour details

**Availability.** Uses the system model's availability. Not eligible, Apple Intelligence off, or model not downloaded:
everything behaves as today (full sheet, "Choose a collection", text-rule title, search on title and text). When the
model becomes available later, the background pass picks up the older scans.

**Settings.** The row from 10-01 with the new subtitle "Names, files and finds your scans" (my call; replaces "Suggests
titles and collections"). When Apple Intelligence isn't available, the switch is off and dimmed and the footer says so
(10-06 already shows that state). While older scans are being read, a footer line "Reading your older scans so search
can find them · 12 of 91" with a thin progress bar (my call; demo). Turning the switch off stops new reads; search
words already stored keep working (my call).

**Review timing.** Reading the page text (Vision) already starts when the camera closes; the model runs after it. The
~5 s limit counts from when the card appears. If it lands after the card has grown into the sheet, it's dropped (no
late jump). If you rescan, the old read is cancelled. If you typed a title or picked a collection, the suggestion only
fills what you haven't touched.

**What the model sees.** The recognized text of the scan (all pages, trimmed to fit the context), and the first page's
image if the spike shows that helps (especially low-text scans like cards and stubs). The collection list with each
collection's description. Output is structured (`@Generable`), with the collection constrained to the given list's
identifiers; an identifier not in the list counts as no suggestion.

**Failures.** Unavailable, refusal (guardrails), context too long, decoding failure, timeout: no suggestion, silently,
logged with `os.Logger` and counted in analytics with no content. A failure on save-time words means the scan is saved
without them and the background pass retries later.

**Settled after the builder check (my calls, veto any).**
- *Saving before the read finishes:* the read keeps going after Save (like today's page-text M2 path) and writes only
  the search words when it lands; title and collection are never changed after Save. If the app is closed first, the
  background pass picks the scan up.
- *Opening the card yourself before it lands:* the sheet still fills the fields you haven't touched, with a quick
  fade. Only the timeout's growth into the sheet stops waiting and drops a late result.
- *Scanning from inside a collection:* that collection is pre-selected and wins (requirements). The slim card still
  shows, Save is on straight away, and the title fills in when it lands unless you saved or typed first (then the
  text-rule title is used).
- *The switch:* on by default when Apple Intelligence is available, stored as an app preference. Off means review,
  titles and the background pass behave exactly as on an iPhone without Apple Intelligence; search words already
  stored keep matching.

**Search rows** (Search.dc.html, 08-03). Order of evidence for the second line: a page-text match shows Plan 4's
snippet; else a title match shows the start of the text as today; else a hidden-word match shows a sparkle and
"Matches **ID**" (the query, bolded). The hidden words themselves never appear. Without Apple Intelligence on this
iPhone, hidden words aren't stored, so nothing changes. Prefix matching on hidden words ("lic" finds "license") follows
whatever Plan 4's matching does for text.

**Older scans.** A background pass while the app is in the foreground, one scan at a time, oldest-unread first, pausing
when the app leaves the foreground. Uses the stored page text plus the first page image. Writes only search words, and
a marker that the scan has been read (so it isn't read twice, and a later prompt version can re-read).

## 6 · The test set of made-up scans

- At least **15 made-up scans per collection** (75+), Ben: "make sure youve got 15 at elast for each collection".
  Variety within each: Wallet (licenses, passports, insurance, membership, business cards, work badges), Receipts
  (grocery, café, gas, pharmacy, hardware, online order printouts), Notes (handwritten-style class notes, to-do lists,
  call notes), Documents (lease, W-2, registration, letters, vaccination record, bills), Throwaways (coat check,
  parking, valet, ticket stubs, wifi slips).
- **A couple lower quality in each collection** (Ben: "make a couple slightly lower quality"): blur, skew, low
  contrast, shadow, crumple or JPEG noise.
- A handful of cases for a **custom collection** (e.g. a made-up "Taxes") to prove the list is honoured.
- Each case records: the right collection, an acceptable title (or a few), and 2–4 searches that must find it by
  hidden words. All names, numbers and addresses are fake ("Sample State", "Alex Morgan"). No personal documents.
- A report like `make compare-readers`: per-collection accuracy, title judgement, search-word recall, timing. It
  runs on a Mac with Apple Intelligence and is **not a CI gate** (CI has no model). How the images are made, and how
  titles are judged, are left to the builder.

## 7 · Constraints

AGENTS.md hard rules apply (iOS 27 minimum, no `#available`, Swift 6, tokens only, middots, localized copy, `os.Logger`,
one type per file, injected collaborators, no personal documents). Fast tests must not need the real model: a fake
suggester behind a protocol seam (a real seam: the system model vs. the fake). New UI-test launch flags for the
suggester's outcomes (arrives, slow, unavailable). The schema change for search words and the read marker is a
SwiftData migration (SchemaV4). Mock-driven: the slim card follows SZ5Ntg5vThvnYN3KAgv14Q (option B, shimmer and
sweep) and the review screens in `design/`; tile and Settings changes follow the demo.

## 8 · Changes to the requirements (to write in when the branch starts)

- Accuracy experiment on real scans → the made-up test set (§6).
- Settings subtitle wording (§5).
- Search also matches what a scan is (new).
- Tile second line (§4).
- Older scans get search words in the background (new).

## 9 · Left to the builder

Prompt wording and instructions; the exact `@Generable` shape; how many hidden words (about 4–8); trimming long text;
whether the image goes in (decided by the spike); how test images are generated; title judging in the report; the
background pass's pacing; where the suggester lives in the module map (Understanding is the natural home, Mac-buildable).

## 10 · First task: spike on Ben's phone

Measure on a real iPhone: time from camera close to suggestion (text only vs text + image), accuracy on a dozen of the
made-up scans, and whether image input improves low-text scans. The image decision comes from it. **The spike stops for Ben** (his call: "lets measure first before making any decisions"): if a suggestion takes well over ~5 s, Ben decides how to respond with the numbers in front of him, before any task that depends on the timing starts. Options on the table then: raise the wait, make the read faster (no image, less text), or keep the full sheet and run the model only after Save for search words.
