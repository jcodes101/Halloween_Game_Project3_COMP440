# House assets

These are selected, unmodified GLB files from the already approved/downloaded
[Kenney Building Kit](https://kenney.nl/assets/building-kit) and
[Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit), both CC0.

Copies are placed here because the original vendor directory has `.gdignore`.
Original models and license files remain preserved under `assets/vendor/kenney/`.
Each copied kit retains its supplied License.txt and colormap texture. `manifest.json`
records each model's source. `design/house/prepare_assets.py` reproduces the selection.

House structure, furniture, door leaves, steps, trim, lamps, garden planting and
neighbor facades use these models. Fit transforms and collision shapes are authored
in `game/house/house_builder.gd`. The crowbar and pull-down ladder are assembled from
kit pipe, column and border pieces. The small key reuses the earlier procedural
key design. Structural infill and collision surfaces use native Godot geometry.
