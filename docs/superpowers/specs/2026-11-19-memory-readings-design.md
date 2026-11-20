# Memory readings for a 20-page scan (#50)

Short design, 2026-11-19. Branch `memory-readings`.

## Intent

#50 asks for two numbers from a real phone: peak memory during a 20-page scan, and memory still held after the viewer
closes. Instruments did not give them on 2026-11-07: xctrace saw the phone as offline, and while the phone was paired
to the Mac its camera went black. So the app records the numbers itself, in debug builds, and the scan is done with the
phone unplugged.

Not in scope: fixing anything the numbers show (the review strip's full-size pages, `ImageCache` keeping three pages).
Those become their own work if the numbers are bad. Release builds are unchanged. MetricKit stays in #2.

## Approaches

- **A. The app writes its readings to a small file (picked).** At six points the app records its memory to a text file
  in its own Caches folder and to the log. The scan is done unplugged; afterwards the phone is plugged in and the file
  is copied off with `devicectl`. Covers the real path, Apple's camera included, and does not need the Mac during the
  scan.
- **B. Log only, read live.** Less code, but the phone must be attached to the Mac during the scan, which is the
  set-up that broke the camera last time.
- **C. A device test pushes 20 made-up pages through the pipeline.** Repeatable, but skips the camera and the real
  screens, so it would not answer #50. Useful later for finding which stage is responsible.

## What is recorded

One line per reading: the time, the stage, the page count where there is one, and three numbers in MB.

| Number | Meaning |
|---|---|
| now | memory the app holds at that moment |
| peak | the highest it has been since the app was opened (iOS keeps this figure) |
| left | how much more the app may take before iOS stops it (iPhone only) |

The six stages:

1. app opened
2. camera finished (the pages were handed to the app)
3. review ready (reading finished)
4. saved
5. viewer closed
6. app in background

`peak` counts from when the app was opened, so each run starts by force-quitting the app. The file is appended to and
never cleared, so a run is not lost if the app is reopened before the file is collected. Lines are about 100 bytes and
the file exists only in debug builds.

The lines hold stage names and numbers only: no titles, no text, no images.

## Where it lives

- `Core`: `MemoryReading` (reads now, peak and left from the system) and `MemoryReadings` (formats a line, appends it,
  logs it). Mac-buildable, so both are tested in Fast.
- The six call sites, each one line, compiled in debug builds only.

## The run

1. **Simulator, by Claude:** a fake-camera scan; the file has the six lines.
2. **Phone, one page (Ben's suggestion):** install with `make device`, unplug, scan one page, save, open it, close it,
   leave the app. Plug in; Claude copies the file. This proves the whole chain, and that the camera works after an
   install, before anyone scans 20 pages.
3. **Phone, 20 pages:** force-quit, open, scan 20 pages, save, open the scan, swipe through every page, close the
   viewer, leave the app. Plug in; Claude copies the file.
4. The numbers go on #50.

## Reading the result

Claude's proposal, for Ben to change: the scan passes if `peak` stays under half of the phone's limit (`now` + `left`).
Memory held after the viewer closes is reported next to the "app opened" figure, and Ben decides whether it needs work.

## Tests

- A reading on the Mac has `now` above zero and `peak` at or above `now`.
- A line has the stage, the page count and the three numbers in the agreed format; a reading with no `left` leaves it
  out.
- Appending twice keeps both lines; a file that cannot be written is logged and nothing else happens.
