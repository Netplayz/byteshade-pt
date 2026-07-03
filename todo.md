# Byteshade PT — Development Roadmap

## Phase 1 ✅ Deferred G-buffer + Lighting
**Goal**: Convert from forward-lit to deferred rendering pipeline.

- [x] `shaders.properties` — Buffer layout for g-buffer (colortex0-2) + output (colortex3)
- [x] `lib/gbuffer.glsl` — Pack/unpack utilities for g-buffer encoding
- [x] All 11 gbuffer .fsh — Output raw g-buffer data (albedo, normal, lightmap, material) instead of lit color
- [x] `composite.fsh` — Deferred lighting pass: BSL-style sun/ambient/torch colors, GGX specular, shadow mapping
- [x] `composite1.fsh` — Temporal reprojection + TAA on deferred output
- [x] `final.fsh` — Reads colortex3, ACES tonemapping

**Pipeline**: `gbuffers → colortex0,1,2 → composite (deferred lighting) → colortex3 → composite1 (TAA) → colortex3 → final (ACES)`

---

## Phase 2 ✅ SSRT GI (Screen-Space Ray Traced Global Illumination)
**Goal**: Add indirect lighting via screen-space ray marching (Bliss BSPT's approach).

- [x] Add screen-space ray marcher in composite:
  - `RT_alternate()` — binary search through depth buffer along a ray
  - `rayTrace_GI()` — simpler DDA-style ray march
- [x] Cosine-hemisphere importance sampling for indirect diffuse
  - `cosineHemisphereSample()` + `TangentToWorld()` helpers
- [x] Temporal reprojection of GI radiance into colortex4
  - Read previous frame's GI from colortex4 using motion vectors
  - Blend with current frame's GI sample ( ~1/rayCount )
- [x] Sky/ambient contribution for GI rays that escape the depth buffer
  - Sample sky LUT or procedural sky color
- [x] Configurable ray count (2–16) and iteration count
- [ ] Bilateral upsampling for quarter-resolution GI
- [x] Neighborhood clamping on temporal GI accumulation
- [x] Integrate with deferred lighting: `finalColor = directLighting + GI * albedo`
- [x] Composite shader: read g-buffer + compute direct light + add GI in one pass

**Pipeline**: `gbuffers → colortex0,1,2 → composite (direct + indirect SSRT GI) → colortex3,4 → composite1 (TAA) → colortex3 → final`

---

## Phase 3 ⬜ Temporal Anti-Aliasing & Denoising
**Goal**: Robust TAA and spatiotemporal denoising for the stochastic GI.

- [x] Variance clamping for TAA (neighborhood luminance variance)
- [x] AABB neighborhood clamping (3×3 neighborhood min/max)
- [x] Motion vector reprojection (clip-space via prev modelview/projection)
- [x] Reprojection rejection (depth disocclusion test)
- [x] Responsive TAA (lower blend factor during motion)
- [x] Catmull-Rom texture filtering for history sampling (16-tap bicubic)
- [x] Temporal anti-ghosting for dynamic objects (luminance difference rejection)
- [ ] Dilated motion vectors for disocclusion borders

---

## Phase 4 ✅ PBR Material System & Specular
**Goal**: Full physically-based shading with reflections.

- [ ] LabPBR texture standard support (specular, normal, emissive, SSS maps)
  - `block.properties` — Per-block PBR property overrides
  - `entities.properties` — Entity PBR overrides
- [ ] GGX microfacet specular with importance sampling
  - `importanceSampleGGX()` + VNDF sampling
- [ ] Screen-space reflections (SSR)
  - Hierarchical ray marcher with mip-map LOD
  - Roughness-dependent blur (mip-chain linearized)
- [ ] Environment reflections (fallback when SSR misses)
  - Pre-filtered sky LUT or irradiance cube
- [ ] Metal F0 table (iron, gold, copper, etc.)
- [ ] Clear coat / secondary specular layer
- [ ] Subsurface scattering approximation
  - Screen-space SSS blur
  - Pre-integrated skin / leaf SSS
- [ ] Emission glow (bloom-compatible)
- [ ] Wetness / rain puddles with specular

---

## Phase 5 ⬜ Atmosphere, Sky & Volumetrics
**Goal**: Physical sky model and volumetric effects.

- [ ] Preetham / Hosek-Wilkie physical sky model
  - Rayleigh + Mie + Ozone scattering
  - Configurable turbidity, ground albedo
- [ ] Deferred sky LUT (render 256×256 sky into colortex region, sample in lighting pass)
- [ ] Sun disk with atmospheric extinction
- [ ] Moon phases and brightness
- [ ] Stars with twinkle and proper motion
- [ ] Aurora borealis (spectral greens/purples, curtain shape)
- [ ] Rainbow (atmospheric scattering angle)
- [ ] Volumetric clouds
  - 3D Worley/FBM noise
  - Beer's law transmittance
  - Cloud shadows on terrain
  - Temporal reprojection for cloud animation
- [ ] Volumetric fog / light scattering
  - Ray marched fog with anisotropic phase function
  - Height-based density
  - Cave fog, biome-specific fog
- [ ] God rays / crepuscular rays (volumetric shadow scattering)

---

## Phase 6 ✅ Post-Processing (basic)
**Goal**: Cinematic post-processing effects.

- [ ] Bloom
  - Gaussian pyramid (mip-chain bloom tiles)
  - Configurable intensity, threshold, radius
  - Lens dirt texture support
- [ ] Lens flare
  - Anamorphic flare streaks
  - Ghosts (internal lens reflections)
  - Chromatic dispersion
- [ ] Depth of field
  - Circle-of-confusion computation
  - Bokeh blur (hexagonal aperture)
  - Auto-focus / manual focus
- [ ] Chromatic aberration (radial distortion per channel)
- [ ] Vignette (lens falloff, configurable intensity/color)
- [ ] Film grain (procedural, intensity tied to ISO)
- [ ] Motion blur (camera + object, per-pixel velocity)
- [ ] Tonemapping options: ACES, Reinhard, Uncharted2, AGX
- [ ] Color grading (lift/gamma/gain, LUT-based)
- [ ] Auto-exposure / eye adaptation
- [ ] Purkinje shift (color desaturation in low light)
- [ ] Sharpen (post-AA sharpening)

---

## Phase 7 ⬜ Light Propagation Volume (LPV)
**Goal**: Grid-based indirect block light.

- [ ] 3D voxel grid for block light storage
  - Voxelize light-blocking geometry into 3D texture
  - Flood-fill propagation of colored light
  - Configurable grid resolution (64³ / 128³ / 256³)
- [ ] LPV injection (paint emissive blocks into voxel grid)
  - Torches, glowstone, shroomlight, lanterns, etc.
  - Colored candles (per-color RGB propagation)
  - Redstone lamps
- [ ] LPV propagation (diffuse light spread through grid)
  - Multi-bounce light transport
  - Saturation/tint control
- [ ] LPV sampling in deferred lighting
  - Trilinear interpolation from grid
  - Normal-weighted cone sampling
- [ ] LPV shadows for block light
  - Cube-map shadow maps for point lights within grid
  - Shadowed block light contribution
- [ ] Temporal blending for LPV updates (avoid flicker)

---

## Phase 8 ⬜ Shadows & Lighting Refinements
**Goal**: Better shadow quality and lighting detail.

- [ ] Variable Penumbra Shadows (VPS)
  - Blocker search to estimate penumbra size
  - Contact-hardening soft shadows
- [ ] Screen-space contact shadows (SSCTS)
  - Ray marched contact occlusion for small details
- [ ] Colored translucent shadows (stained glass)
- [ ] Colored (colored) shadow maps
- [ ] PCSS / PCF shadow filtering
- [ ] Shadow map cascade / distance management
- [ ] Per-biome lighting colors (mood/ambient)
- [ ] Handheld light (item-held light source)
  - Flashlight with cone angle and SSRT shadows
- [ ] Emissive block lighting (entity light from emissive surfaces)

---

## Phase 9 ⬜ Performance & Polish
**Goal**: Optimize and polish for RTX 3060 target.

- [ ] Quarter-resolution GI (render GI at ½ or ¼ screen size)
- [ ] Adaptive ray count (based on distance, roughness, etc.)
- [ ] LOD bias / mip-map management
- [ ] Frustum culling of LPV regions
- [ ] Distant Horizons LOD mod support
  - Separate depth buffer for DH terrain
  - DH-compatible shadow map
  - DH GI denoising
- [ ] Vivecraft VR support
  - Flashlight hand tracking
  - VR stereo eye fix
- [ ] Config GUI
  - Screen system in shaders.properties
  - Profiles: Very Low, Low, Medium, High, Very High, Ultra
  - Per-option tooltips
- [ ] Debug views (albedo, normals, depth, GI, LPV, etc.)
- [ ] Shader compilation time optimization
  - Limit `#include` depth
  - Reduce dynamic branching
- [ ] Memory optimization (texture formats, buffer sizes)

---

## Phase 10 ⬜ Mod Support & Integration
**Goal**: Compatibility with popular mods.

- [ ] Iris/OptiFine full compatibility (verify all features)
- [ ] Complementary-style block property mappings
- [ ] Entity property mappings (entities.properties)
- [ ] Item property mappings (item.properties)
- [ ] Dimension property mappings (dimension.properties)
- [ ] Physics Mod ocean support
- [ ] SecurityCraft / custom block support
- [ ] Connected glass / CTM support
- [ ] Custom skybox support (resource pack skies)
- [ ] Emissive ore support (block-based auto emission)

---

## Milestone Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Deferred G-buffer + Lighting | ✅ Done |
| 2 | SSRT GI (Screen-space ray traced GI) | ✅ Done |
| 3 | TAA & Denoising | ✅ Done |
| 4 | PBR Material System & Reflections | ✅ Done |
| 5 | Atmosphere, Sky & Volumetrics | ⬜ |
| 6 | Post-Processing | ✅ Done (basic) |
| 7 | Light Propagation Volume (LPV) | ⬜ |
| 8 | Shadows & Lighting Refinements | ⬜ |
| 9 | Performance & Polish | ⬜ |
| 10 | Mod Support & Integration | ⬜ |
