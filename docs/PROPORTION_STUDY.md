# Proportion Study — furniture vs. characters

The world is built in METERS. Audit against ergonomic standards
(ANSI/BIFMA seated-work guidance; typical anthropometry, adult ~1.70 m):

| Element | Ours | Standard | Verdict |
|---|---|---|---|
| Sit-stand desk | 0.72 | 0.72–0.76 | ✓ |
| Task-chair seat | 0.45 | 0.43–0.45 | ✓ |
| Meeting round table | 0.72 | 0.72–0.75 | ✓ |
| Reception counter | 0.99 | 0.90–1.10 | ✓ |
| Coffee island worktop | 0.95 | 0.90–0.95 | ✓ |
| Bar stool seat | ~0.65 | 0.61–0.66 | ✓ |
| Lounge sofa seat | 0.39 | 0.40–0.45 (low modern) | ✓ |
| Shelving | 1.80 | 1.80–2.00 | ✓ |
| Interior glass | 2.00 | 2.10–2.40 (kept lower for dollhouse readability) | ~ |
| Ceiling luminaires | 2.92 | 2.70–3.00 | ✓ |
| **Character height** | **1.35 → 1.70** | avg adult ≈ 1.70 | **fixed** |

Root cause: 1.35 m was tuned for KayKit chibi bodies (oversized heads
carry the silhouette, so furniture ratios read fine). Realistically
proportioned people (Quaternius Modular Men) at 1.35 read as children
at adult desks — desk-to-height ratio hit 53% where reality is ~43%.

Fix: CHAR_H 1.70 (desk ratio 42% ✓, chair 26% ✓, counter 58% ✓),
carried document raised to chest height 1.05. Bubbles, status bars and
pop FX are CHAR_H-relative and follow automatically.
