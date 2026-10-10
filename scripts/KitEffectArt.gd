class_name KitEffectArt
extends RefCounted
const GROUPS={"thresh": "warden-vexel", "veigar":"warden-vexel","darius":"rook-granite","malphite":"rook-granite","morgana":"noctra-vesper","vayne":"noctra-vesper"}
static var textures: Dictionary={}
static var bounds: Dictionary={}
static var ground_texture: Texture2D
static func has_effect(id: String) -> bool:
 if id.get_slice("_",0) in RosterExpansion12.KEYS:return id.get_slice("_",1) in ["q","w","e","r","auto"]
 return GROUPS.has(id.get_slice("_",0)) and id.get_slice("_",1) in ["q","w","e","r"]
static func sheet(id: String) -> Texture2D:
 if id.get_slice("_",0) in RosterExpansion12.KEYS:return Roster12Art.sheet(id)
 if id in ["veigar_w","veigar_e"]:
  if ground_texture==null:ground_texture=load("res://assets/vfx/vexel-ground-v2.png")
  return ground_texture
 var group=GROUPS[id.get_slice("_",0)]
 if not textures.has(group):textures[group]=load("res://assets/vfx/"+group+"-skills-v1.png")
 return textures[group]
static func region(id: String,frame: int) -> Rect2:
 if id.get_slice("_",0) in RosterExpansion12.KEYS:return Roster12Art.region(id,frame)
 if id in ["veigar_w","veigar_e"]:
  var cell=sheet(id).get_size()/Vector2(4,2)
  return Rect2(Vector2(clampi(frame,0,3),0 if id=="veigar_w" else 1)*cell+Vector2.ONE*2,cell-Vector2.ONE*4)
 if bounds.is_empty():bounds=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/kit-effect-crops-v1.json"))
 var hero=id.get_slice("_",0);var skill=id.get_slice("_",1)
 var row=["q","w","e","r"].find(skill)
 if hero in ["veigar","malphite","vayne"]:row+=4
 var texture=sheet(id);var cell=Vector2(texture.get_width()/4.,texture.get_height()/8.)
 var crop=bounds[GROUPS[hero]][row]
 return Rect2(Vector2(clampi(frame,0,3),row)*cell+Vector2(crop[0],crop[1]),Vector2(crop[2],crop[3]))
static func ground_rect(id: String,radius: float) -> Rect2:
 # Map the painted ground rim, rather than pillar/glow bounds, to collision radius.
 var cell=sheet(id).get_size()/Vector2(4,2)
 var rim_ratio=.39 if id=="veigar_w" else .375
 var anchor=cell*Vector2(.5,.5 if id=="veigar_w" else .48)-Vector2.ONE*2
 var scale_factor=radius/(cell.x*rim_ratio)
 return Rect2(-anchor*scale_factor,(cell-Vector2.ONE*4)*scale_factor)
