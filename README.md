# Byteshade PT

Ultra-realistic path-traced shaderpack for Iris Shaders (Fabric/NeoForge).

Screen-space path tracing with physically-based rendering, global illumination, atmospheric scattering, and cinematic post-processing.

## Features

- Deferred PBR G-buffer - Albedo, normal, roughness, metallic, emission rendered to MRTs
- Screen-space global illumination - Multi-bounce indirect light via hemisphere ray marching
- Screen-space reflections - Binary-search refined ray marching through depth buffer
- Cascaded shadow maps - 2048x2048 with 3x3 PCF soft shadows
- Physically-based BRDF - GGX distribution, Smith geometry, Schlick Fresnel
- Atmospheric scattering - Precomputed Rayleigh/Mie sky model, procedural stars, clouds, aurora
- Gerstner wave water - Animated vertex displacement, specular water, underwater fog
- Temporal accumulation - Motion-vector reprojection with neighborhood clamping denoising
- ACES Filmic tonemapping - Film-like dynamic range compression
- Cinematic post-processing - Auto-exposure, bloom, depth of field, chromatic aberration, vignette, film grain

## Installation

1. Install [Iris Shaders](https://irisshaders.dev) (1.20.1+ / 26.x)
2. Download the latest release of Byteshade PT
3. Place the .zip in your shaderpacks folder
4. Select Byteshade PT in Video Settings -> Shaderpacks
5. (Recommended) Use a LabPBR-compatible resource pack like [Vanilla Normals Renewed](https://github.com/Poudingue/Vanilla-Normals-Renewed) for PBR textures

## Performance

| GPU | Resolution | FPS |
|-----|-----------|-----|
| RTX 4090 | 1440p | 60-90 |
| RTX 3060 | 1080p | 40-60 |
| RTX 2060 | 1080p | 25-40 |

## Building from source

No build step - it's raw GLSL. Just zip the shaders/ directory:

```bash
cd byteshade-pt
zip -r Byteshade_PT.zip shaders/
```

## Pipeline

```
G-buffers (11 passes)
    | colortex0-4, depthtex0
composite - direct light + SSR + GI + sky
    | colortex0 (HDR), colortex5 (history)
composite1 - temporal accumulation denoising
    | colortex0 (denoised HDR)
final - ACES -> bloom -> DoF -> CA -> vignette -> grain -> gamma
    | colortex0 (final sRGB)
```

## License

GNU General Public License v3.0 - see [LICENSE](LICENSE).
