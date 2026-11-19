# Titles Skip Lines of Numbers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `TitleRule` never picks a line that is mostly numbers, times or units (#48), with a before-and-after list of rule titles to prove it.

**Architecture:** Two changes. The suggestion evaluation's "Every case" table gains the rule's title, so the rule can be compared across runs. Then `TitleRule`'s line filter gets the stricter "this line is words" test; everything after the filter is unchanged.

**Tech Stack:** Swift 6, Swift Testing, the `Understanding` module and the `SuggestionEvaluationTests` target.

**Spec:** `docs/superpowers/specs/2026-11-19-title-skips-numbers-design.md`

## Global Constraints

- A line can be a title when (1) it has a word of at least three letters with no digit in it, and (2) at least half of its letters and digits are letters in words without digits.
- Unchanged: page 1 only, top 40%, tallest line wins, higher line on a tie, all-caps title-cased, 60 characters at most, nil when no line qualifies.
- `Understanding` stays Mac-buildable. Thresholds are named private constants beside the existing ones.
- Tests and fixtures use made-up text only. Private titles appear only in files under `~/FilingCabinetPrivate/eval/`: never in the repo, a commit message, the PR, an issue or an artifact.
- The evaluation stays a report, not a gate.
- Run tests with `make fast`; the evaluation with `make eval-suggestions`.

## Review Focus

- A line with no letters or digits at all ("— — —"): not a title, no division by zero. (Task 2)
- A word joined to digits by punctuation ("0:0AM", "#4471"): it counts as a word with a digit. (Task 2)
- A page with a scan that fails to read: the report's rule title cell is empty, the run doesn't fail. (Task 1)
- A rule title containing "|": it stays inside one table cell. (Task 1)
- Accented letters ("Café Résumé"): letters, so a title. (Task 2)

---

### Task 1: The evaluation report shows the rule's title

