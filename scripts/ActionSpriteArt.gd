class_name ActionSpriteArt
extends RefCounted
# Per-cell metadata comes from the real generated atlases, never from a placeholder.
static var manifest: Dictionary = {}
static var textures: Dictionary = {}
static func entry(key: String) -> Dictionary:
 if manifest.is_empty():
  manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/manifest.json"))
 return manifest[key]
static func texture(key: String, override_path: String = "") -> Texture2D:
 var path = override_path if override_path!="" else str(entry(key).path)
 if not textures.has(path): textures[path] = load(path)
 return textures[path]
static func texture_for_frame(key: String, action: String, index: int) -> Texture2D:
 return texture(key,str(frame(key,action,index).get("path","")))
static func frame(key: String, action: String, index: int) -> Dictionary:
 var data = entry(key)
 var row = int(data.actions.get(action,0))
 return data.frames[row*6+clampi(index,0,5)]
static func region(key: String, action: String, index: int) -> Rect2:
 var cell = frame(key,action,index).region
 return Rect2(cell[0],cell[1],cell[2],cell[3])
static func rect(key: String, action: String, index: int, height: float) -> Rect2:
 var data = entry(key)
 var cell = frame(key,action,index)
 var scale = height/float(data.body_height)*float(cell.get("relative_scale",1.0))
 return Rect2(-Vector2(cell.pivot[0],cell.pivot[1])*scale,Vector2(cell.region[2],cell.region[3])*scale)
static func body_rect(key: String, height: float, flip: bool = false) -> Rect2:
 var data = entry(key)
 var cell = frame(key,"idle",0)
 var scale = height/float(data.body_height)
 var body = cell.body
 var result = Rect2(Vector2(body[0]-cell.pivot[0],body[1]-cell.pivot[1])*scale,Vector2(body[2],body[3])*scale)
 if flip: result.position.x = -result.end.x
 return result

static func apply_frame_mask(material: ShaderMaterial, key: String, action: String, index: int) -> void:
 var cell=frame(key,action,index)
 var texture=texture_for_frame(key,action,index)
 var dimensions=Vector2(texture.get_width(),texture.get_height())
 var values=PackedVector4Array()
 for bounds in cell.get("exclusions",[]):
  values.append(Vector4(bounds[0]/dimensions.x,bounds[1]/dimensions.y,bounds[2]/dimensions.x,bounds[3]/dimensions.y))
 material.set_shader_parameter("atlas_pixel_size",Vector2.ONE/dimensions)
 material.set_shader_parameter("exclusion_count",values.size())
 values.resize(8)
 material.set_shader_parameter("excluded_rects",values)
