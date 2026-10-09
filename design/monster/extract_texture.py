import bpy
image = bpy.data.images.get("Image_0")
image.save_render(bpy.path.abspath("//../../../downloads/jane-texture.png"))
