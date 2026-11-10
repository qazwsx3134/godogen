# Battlefield surface atlas

Original procedural assets authored for walker-tps, 2026-11-10. No third-party or AI-generated image source. Reproduction source: `tools/make_environment_atlas.py` (Python standard library, fixed seed).

Three 1024×512 maps share eight 256×256 cells in a 4×2 layout: soil, asphalt, grass, concrete; rust, painted steel, moss, burnt metal. ORM uses R=ambient occlusion (currently white), G=roughness, B=metallic. Normal is tangent-space. Import with mipmaps; current imports use VRAM compression for desktop and ETC2/ASTC targets.

Ground blends cells 0–2. Weathered props select concrete/rust/burnt metal and add restrained moss coloration. Other cells are available in the same atlas. Shared materials live in `materials/`; see project README for editable shader parameters and authoring tools.
