import json, struct
from pathlib import Path
for name in ['wall','wall-window-square','wall-window-wide-square','door-rotate-square-a','stairs-closed','border','barricade-doorway-a','roof-flat-center']:
 path=Path('assets/environment/building')/(name+'.glb')
 with path.open('rb') as stream:
  stream.read(12)
  length, _ = struct.unpack('<II',stream.read(8))
  data=json.loads(stream.read(length))
 print(path.name, 'meshes',[(m.get('name'),len(m['primitives'])) for m in data['meshes']], 'materials',[(m.get('name'),m.get('alphaMode')) for m in data.get('materials',[])])
 for mesh in data['meshes']:
  print([(data['accessors'][p['attributes']['POSITION']].get('min'),data['accessors'][p['attributes']['POSITION']].get('max')) for p in mesh['primitives']])
 print('nodes',data['nodes'])
