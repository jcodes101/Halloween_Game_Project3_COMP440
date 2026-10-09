"""Read-only inspection of the user-supplied Blender working copy."""
import bpy
import json

report = {"objects": [], "images": []}
for obj in bpy.data.objects:
    item = {"name": obj.name, "type": obj.type}
    if obj.type == "MESH":
        item.update(vertices=len(obj.data.vertices), polygons=len(obj.data.polygons),
                    materials=[slot.material.name if slot.material else None for slot in obj.material_slots],
                    shape_keys=list(obj.data.shape_keys.key_blocks.keys()) if obj.data.shape_keys else [],
                    vertex_groups=[group.name for group in obj.vertex_groups],
                    modifiers=[mod.type for mod in obj.modifiers])
    if obj.type == "ARMATURE":
        item["bones"] = [bone.name for bone in obj.data.bones]
    report["objects"].append(item)
for image in bpy.data.images:
    report["images"].append({"name": image.name, "size": list(image.size),
                             "packed": bool(image.packed_file), "filepath": image.filepath})
print("MODEL_INSPECTION=" + json.dumps(report))
