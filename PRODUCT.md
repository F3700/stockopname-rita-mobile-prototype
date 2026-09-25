# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

Warehouse inspectors doing stock opname (stock-taking) on the shop floor. Mid-range Android phones, often one-handed, possibly gloved, in bright aisle light. Indonesian-speaking.

## Product Purpose

Offline-first mobile scanner for stock opname sessions: join a session (manual codes or coordinator QR), walk racks, scan product barcodes (camera or manual PLU), record quantities, upload per-rack when online, finish the session. Success = a full rack scanned fast with zero ambiguity about what is recorded, what is uploaded, and what remains.

## Positioning

Works where the warehouse has no signal: the whole scan flow is local-first (SQLite), and upload is an explicit per-rack act, not background magic. A session survives app restarts and continues from history.

## Operating Context

Sessions identified by sesi code + coordinator code + inspector code + rack names. Flow: Home (history) → Session setup or QR join → Rack list → Rack scan → Product detail → rack upload → session finish. Online gates: joining, opening a rack, and finishing require connectivity; scanning itself never does.

## Capabilities and Constraints

- 7 screens: Home, SessionForm, ScanCoordinator, JoinQrForm, RackList, RackScan, ProductDetail. Riverpod + SQLite + Dio stay as-is.
- Barcode truth: unknown barcode = message only; duplicate scan in a rack = Tambah/Ganti dialog; quantities are integers > 0.
- Rack completion requires online + successful upload before local done-mark.
- 360dp base width. Min touch target 48dp (gloves). Body text ≥ 4.5:1 contrast, sun-readable.
- OPEN: exact device models in the fleet; whether dark mode is wanted (default: light, picked from use scene).

## Brand Commitments

Rita red `#C00000` primary + Inter. Existing logo asset `assets/images/logoritapasaraya.png`. Indonesian copy throughout.

## Evidence on Hand

- Flutter source of record: `lib/features/home/home_screen.dart`, `lib/features/setup/session_form_screen.dart`, `lib/features/join_qr/scan_coordinator_screen.dart`, `lib/features/join_qr/join_qr_form_screen.dart`, `lib/features/racks/rack_list_screen.dart`, `lib/features/scan/rack_scan_screen.dart`, `lib/features/scan/product_detail_screen.dart`.
- Penpot: file `...5d97e7b0`, pages `Page 1` (v1 placeholders) and `Rita v2` boards `H-Home…H-Detail` (tidy v1 baseline, pre-redesign).
- API spec `apispec.json` (backend contract, unchanged).

## Product Principles

1. The camera screen is the product; everything else gets out of its way.
2. Every quantity on screen is either recorded-local or uploaded — never ambiguous.
3. One thumb, one glance: primary action always bottom, status always top.
4. Errors name the problem and the recovery, in Indonesian, inline first.
5. No decoration that costs a scan-second.

## Accessibility & Inclusion

Gloved/bright-light operation: 48dp targets, 16sp+ body, no meaning carried by color alone (status always pairs color + label). Bahasa Indonesia throughout.
