# Titles skip lines of numbers (#48)

Short design, 2026-11-19. Branch `title-skips-numbers`.

## Intent

On the phone, a scan with a chart at the top got the title "A 120AM 0:0AM 0200…": the title rule took a row of
time-axis labels as the heading. The rule's title is what the review shows when Apple Intelligence is off, unavailable
or too slow, and what it shows before the suggestion arrives. It should be a real heading or nothing, never a row of
numbers.

Not in scope (Ben, 2026-11-19): suggesting a collection by rule. Without Apple Intelligence the sheet still says
"Choose a collection". That idea moved to After 1.0 (#25).

## Approaches

- **A. Tighten which lines can be a title (picked).** `TitleRule` already drops lines with fewer than three letters. It
  gets a stricter test for "this line is words", and otherwise works as today: tallest line left in the top 40% of
  page 1. One file, no new concept.
- **B. Score every line** (height, position, share of letters, length) and take the best score. More knobs to tune and
  harder to say why a title was picked; nothing in the one reported case needs it.
- **C. Lean on the reader's structure** (headings, tables from the documents reader). Depends on #41, which reader is
  the default, and the text reader has no such structure.

A is the smallest change that fixes the cause. Ben approved this scope on 2026-11-19.

## The rule

A line can be a title when all three hold:

1. it has at least three letters (today's rule),
2. at least half of its letters and digits are letters, and
3. if it has a digit, three of its letters are in a row.

Revised 2026-11-19 after the branch review. The first version counted only letters in words without a digit and asked
every line for a three-letter word, which cost real headings: "To Do", a letter-spaced "M E N U", "Form 1099-INT",
"COVID-19 Test", "7-Eleven". The rows in the table below come out the same under both versions.

Everything else is unchanged: page 1 only, the top 40%, tallest line wins, the higher line on a tie, all-caps is
title-cased, 60 characters at most, and no title when no line qualifies.

| Line | Title? | Why |
|---|---|---|
| A 120AM 0:0AM 0200 | No | no three letters in a row |
| 12:00 AM 2:00 AM 4:00 AM | No | "AM" is two letters |
| 12 kg 30 kg 45 kg | No | no three letters in a row |
| 0 50 100 150 kWh | No | 3 of 12 characters are letters |
| 100 mg 200 mg | No | no three letters in a row |
| City Pharmacy | Yes | |
| Form 1040 | Yes | half is letters |
| Form 1099-INT | Yes | |
| To Do | Yes | no digits, so as today |
| Bio 210 · Oct 10 | Yes | as today's test expects |
| Lease Renewal Unit 4B | Yes | |
| Order 1234567890 | No | mostly a number; the next tallest line wins, or no title |

**Known limits:** a row of word labels ("Mon Tue Wed Thu") still passes. Only its height decides, as today. Text alone
can't tell it from a heading. And a short heading that is mostly a number loses: "2025 Q4 Tax", "2025–2026 Budget".

## Checking it

- **Regression tests** in `TitleRuleTests`, from made-up lines only: the reported row loses to a smaller real heading;
  a page with only number rows has no title; the "Yes" rows above still win.
- **Before and after.** `make eval-suggestions` scores only the model's title today. Its report gains the rule's title
  for each case, so the rule can be compared on the 87 made-up scans and the private set. The plan's first task adds
  that and records the baseline from `main`; the last task lists every case whose rule title changed. Private titles
  stay in the private folder's report, never in the repo, the PR or an issue. Ben sees both lists before merge.

## Constraints

- `Understanding` stays Mac-buildable; the two thresholds are named private constants beside the existing ones.
- No personal scan content in tests, fixtures, commit messages or the PR.
- The evaluation stays a report, not a gate.

## Rulings (mine, for Ben to check)

1. **"Half" and "three letters" are my numbers, and the revised rule above is my call too** (it follows the review,
   not a decision of Ben's). If the baseline shows good titles lost, they change before merge and
   this doc is updated. Cost if wrong: one constant.
2. **No fallback below the top 40%.** A page whose top has only numbers gets no title, as a page with no text does.
   Cost if wrong: one more pass over the rest of the page.
3. **The rule's title goes in the evaluation report for good**, not as a throwaway script, so later rule changes can be
   compared the same way. Cost if wrong: one column to remove.

## Left to the builder

How the report shows the rule's title (a column or its own section), and the wording of the "changed" list.
