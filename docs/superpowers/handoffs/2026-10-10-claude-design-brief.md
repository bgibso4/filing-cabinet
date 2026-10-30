# Claude Design brief: Filing Cabinet screen design

Paste everything below the line into Claude Design, inside the **Filing Cabinet Mocks** project.

---

We're starting the screen design for Filing Cabinet: iPhone, 390 × 844, every screen in light and dark. Use the Filing Cabinet Design System's tokens and follow its README rules.

**Read first**
- `docs/superpowers/specs/2026-10-10-filing-cabinet-requirements.html` is the source of truth. It has the user stories, the cleanup model and the decisions log.
- Flows 1–5 and the decisions board on this canvas define behavior. Don't change them.

**Agreed so far**
- One Home screen holds the folder structure (Favorites, the five collections, Recent, All, Trash) and links to everything else.
- There's a single Scan button. There's no tab bar.

**Still open: show me options, don't decide**
- **Collections on Home:** folder tiles or a list. I like both. The existing Home boards on this canvas are early explorations, not decisions.
- **Favorites:** how they scale from 0 to 10 or more without pushing the collections down. A sideways-scrolling row is one idea.
- **Placement:** where Scan, Search, Trash and Settings live.

**Start with:** Home. Give two or three options that answer the open questions above, each in light and dark, so I can pick before we move on to other screens.

**The full list of screens, in order.** Do one screen at a time and show options before building the next. Once they're all agreed, wire them into one clickable prototype that follows Flows 1–5.

| # | Screen | States to cover | Flow |
|---|---|---|---|
| 1 | Home | Normal · first launch (empty) · no favorites · many favorites · "4 scans moved to Trash" banner · large text | 2, 4, 5 |
| 2 | Collection (Wallet, Receipts, Notes, Documents, Throwaways), Recent, All | Grid with days left or Kept forever · some expiring within 7 days · empty | 2 |
| 3 | Search | Before typing · results with the matching line · no results | 2 |
| 4 | Favorites "See all" | Only if the chosen Home design needs it · reordering | 2 |
| 5 | Camera is off | Explains why, with Open Settings | 1 |
| 6 | Review sheet | With suggestion · without Apple Intelligence (Save disabled until a collection is picked) · expiry choices and a custom date · discard confirmation · couldn't save | 1 |
| 7 | Saved confirmation | "Saved to Receipts · 90 days", tappable | 1 |
| 8 | Scan detail | Multi-page · expiring vs Kept forever · favorite on and off | 3 |
| 9 | Edit sheet | Title, collection, expiry; changing collection resets expiry | 3 |
| 10 | Delete confirmation | "Moved to Trash · restore within 30 days" afterwards | 3 |
| 11 | Trash | Days until deleted · Restore · Delete now · Empty Trash with confirmations · empty Trash | 4 |
| 12 | Settings | Lifespans · automatic filing on, or why it's off · privacy line | 5 |
| 13 | Lifespan picker | Choices · confirmation when shortening would trash existing scans | 5 |
| 14 | Notification ask and the notification | The one-line reason before iOS asks · the notification text | 4 |

iOS draws these itself, so they need no design: the document camera, the share sheet, and the permission prompts.
