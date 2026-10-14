"""Copy approved kit models out of ignored vendor folders for Godot import."""
from pathlib import Path
import shutil, json

root = Path('assets/vendor/kenney')
choices = {
 'building': ['floor','wall','wall-half','wall-doorway-square','wall-window-square','wall-window-wide-square','door-rotate-square-a','stairs-closed','roof-flat-square','column','border','detail-pipe','barricade-doorway-a'],
 'furniture': ['loungeSofa','loungeChair','tableCoffee','televisionVintage','cabinetTelevision','rugRectangle','bookcaseOpen','books','pottedPlant','lampRoundFloor','lampRoundTable','lampWall','sideTable','kitchenCabinet','kitchenCabinetUpper','kitchenSink','kitchenStove','kitchenFridge','hoodLarge','table','chair','bedDouble','bedSingle','cabinetBed','desk','chairDesk','bathroomSink','bathtub','toilet','bathroomMirror','washer','dryer','cardboardBoxClosed','coatRackStanding','ceilingFan','doorway','doorwayOpen']
}
manifest = []
for kit, names in choices.items():
 source = root / ('building-kit/Models/GLB format' if kit=='building' else 'furniture-kit/Models/GLTF format')
 target = Path('assets/environment') / kit
 target.mkdir(parents=True, exist_ok=True)
 for name in names:
  src = source / (name+'.glb')
  shutil.copy2(src, target / src.name)
  manifest.append({'asset':str(target/src.name), 'source':str(src), 'license':'CC0'})
 shutil.copy2(root / (kit+'-kit') / 'License.txt', target/'License.txt')
 tex = source/'Textures'
 if tex.exists():
  shutil.copytree(tex, target/'Textures', dirs_exist_ok=True)
Path('assets/environment/manifest.json').write_text(json.dumps(manifest,indent=2))
print(f'Copied {len(manifest)} approved kit models.')
