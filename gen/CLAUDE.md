# gen

Pure static generators for the well; no node state, no cache.

- `WellGenerator.tiers() -> Dictionary` is stage 1. It reads `Tuning.field` and `Tuning.planet` on every call and root-finds on `GravityField.planet_potential_eff`. Result: `boundaries: Array[float]` (5 ascending radii: `atmosphere_edge`, then 10 %, 35 %, 75 % of the Φ_eff swing above the edge, then `carrier_orbit_radius`; cumulative `tier_shares` from the bottom), `tow` (= `boundaries[2]`, bottom of the middle tier) and `ceiling` (= `carrier_orbit_radius + ceiling_offset`).
- swing = Φp(`carrier_orbit_radius`) − Φp(`atmosphere_edge`); each inner boundary is found by bisection on [edge, r_c] and stops on a Φ tolerance relative to the swing, not an r tolerance: `frame_omega` uses `eps` while Φ does not, so g_eff(r_c) is only ≈ 0 and the profile is flat near r_c.
