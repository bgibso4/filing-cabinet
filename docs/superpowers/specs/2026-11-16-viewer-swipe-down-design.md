# Swipe down closes a scan (#98)

Short design, 2026-11-16. Lane `viewer-feel`.

## Intent

Closing a scan should feel like Photos: swipe down on the page, it shrinks under the finger as the screen behind shows
through, and on release it flies back into the thumbnail it came from. One-handed, no reaching for the back button.

## Approaches

- **A. The system's zoom navigation transition (picked).** The viewer is pushed with
  `.navigationTransition(.zoom(sourceID:in:))` and each place a scan opens from marks its thumbnail with
  `.matchedTransitionSource`. Opening grows the scan out of its thumbnail; iOS supplies the interactive swipe-down close,
  the screen behind showing through, and the Reduce Motion fallback. Little code. It changes the open animation
  everywhere, from a slide to a zoom.
- **B. Our own swipe-down, keeping the slide-in.** Built like `DetailsSwipe`. More code, the screen behind can't show
  through a push, and the release slides sideways instead of returning to the thumbnail.

Ben tried both on his phone as throwaway spikes on 2026-11-16 and picked A ("definitely A").

## Behaviour

| Where | What happens |
|---|---|
| Open a scan | It zooms out of the thumbnail that was tapped |
| Swipe down on a page at rest, Details closed | The page follows the finger and shrinks; release far or fast enough and it returns to its thumbnail, otherwise it springs back |
| Back button, edge swipe back | Also zoom back to the thumbnail (the system's) |
| Details up | A swipe down closes Details (#71) and never the scan; a second swipe closes the scan |
| Page zoomed in | A drag pans the page; it never closes the scan |
| Sideways | Pages, as today |
| Swipe up | Opens Details, as today |
| Opened from Trash | The same, back to its Trash tile (the same as Close) |
| Reduce Motion | Whatever the system does for the zoom transition under Reduce Motion |

**Sources** (each marks its thumbnail, matched by `ScanID`): collection grid tiles (every grid, Favorites included),
Home's favourite cards, Trash tiles, Search's result rows and its recently viewed scans. Search has its own navigation
stack, so it has its own namespace.

A scan opened from outside the app (Spotlight, Siri, `-Request open:`) has no thumbnail on screen: it uses the system's
fallback for a zoom without a source.

## Constraints

- No `#available` (iOS 27 minimum); Swift 6; tokens only for radii. The source's corner shape matches each thumbnail's
  own clip.
- `BrowseJourneyTests`' zoomed-edge swipe and largest-text audit tests belong to the test-reliability lane: don't
  change them.

## Rulings (mine, for Ben to check)

1. **Trash swipes down too.** Same as its Close button. Cost if wrong: one condition to remove.
2. **Outside-the-app opens use the system fallback** rather than keeping the slide. Cost if wrong: a second destination
   style for requests.
3. **Reduce Motion is the system's.** If it still moves too much on the phone, that joins #72.

## Left to the builder

The one real risk: the system's swipe-down and our own gestures (`DetailsSwipe`'s close of Details, a zoomed page's
pan, the pager). The first plan task measures what happens on the device in each case; anything that conflicts is
resolved there (for example by declining the system's dismissal while Details is up or a page is zoomed). Tests: UI
journey tests for swipe-down closing the viewer, closing only Details when it is up, and not closing a zoomed page;
unit tests for any rule that decides which gesture wins.
