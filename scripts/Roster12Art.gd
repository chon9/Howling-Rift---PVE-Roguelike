class_name Roster12Art
extends RefCounted
static var textures: Dictionary={}
static var crops: Dictionary={}
static var icon_crops: Dictionary={}
static func texture(path: String) -> Texture2D:
 if not textures.has(path):textures[path]=load(path)
 return textures[path]
static func icon(key: String,row: int) -> Texture2D:
 var i=RosterExpansion12.KEYS.find(key);var atlas=texture("res://assets/ui/roster12-icons-%d-v1.png" % (i/4))
 if icon_crops.is_empty():icon_crops=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/roster12-icon-crops.json"))
 var crop=icon_crops[str(i/4)][row*4+i%4]
 var result=AtlasTexture.new();result.atlas=atlas;result.region=Rect2(crop[0],crop[1],crop[2],crop[3]);result.filter_clip=true;return result
static func sheet(id: String) -> Texture2D:
 return texture("res://assets/vfx/"+id.get_slice("_",0)+"-skills-v1.png")
static func region(id: String,frame: int) -> Rect2:
 if crops.is_empty():crops=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/roster12-crops.json"))
 var hero=id.get_slice("_",0);var row=["q","w","e","r"].find(id.get_slice("_",1));row=maxi(0,row)
 var crop=crops[hero][row*4+clampi(frame,0,3)]
 return Rect2(crop[0],crop[1],crop[2],crop[3])
