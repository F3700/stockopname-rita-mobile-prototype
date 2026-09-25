# Design — Rita Stock Opname (Rita v5, current)

<!-- impeccable:design-schema 1 -->

World: sun-readable warehouse instrument. Committed red header band, paper surface, ink cards. Restrained strategy: neutrals + red for primary actions/selection/state only. Inter throughout. Light theme (picked from use scene: bright aisles). Green = success/done/uploaded; red never means "done".

## Direction contract (shipped, v5 evolution of v4)

- THESIS: the camera screen is the product; every screen answers "what now, what's done" in one glance. v5 compacts v4: 80px band, one pill spec, contrast-correct text tokens, complete scan/upload feedback.
- OWN-WORLD: 80px red band (title 20/700 at y+20, sub 12/400 at y+44, lockup centered) + 44px back target + white status pill in the right slot where one exists; 16px margin / 8px gap grid; `#F6F6F6` ground; white r16 cards with 1px `#E3E3E3` borders; 56px red r12 CTAs bottom-anchored at y=712; quantities tabular Data 22; status color + Indonesian label; 11-icon Material set.
- STORY: inspector sees session state, acts with one thumb, trusts every number as recorded-vs-uploaded.
- FIRST VIEWPORT: band → task content → bottom CTA on all 7 screens; scan screens lead with the black viewfinder card.
- FORM: evolution inside the locked red+Inter identity (no concept roll: pinned brief).
- FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance.

## Tokens (`rita/global`, 32)

| Token | Value | Use |
|---|---|---|
| color.primary | #C00000 | CTA, selection, active state, brand |
| color.pressed | #9A0000 | CTA pressed |
| color.ink | #1A1A1A | Headings, data |
| color.grey | #818181 | legacy meta |
| color.light-grey | #6B7280 | Hints/placeholders (≥4.5:1) |
| color.label | #616161 | Field labels |
| color.border | #D9D9D9 | Input borders, outline pills |
| color.track | #EDEDED | Progress track |
| color.success | #1B9E4B | Success **icons/dots only** |
| color.success-text | #157A3E | Success **text** (4.8:1 on success-bg) |
| color.success-bg | #E5F4EB | Selesai/Terupload pill bg |
| color.warning | #E8890B | Warning dot/border |
| color.warning-text | #9A5000 | Warning text (5.2:1 on warning-bg) |
| color.warning-bg | #FCEEDD | Belum-upload pill bg |
| color.error | #C00000 | Errors |
| color.focus | #1A73E8 | Focus rings |
| color.line | #E3E3E3 | Card hairlines |
| color.primary-surface | #FDECEC | Berjalan pill bg, just-scanned row tint |
| color.neutral-surface | #F1F3F4 | Proses pill bg, skeleton base |
| radius.sm/md/lg | 10 / 12 / 16 | Inputs / buttons-cards / sheets |
| spacing.xs–xl | 8 / 10 / 16 / 17 / 20 | Compact scale |

Note: legacy `space.*` dupes remain; `spacing.*` is canonical.

## Type styles (library)

`R4/Display 20 · R4/Title 17 · R4/Body 16 · R4/Body 15 · R4/BodyStrong 15 · R4/Label 12 · R4/Caption 12 · R4/Data 22 · R4/Button 16 · R4/Pill 11` — all Inter. Buttons ALL CAPS 15; pills 11/700; everything else sentence case.

## Icons (11, Material paths, 24px)

back · chevron-right · plus · minus · close · search · trash · check · refresh · flash (torch) · flip (camera switch). Glyph 24 in 44×44 targets, centered; no decorative icons (rack chevrons removed in v5 — whole row is tappable).

## Components (Penpot library, 13)

`Button-Primary, Card, Input, Pill-Done` (v1) · `R3-ButtonPrimary, R3-Input` (v3) · `R4-*` (v4) · `R5-Pill, R5-IconButton, R5-RackRow` (v5).

## Surface brief (per screen, page `Rita v5`, 360×800, band 80)

- `R5-Home` — band 80 + 40 avatar + Online dot; MULAI primary / QR secondary; history count; cards (17 title, 13 meta, status pill + bordered via-QR tag, date, 44 trash).
- `R5-Session` — back band; 3 inputs (16/328/52); rak add-row (226 + 8 + 94); 56 rows with 44 trash; CTA anchored.
- `R5-ScanQR` — back band; 300 viewfinder; green validated strip (check 20 + 13/700); result card (title + IN_PROGRESS pill + sesi + hint); PINDAI ULANG anchored.
- `R5-JoinQR` — back band; coordinator card (18 code + green pill + sesi + meta); inspector input; rak add-row; bordered chips w/ ×; GABUNG anchored.
- `R5-Racks` — back band + Berjalan pill; progress card (counts + % + 8px bar + upload + amber syncing line); icon search; rows: title + right-aligned pill + meta + upload state (check/⚑/bar/Ulangi); FAB y=640; SELESAIKAN anchored.
- `R5-Scan` — back band + Proses pill; 190 camera with 44 torch/flip (scrim 55%); PLU row (268 field + 52 red search btn); item search; rows ink title + red Data 22 qty + PCS.
- `R5-Detail` — back band; scanned fields (HASIL SCAN pill, neutral border); master fields; price pair (160/8/160); amber notice; qty stepper (− 44 / 224 focus-ring field / + 44); SIMPAN anchored.
- `DS5-Core` (760×1160) — header anatomy (Home + back/pill variants as nested bands), type scale incl Pill 11, pills+tags+chip row, button matrix, icon/icon-button + FAB row, input matrix (default/focus/error/disabled), 11-icon grid.
- `DS5-States` (760×2628) — 4 banners (offline/syncing w/ progress/error+Ulangi/success), pill row, 3 rack-row states (uploaded/uploading w/ inline bar/failed+Ulangi), scan rows (normal + just-scanned w/ BARU), 5 dialogs (duplikat Tambah/Ganti, sync w/ Coba lagi+Lanjut offline, selesaikan sesi, hapus riwayat, hapus rak), 3 toasts (check / text / Ulangi action), skeletons, 3 empties, camera-denied.

## Finish review v5 (in-thread verdict, no subagent surface)

Inspected all 9 v5 boards in one batched export round + one fix pass + confirm. Root-cause fix during review: `children.indexOf()` on API wrappers returns −1, so every pill background landed at the bottom of the z-stack — all 25 pill bg/text pairs re-ordered with `bringToFront()`. Other fixes: empty-state title/sub created with shifted args (giant black text) rebuilt; syncing banner bar moved off the sub line; DS tag/chip overlap and error-message overlap fixed; focus-ring stroke restored (`C.focus` was missing from the v5 palette); card pills inset 16 from card edge; BARU tag moved clear of the barcode; `Ulangi` inset. **Verdict: ship.** Known nits: `space.*` token dupes remain; `via QR`/tint badges subtle at export scale (in-app values correct); legacy v1–v4 pages untouched. No detector run (native target); floor judged in Android conventions. Flutter `lib/` untouched throughout.
