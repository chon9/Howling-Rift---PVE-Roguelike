class_name HeroArt
extends RefCounted
const EXTENDED = preload("res://assets/champions/extended-roster.png")
const KEYS = ["yasuo","leesin","zed","jinx","katarina","kayle"]
static func texture_for(key: String) -> Texture2D:
 if key in RosterExpansion12.KEYS:return Roster12Art.icon(key,0)
 if ExpansionRoster.KEYS.has(key): return expansion_icon(key,0)
 var index = KEYS.find(key)
 if index < 0: return load("res://assets/champions/%s-painted.png" % key)
 var result = AtlasTexture.new()
 result.atlas = EXTENDED
 var cell = Vector2(EXTENDED.get_width()/3.0,EXTENDED.get_height()/2.0)
 result.region = Rect2(Vector2(index%3,index/3)*cell,cell)
 result.filter_clip = true
 return result
static func expansion_icon(key: String,row: int) -> Texture2D:
 var atlas=load("res://assets/ui/expansion-hero-icons-v1.png")
 var result=AtlasTexture.new();result.atlas=atlas
 var cell=Vector2(atlas.get_width()/6.,atlas.get_height()/5.)
 result.region=Rect2(Vector2(ExpansionRoster.KEYS.find(key),row)*cell+Vector2(3,3),cell-Vector2(6,6));result.filter_clip=true
 return result
