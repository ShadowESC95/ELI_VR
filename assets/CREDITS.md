# Where the art comes from

Everything in `assets/space/`, `assets/skies/` and `assets/materials/` was made from the sources below by `tools/prepare_space_assets.py`. All of it is free to use and to redistribute. Nothing is downloaded when ELI VR runs.

## The night sky

`assets/space/starmap_8k.jpg`

Deep Star Maps 2020, NASA Scientific Visualization Studio: <https://svs.gsfc.nasa.gov/4851/> (`starmap_2020_8k.exr`). The real sky: about 1.7 billion stars from the Hipparcos-2, Tycho-2 and Gaia DR2 catalogues.

Credit: NASA/Goddard Space Flight Center Scientific Visualization Studio. Gaia DR2: ESA/Gaia/DPAC.

NASA imagery is not copyrighted. Its use here does not imply NASA's or ESA's endorsement.

## Earth

| File | Source |
|---|---|
| `assets/space/earth_day.jpg` | Blue Marble Next Generation, December, with topography and bathymetry. NASA Earth Observatory, <https://visibleearth.nasa.gov/images/73909>. Credit: Reto Stöckli, NASA Earth Observatory. |
| `assets/space/earth_clouds.jpg` | Blue Marble clouds. NASA Earth Observatory, <https://visibleearth.nasa.gov/images/57747>. Credit: NASA Goddard Space Flight Center, image by Reto Stöckli. |
| `assets/space/earth_night.jpg` | Black Marble 2016. NASA Earth Observatory, <https://earthobservatory.nasa.gov/features/NightLights>. Credit: NASA Earth Observatory images by Joshua Stevens, using Suomi NPP VIIRS data from Miguel Román, NASA's Goddard Space Flight Center. |

NASA imagery is not copyrighted.

## Places

`assets/skies/` holds 360 degree photographs of real places from Poly Haven, <https://polyhaven.com>. Licence: Creative Commons CC0 1.0 (public domain). Each is the 8K tonemapped version.

| File | Poly Haven panorama | Photographer |
|---|---|---|
| `assets/skies/mountain_dawn.jpg` | `kiara_1_dawn` | Greg Zaal |
| `assets/skies/misty_pines.jpg` | `misty_pines` | Greg Zaal |
| `assets/skies/sunset_sea.jpg` | `belfast_sunset_puresky` | Dimitrios Savva (photography), Greg Zaal (processing), Jarod Guest (sky edits) |

## Surfaces

Scanned materials from ambientCG, <https://ambientcg.com>, by Lennart Demes. Licence: Creative Commons CC0 1.0 (public domain).

| Files | ambientCG material |
|---|---|
| `assets/materials/hull_panels_*.jpg` | MetalPlates008 |
| `assets/materials/deck_plating_*.jpg` | MetalPlates017A |
| `assets/materials/brushed_metal_*.jpg` | Metal009 |
| `assets/materials/rock_*.jpg` | Rock058 |
| `assets/materials/moss_rock_*.jpg` | Rock063 |
| `assets/materials/snow_*.jpg` | Snow010A |
| `assets/materials/ice_*.jpg` | Ice003 |
| `assets/materials/forest_floor_*.jpg` | Ground068 |
| `assets/materials/sand_*.jpg` | Ground080 |
| `assets/materials/concrete_*.jpg` | Concrete030 |
| `assets/materials/marble_white_*.jpg` | Marble012 |
| `assets/materials/marble_black_*.jpg` | Marble016 |
| `assets/materials/wood_floor_*.jpg` | WoodFloor043 |
| `assets/materials/planks_*.jpg` | Planks037A |
| `assets/materials/lab_tiles_*.jpg` | Tiles107 |
| `assets/materials/bark_*.jpg` | Bark012 |

Each set is the 1K version, repacked as colour, normal (OpenGL convention) and one texture holding occlusion, roughness and metalness.

## Drawn for ELI VR

`assets/materials/fern_frond.png` and `assets/materials/kelp_blade.png` are drawn by `tools/prepare_space_assets.py` itself and belong to this project.

## Objects in the rooms

`assets/models/` holds 3D models from Poly Haven, <https://polyhaven.com>, as glTF with their 1K textures. Licence: Creative Commons CC0 1.0 (public domain). `tools/prepare_models.py` brings them in from Poly Haven's own downloads and records them in `assets/models/models.json`.

| Folder | Poly Haven model | Made by |
|---|---|---|
| `SchoolChair_01` | School Chair 01 | Ethan Place |
| `Television_01` | Television 01 | Gabriel Radić |
| `WoodenChair_01` | Wooden Chair 01 | Jake Mobley |
| `bench_vice_01` | Bench Vice 01 | Antanas Kep, Yann Kervran |
| `caged_hanging_light` | Caged Hanging Light | Ulan Cabanilla |
| `ceiling_fan` | Ceiling Fan | Ulan Cabanilla |
| `circuit_board` | Circuit Board | Benny Weimer |
| `classic_laptop` | Classic Laptop | Arrangemonk |
| `clipboard` | Clipboard | ProgrammerOnCoffee |
| `desk_lamp_arm_01` | Desk Lamp Arm 01 | Kuutti Siitonen, Yann Kervran |
| `drill_press_01` | Drill Press 01 | Viktor |
| `filmstrip_projector_8mm` | Filmstrip Projector 8mm | PeterM |
| `hanging_industrial_lamp` | Hanging Industrial Lamp | Kuutti Siitonen |
| `industrial_microscope` | Industrial Microscope | Lukas Walzer |
| `industrial_storage_cart` | Industrial Storage Cart | Jule Bielitz |
| `industrial_wall_lamp` | Industrial Wall Lamp | Kuutti Siitonen |
| `industrial_wall_sconce` | Industrial Wall Sconce | Ulan Cabanilla |
| `magnifying_glass_01` | Magnifying Glass 01 | Nazar Borodavka |
| `metal_office_desk` | Metal Office Desk | Ulan Cabanilla |
| `metal_tool_chest` | Metal Tool Chest | John Hutcheson, Yann Kervran |
| `metal_toolbox` | Metal Toolbox | Mateusz Sadek |
| `modular_electric_cables` | Modular Electric Cables | Kuutti Siitonen |
| `mounted_fluorescent_lights` | Mounted Fluorescent Lights | Ulan Cabanilla |
| `office_notepads` | Office Notepads | Ulan Cabanilla |
| `plastic_crate_01` | Plastic Crate 01 | PierreB3D |
| `plastic_crate_02` | Plastic Crate 02 | Fabi_G |
| `portable_welding_cart` | Portable Welding Cart | Georgii Gorbunov |
| `power_box_01` | Power Box 01 | Rico Cilliers, Yann Kervran |
| `retro_multimeter` | Retro Multimeter | elli moeller |
| `steel_frame_shelves_01` | Steel Frame Shelves 01 | James Ray Cock |
| `steel_frame_shelves_02` | Steel Frame Shelves 02 | James Ray Cock |
| `television_02` | Television 02 | Benny Weimer |
| `tool_cart` | Tool Cart | Savva Zakharov |
| `vintage_cabinet_01` | Vintage Cabinet 01 | Rico Cilliers |
| `worn_metal_rack` | Worn Metal Rack | Luca B |
