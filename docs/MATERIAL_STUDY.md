# Material Study — researched before applied

Rule adopted for this project: **no surface value is set by feel.** Every
material gets its roughness / metallic / specular from measured references
first, then at most a small stylization nudge. This file is the paper trail.

## Sources

- [physicallybased.info](https://physicallybased.info/) — database of
  measured PBR values (albedo, IOR, metalness, F0) per real material
- [sameerbaloch.com — roughness values guide](https://sameerbaloch.com/roughness-setting/)
- [3dskillup.art — roughness maps in PBR](https://3dskillup.art/roughness-maps-in-pbr/)
- [danthree.studio — roughness map glossary](https://www.danthree.studio/en/glossary/roughness-map)

## Reference values used

| Material | Measured / guide value | Applied in `office_3d.gd` |
|---|---|---|
| Glass (soda-lime) | IOR 1.52, roughness ≈ 0 | `glass`, `podglass`: rough 0.05 |
| Water | IOR 1.333 → F0 ≈ 2%, roughness ≈ 0 | `pond`: rough 0.02, specular 0.25 |
| Stainless steel (brushed) | metallic, F0 (0.67, 0.64, 0.60), rough 0.3–0.45 | `steel`: metallic 1.0, rough 0.35; furniture legs metallic 0.85 |
| Varnished wood | rough 0.3–0.4 | `oak`, `stage_top`, deck floor: 0.40–0.45 |
| Concrete (sealed) | albedo ~0.51 gray, rough 0.7–0.9 | floors/slabs/stone: 0.80–0.85 |
| Painted drywall | rough 0.6–0.75 | `wall_face`, `wall_white`: 0.70 |
| Laminate / coated plastic | rough 0.3–0.5 | counters, trays, bezels, chips: 0.35–0.50 |
| Fabric / carpet | rough 0.8–1.0, fibers → low F0 | carpet 1.0 + specular 0.25; felt/cushions 0.92 |
| Grass | albedo (0.105, 0.133, 0.041) — far darker than intuition | tint darkened to (0.42, 0.54, 0.31) — stylized midpoint |
| Leaf (waxy) vs bark | leaf semi-gloss, bark matte | `leafA/B` 0.70, `trunk` 0.90 |
| Office paper | albedo (0.79, 0.83, 0.88), matte | pinboards 0.75 |

## Why it matters

Before this pass every generated material sat at roughness **0.9** (or 0.62
if it had a normal map) with metallic 0 — glass was effectively frosted,
water was chalk, steel was plastic, and nothing separated a cushion from a
countertop. Under SDFGI the roughness/metallic split is what makes materials
read: smooth dielectrics show sharp speculars, metals tint their reflections,
fabric shows none.

Key principles applied:

1. **Dielectric F0 is ~4%** (Godot `metallic_specular` 0.5). Only two kinds
   of exception: water-like (lower, 2%) and fibrous surfaces (light escapes
   between fibers → drop specular to 0.25–0.3).
2. **Metals get their color from F0**, so `metallic = 1` materials must carry
   the metal color in albedo — never gray-plastic with a specular boost.
3. **Roughness bands, not guesses:** glazing < 0.1, coatings 0.3–0.5, paint
   0.6–0.75, minerals 0.8–0.9, textiles 0.9–1.0.
4. **Albedo discipline continues** (see the lighting commit): whites capped
   ~0.8, grass darkened toward its measured reflectance so GI bounce stays
   plausible.

## Fur (asked about, not yet in the scene)

Fur/hair is not a flat-material problem — it needs strand or shell
rendering (layered transparent shells with a flow map) plus anisotropic
specular. Nothing in the office currently has fur; when an office pet is
added, the plan is shell texturing on a low-poly body, not a StandardMaterial.