**Files:**
- Modify: `Packages/FilingCabinetKit/Tests/SuggestionEvaluationTests/EvaluationRun.swift`
- Modify: `Packages/FilingCabinetKit/Tests/SuggestionEvaluationTests/EvaluationReport.swift` (`everyCase`)
- Modify: `Packages/FilingCabinetKit/Tests/SuggestionEvaluationTests/SuggestionEvaluationTests.swift` (`run`)
- Test: `Packages/FilingCabinetKit/Tests/SuggestionEvaluationTests/EvaluationReportTests.swift`
- Modify: `AGENTS.md` (the `make eval-suggestions` row: the report also lists the title rule's title per case)

**Interfaces:**
- Produces: `EvaluationRun.Result.ruleTitle: String?` (`var`, default `nil`, placed after `words` like `isPrivate`): what `TitleRule` picked from page 1, nil when it picked none.

- [ ] **Step 1: Write the failing tests** in `EvaluationReportTests`:

```swift
@Test func everyCaseShowsTheRulesTitle() {
    var result = Self.result(Self.item(id: "a"))  // match the helpers' existing parameters
    result.ruleTitle = "City | Pharmacy"
    let markdown = Self.report([result]).markdown
    #expect(markdown.contains("| Case | Expected | Got | Title | Rule title | Words | Filing | Words call |"))
    #expect(markdown.contains("| City \\| Pharmacy |"))
}

@Test func everyCaseLeavesTheRulesTitleEmptyWhenThereIsNone() {
    let markdown = Self.report([Self.result(Self.item(id: "a"))]).markdown
    // The row has eight cells; the fifth is empty.
    let row = markdown.split(separator: "\n").first { $0.hasPrefix("| a |") }
    #expect(row?.split(separator: "|", omittingEmptySubsequences: false).count == 10)
}
```

- [ ] **Step 2: Run `make fast`.** Expected: both fail to compile (`ruleTitle` unknown).
- [ ] **Step 3: Add `var ruleTitle: String?` to `EvaluationRun.Result`; add the "Rule title" column after "Title" in `everyCase`** (header, divider and row, through `Self.cell`).
- [ ] **Step 4: Set it in `run`.** The loop already reads each page with `reader.read([image])`; keep the first page's `ScanReading.title` and pass it as `ruleTitle`.
- [ ] **Step 5: Run `make fast`.** Expected: pass.
- [ ] **Step 6: Update the `make eval-suggestions` row in `AGENTS.md`. Commit.**
- [ ] **Step 7: Record the baseline.** Copy `~/FilingCabinetPrivate/eval/suggestion-eval.md` and `review.html` to names ending `-2026-11-14` in the same folder (the run overwrites them). Run `make eval-suggestions PRIVATE=~/FilingCabinetPrivate/eval` (the made-up cases run too). Copy the new report to `~/FilingCabinetPrivate/eval/rule-titles-before.md`. Expected: 87 made-up rows plus the private ones, each with a rule title cell. If the model is unavailable the report has no rows: stop and say so.

### Task 2: `TitleRule` skips lines that aren't words

**Files:**
- Modify: `Packages/FilingCabinetKit/Sources/Understanding/Title/TitleRule.swift`
- Test: `Packages/FilingCabinetKit/Tests/UnderstandingTests/TitleRuleTests.swift`

**Interfaces:**
- Consumes: nothing new. `TitleRule.title(from:)` keeps its signature.
- Produces: `private static func isWords(_ text: String) -> Bool`, replacing the letter count in the filter. Constants: `minimumWordLetters = 3` (replaces `minimumLetters`), `minimumWordShare = 0.5`. A word is a whitespace-separated run; "has a digit" is `contains(where: \.isNumber)`.

- [ ] **Step 1: Write the failing tests** (using the file's `line` and `page` helpers):

```swift
@Test func aRowOfTimesLosesToASmallerHeading() {
    let chart = page(
        line("A 120AM 0:0AM 0200", top: 0.05, height: 0.08),
        line("Sleep Report", top: 0.20, height: 0.03))
    #expect(TitleRule.title(from: [chart]) == "Sleep Report")
}

@Test func aPageTopOfOnlyNumberRowsHasNoTitle() {
    let rows = page(
        line("12:00 AM 2:00 AM 4:00 AM", top: 0.05, height: 0.05),
        line("0 50 100 150 kWh", top: 0.12, height: 0.05),
        line("100 mg 200 mg", top: 0.20, height: 0.05),
        line("Order 1234567890", top: 0.28, height: 0.05),
        line("— — —", top: 0.34, height: 0.05))
    #expect(TitleRule.title(from: [rows]) == nil)
}

@Test(arguments: ["Form 1040", "Receipt #4471", "Bio 210 · Oct 10", "Lease Renewal Unit 4B", "Café Résumé"])
func linesThatAreMostlyWordsCanStillBeTitles(text: String) {
    #expect(TitleRule.title(from: [page(line(text, top: 0.1, height: 0.05))]) != nil)
}
```

- [ ] **Step 2: Run `make fast`.** Expected: the first two fail (today's rule picks the number rows); the third passes.
- [ ] **Step 3: Implement `isWords` and use it in the filter.** Update the type's doc comment to say what a title line is. `linesWithFewerThanThreeLettersAreSkipped` must still pass unchanged.
- [ ] **Step 4: Run `make fast`.** Expected: pass, the ten existing `TitleRuleTests` included.
- [ ] **Step 5: Commit.**
- [ ] **Step 6: After.** Run `make eval-suggestions PRIVATE=~/FilingCabinetPrivate/eval`. Compare the "Rule title" column with `rule-titles-before.md` by case id. Write the changed rows (id, before, after) to `~/FilingCabinetPrivate/eval/rule-titles-changed.md`. In chat, give Ben the made-up changes in full and the private ones as a count and the file path. Expected: no title that was a real heading is lost. If one is, stop: the thresholds are Ben's to change (spec ruling 1).
- [ ] **Step 7: Finish.** `ios-verifier`: `make build`, `make lint`, `make unused`, `make affected`. Then the PR, left open for Ben.
