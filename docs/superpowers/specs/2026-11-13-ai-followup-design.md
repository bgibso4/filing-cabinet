# AI follow-up: better titles, a longer wait, TelemetryDeck: design

Date: 2026-11-13 · Branch: `ai-followup` (from main after Plan 6, PR #96) · Issues: #94, #90, #3, #97 · Ben's page: https://claude.ai/artifact/28b1XF7A7v6sRHbgzyW7vW

## Why

Ben's phone test of Plan 5 (2026-11-12): about half his scans got no suggestion, and the titles that came were verbose
("Body scan composition analysis" for an InBody report; he wants "InBody Report"). Suggestions that work and read well
are the point of the Apple Intelligence feature, and TestFlight (every green merge to `main` uploads once Plan 6 is in)
is where friends first see it. TelemetryDeck (#3) must be connected before TestFlight so we learn how the app is used.

Success: on Ben's phone almost every scan gets a suggestion, and the titles are ones he would have typed himself.

## Goals

1. **The wait is 10 s** (was 5 s, E1). Ben: "I would rather wait longer"; a quick model never shows the limit, and a
   good suggestion saves typing.
2. **A written definition of a good title**, drawn from Ben's yes/no judgements made while looking at each scan, not
   from rules we guess.
3. **A private real-scan set**: about 30 of Ben's own scans, kept outside the repo, with expected titles from his
   review, run through the same eval as the made-up set.
4. **Better titles**, by approach 2 (below), compared fairly against a refined approach 1; the winner ships.
5. **TelemetryDeck connected** for Release builds.

## Non-goals

- **Dates in titles.** Decided by Ben: no dates for now. Telling repeat documents apart by the printed date is #88
  (moved to App Store 1.0; notes in its comment of 2026-11-13).
- The text-rule titles used without Apple Intelligence (#48, #25). Ben is "less concerned" with them.
- Collection accuracy work beyond what the prompt change brings (93% on the made-up set is acceptable).
- Search words: the words call and its prompt are untouched.
- Plan 6 work of any kind.

## Anti-goals (would be a failure even if it "works")

- Any real scan, its text or its image committed, pushed, uploaded to an artifact or sent to any service. Real scans
  live only in a folder outside the repo and in local files on Ben's Mac.
- Titles that get longer or more descriptive in exchange for "accuracy".
- Analytics carrying any text from a scan, or sending from Debug builds and UI tests.
- Tuning to the made-up set until it scores well while real scans stay poor.

## Constraints

- On-device model only (`SystemLanguageModel.default`), never Private Cloud Compute. Plan 5's E2 (page 1's image goes
  in), E3 (prewarm at camera open), E4 (the split read: title and collection on the card, words after Save) stay.
- Titles stay Title Case (`TitleCasing`) and pass through `SuggestionCleanup`.
- `ScanSuggestion.promptVersion` is **not** bumped for a title-only change: it versions the search words, and bumping
  it would re-run the words pass over every saved scan.
- Evals: iterate on a subset (`CASES=`), then one full run; never a full 30-minute run per tweak.
- TelemetryDeck is already approved as a third-party package (foundations spec §8); pinned with `exact:`, root
  `Package.resolved` updated. No opt-out (Ben's decision in §8).
- AGENTS.md hard rules throughout (no `#available`, `package` access, tokens only, localized copy, etc.).

## Approaches considered (titles)

1. **Prompt only.** The model keeps writing a finished title; instructions and examples are rewritten around Ben's
   judgements. Cheapest, but length and shape are only asked for. Today's prompt already asks for "issuer first, then
   kind, at most 40 characters" and the model still drifts into descriptions and raw page text.
2. **Parts, composed in code.** The filing call answers `name` (the store, company, product, school or subject as
   printed, or empty) and `kind` (what the document is, 1–2 words), plus the collection as today. Code composes
   "‹name› ‹kind›" ("InBody Report", "Harbor Gas Receipt", "Bio 210 Notes"), or just "‹kind›" ("Library Card") when
   there is no name. Shortness becomes structural; the eval can score name and kind separately. Risk: documents that
   don't fit the shape (meeting notes with a person, a 1099 from a client); the review shows how many.
3. **A custom adapter** for the on-device model. Dropped: heavy to train and ship, overkill for a shape problem.

**Chosen (Ben): 2, unless a major refinement of 1 beats it in a fair comparison.** Both are built as eval variants,
run on the same judged cases (made-up and real), and the better one ships. Ties go to 2 (shorter by construction).

## The design

### Part 0: what is failing on the phone (with Part 2's scanning session)
The suggester's success, cancel and outcome lines are `.info`, which iOS keeps in memory only, so the Plan 5 test scans'
lines are gone; and a timeout writes no `Understanding` line (the card gives up in `ReviewModel`). So Part 0 is a live
session (my call): while Ben scans his ~30 real documents for Part 2 **on the current build (5 s wait)**, his phone is
attached and Console streams subsystem `com.cadre.filingcabinet` (categories `Understanding` and `Analytics`, info
messages shown). The "filed in X" timings and `suggestionOutcome` events give the split: answered, timed out (with how
long answered ones took), refusal/guardrail, a wedged streak. Write the counts into #90. No code change needed; once
Part 5 ships, `suggestionOutcome` counts arrive in TelemetryDeck from TestFlight too.

### Part 1: the 10 s wait
`suggestionWaitLimit` in `App/AppEnvironment+Scanning.swift` becomes `.seconds(10)`. The card's behaviour is unchanged
(reading state, then it grows into the sheet when the limit passes). Record as E1 revised in the Plan 5 spec's
"Decided during execution" table with Ben's reason.

### Part 2: the real-scan set (private)
- Ben scans about 30 real documents in the app across all five collections, weighted to what he actually keeps
  (receipts, cards, letters, a couple of InBody reports, notes), and AirDrops page 1 of each (JPEG, or the PDF) to a
  folder outside the repo: **`~/FilingCabinetPrivate/eval/`** (my call). Exporting from the app's Share is fine.
- The eval learns to read an extra case set from a directory given by an environment variable (`PRIVATE=<dir>` on
  `make eval-suggestions`, mapped to e.g. `FC_EVAL_PRIVATE`), holding a `cases.json` of the same shape as the made-up
  one and its images. The private cases are reported in their own column and never mixed into tune/holdout.
- Nothing about this set is committed: no files, no case ids that reveal content, no report excerpts in commits, PRs,
  issues or artifacts. Reports including private cases are written to the private folder, not `build/`.

### Part 3: the review that defines a good title
- A new eval output: a **local HTML review page** (`review.html`, written next to the report; for private cases into
  the private folder) showing, per case, page 1's image, the model's title under each variant, the collection, and for
  each title ✓ / ✗ plus an optional "what I'd call it" box. The page saves Ben's answers as a JSON file he downloads
  (or copies) and hands back. It is opened from disk only; it is never published.
- First round: today's prompt on all made-up cases plus the private set. Ben judges. From his answers:
  - a short **written definition of a good title** (kept in the spec, and summarised in the prompt), e.g. what counts
    as a name, which kinds are allowed, when no name is better;
  - the **expected titles** for the private set (his ✓ answers and typed names) and corrections to the made-up set's
    `titles` lists where his judgement differs (the made-up set's file is committed; its edits are fine).
- A second round after the prompt change: Ben judges both variants' titles side by side on the private set (the decision rule, Part 4).

### Part 4: better titles
- **Variant 2 (parts):** the filing schema becomes `name: String` (may be empty), `kind: String`, `collection` (one of
  the ids, as today). Instructions describe name and kind with examples drawn from Ben's ✓ titles. `SuggestionCleanup`
  composes: trims both, drops a name that repeats the kind, joins "name kind" (keeping the owner's name out is the prompt's job
  alone, as today: code can't tell a person's name from a business's), applies `TitleCasing` and the 40-character limit (a long name is cut before the kind is dropped).
  The composed title is what `ScanSuggestion.title` holds, so nothing downstream changes.
- **Variant 1 (refined prompt):** the same schema as today, instructions rewritten around the definition and Ben's
  examples, with a stricter shape ("2–4 words", "no descriptions").
- Titles with a middot today ("2025 W-2 · Northwind", "Biology Handout · Cell Respiration") don't fit "name kind".
  Ben's review settles whether he wants them; if his ✓ titles need a third part often, variant 2 gains an optional
  `detail` part (joined with " · "), otherwise those expected titles are rewritten to his shape (my call, after the
  review).
- The eval gets a `VARIANT=` switch (1 or 2) so both run on the same cases; the report gains name/kind accuracy for
  variant 2 and keeps title-acceptable for both. Iterate on a subset (the misses plus a few hits, plus the private
  set), then one full run per variant.
- **Scoring.** The loose matcher (`isAcceptableTitle` passes any answer *containing* an expected title) would reward
  longer titles, the anti-goal. It becomes strict: equal to an expected title after folding case, spacing and
  punctuation. The baseline (today's prompt) is re-measured on the edited expected titles with the strict matcher;
  that number, not 60%, is the holdout floor.
- **Decision rule:** **Ben judges both variants side by side** (Ben): after Part 4's iteration, the review page shows each private case with both variants' titles; he ticks the ones he'd keep, and the variant with more ticks wins. The strict matcher drives iteration and the made-up set; Ben's ticks decide. Made-up holdout must not drop below the re-measured baseline;
  collection accuracy must not fall more than a couple of points. Ties go to 2. Ben confirms the pick from the report
  before the losing variant is deleted.
- After the pick, Ben checks on his phone (`make device`) with a handful of fresh real scans: the phone iteration loop.

### Part 5: TelemetryDeck
- Add the TelemetryDeck Swift SDK (`exact:` pin) to the app target only (not the package: `Core` stays dependency
  free). A new `App/TelemetryDeckAnalytics.swift` conforms to `Analytics` and turns each event into a signal: the
  event's `name` as the signal type, the payload as string parameters (`.int` → decimal, `.bool` → "true"/"false",
  `.token` → its raw value). That needs a package-level way to read a token's raw value for the sink (e.g. a
  `public var description` or a `package` accessor exposed through a `public` mapping function in `Core`); the
  no-free-text guarantee stays, since tokens are still only mintable inside the package.
- Wiring: one sink, made once and shared (today `AppStartup` and `AppEnvironment` each make their own `LogAnalytics`). Release builds use `TelemetryDeckAnalytics`; Debug builds, `make device`, `-UITest` and
  snapshot runs keep `LogAnalytics` (my call: Ben's own test installs shouldn't fill the dashboard). TestFlight builds
  are Release, so they send; TelemetryDeck itself marks TestFlight signals.
- The app ID lives in a build setting in `project.yml` (`TELEMETRYDECK_APP_ID`, read through Info.plist), committed:
  it ships in the app anyway. Until Ben creates the account it is empty and an empty ID means `LogAnalytics` even in
  Release. The real ID must be in before the branch merges (Ben signs up at telemetrydeck.com, free plan: 50,000
  events a month for new accounts since July 2026).
- `PrivacyInfo.xcprivacy` (#97): Product Interaction and Other Diagnostic Data, not linked, not tracking, purpose
  analytics, plus any required-reason APIs TelemetryDeck's docs name. Confirm the SDK's default user identifier is
  anonymised. The App Store Connect privacy label (Usage Data and Diagnostics, not linked, not tracking) is Ben's
  manual step, listed in the PR.
- #3's extras: `appOpened` fires at launch (the `.onChange(of: scenePhase)` gets `initial: true`, or the launch path
  sends it), with a test; recheck that `LogAnalytics` logging payloads `.public` is still right (it is, as long as
  payloads hold only tokens, numbers and booleans; say so in a comment).
- No opt-out (§8). The privacy page already names TelemetryDeck (Plan 6).

## Decided, and by whom

| Decision | By |
|---|---|
| 10 s wait | Ben |
| A good title is defined from Ben's yes/no review, with the scan visible | Ben |
| Shorter wins when unsure; printed names are fine, descriptions and stray page text are not | Ben |
| ~30 real scans, outside the repo, never committed | Ben (agreed) |
| No dates in titles; document dates go to #88 | Ben |
| Approach 2, compared against a refined 1 | Ben |
| The winner is picked by Ben ticking both variants' titles side by side | Ben |
| TelemetryDeck in this branch | Ben |
| Real-scan folder `~/FilingCabinetPrivate/eval/`, `PRIVATE=` switch, review page as a local file | my call |
| Only Release builds send; empty app ID falls back to the log | my call |
| App ID committed in `project.yml` | my call |
| Ties go to approach 2; strict title matcher; holdout floor re-measured | my call |
| Part 0 as a live Console session during Part 2's scanning | my call |
| No code rule for owners' names (prompt only) | my call |
| Middot titles: optional third part or rewritten expectations, after the review | my call |
| One shared analytics sink (`AppStartup` and `AppEnvironment` each make one today) | my call |
| `promptVersion` not bumped | my call (it versions the words) |

## Left to the builder

- Exact prompt wording and examples (from Ben's review), schema property descriptions.
- How the review page stores and returns answers (download JSON is the default).
- The eval's subset choice while iterating, within the "subset then one full run" rule.
- The token raw-value accessor's exact shape, within the module-access rules.
- Exact PrivacyInfo entries, from TelemetryDeck's current docs.
- Test names and file split, per AGENTS.md.

## Order

Part 0 + Part 2 together (Ben scans at the Mac, current build) → Part 1 → Part 3 (needs Ben's review) → Part 4 →
phone check. Part 5 is independent and can be built first while waiting on Ben. Building starts on `ai-followup` off
`origin/main` after Plan 6 merges, or in a herdr worktree if Ben asks for one.
