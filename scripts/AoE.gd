extends Node2D
class_name AoE

var src = null
var team: int = 0
var radius: float = 100
var dmg: float = 0
var duration: float = 0.5
var elapsed: float = 0.0
var hit_set: Array = []
var cone_ang: float = -999.0
var arc: float = 0.0
var color: Color = Color.WHITE
var slow_pct: float = 0.0
var slow_duration: float = 0.0
var art_row: int = -1
var stun_time: float = 0.0
var wind_kind: int = -1
var damage_type: String = "skill"
var ring: bool = false
var tick_interval: float = 0
var next_tick: float = 0
var effect_id: String = ""
var effect_dir: Vector2 = Vector2.RIGHT
var zone_kind: String = ""
var arm_delay: float = 0.0
var follows_src: bool = false
var broken_walls: Array = [false,false,false,false,false]
var previous_positions: Dictionary = {}

func setup(_src, pos: Vector2, opts: Dictionary) -> void:
	effect_id=opts.get("effect_id", "");effect_dir=opts.get("effect_dir",Vector2.RIGHT);zone_kind=opts.get("zone_kind", "");arm_delay=opts.get("arm_delay",0.);follows_src=opts.get("follows_src",false)
	src = _src
	damage_type=opts.get("damage_type","skill");ring=opts.get("ring",false);tick_interval=opts.get("tick_interval",0.)
	team = _src.team
	global_position = pos
	radius = opts.get("radius", 100)
	dmg = opts.get("dmg", 0)
	# Trap siblings share hit history; explosions can exclude their direct victim.
	hit_set = opts.get("hit_set",[])
	duration = opts.get("duration", 0.5)
	cone_ang = opts.get("cone_ang", -999.0)
	arc = opts.get("arc", 0.0)
	color = opts.get("color", Color.WHITE)
	slow_pct = opts.get("slow", 0.0)
	stun_time = opts.get("stun",0.0)
	wind_kind = int(opts.get("wind_kind",-1))
	slow_duration = opts.get("slow_dur", 0.0)
	z_index = Constants.Z_AOE
	art_row = SpellArt.row_for(src)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _draw() -> void:
	if KitEffectArt.has_effect(effect_id):
		_draw_kit_effect()
		return
	if ring:
		var fade=clampf((duration-elapsed)*2.,0.,1.)
		draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(color,fade*.85),7.,true)
		for i in range(8):
			var point=Vector2.from_angle(i*TAU/8.)*radius
			draw_line(point,point+Vector2(0,-30),Color(color,fade),5.,true)
		return
	if wind_kind >= 0:
		draw_texture_rect_region(WindArt.texture,Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),WindArt.frame(wind_kind,mini(3,int(elapsed/duration*4))),Color(1,1,1,0.9))
		return
	if art_row >= 0:
		draw_texture_rect_region(SpellArt.impacts, Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), SpellArt.frame(SpellArt.impacts, art_row, mini(7, int(elapsed / duration * 8))), Color(1, 1, 1, 0.7))
	var alpha = 0.55 * (1.0 - elapsed / duration)
	if alpha < 0: alpha = 0
	draw_circle(Vector2.ZERO, radius, Color(color.r, color.g, color.b, alpha * 0.6))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(color.r, color.g, color.b, alpha), 3.0, true)
	# Cone overlay
	if cone_ang > -900:
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in range(17):
			var t = float(i) / 16.0
			var a = cone_ang - arc * 0.5 + arc * t
			pts.append(Vector2(cos(a) * radius, sin(a) * radius))
		draw_colored_polygon(pts, Color(color.r, color.g, color.b, alpha * 0.5))

func update_frame(delta: float) -> void:
	elapsed += delta
	if follows_src and is_instance_valid(src) and not src.dead:global_position=src.world_pos()
	if zone_kind in ["box","cage","lantern"]:
		_update_zone()
		queue_redraw()
		if elapsed>=duration:GameState.aoes.erase(self);queue_free()
		return
	if tick_interval>0 and elapsed>=next_tick:
		hit_set.clear();next_tick=elapsed+tick_interval
	# Deal damage once per entity
	if dmg > 0 and elapsed >= arm_delay:
		var cands = GameState.minions + GameState.champions + GameState.structures
		for u in cands:
			if hit_set.has(u) or u == null or u.dead or u.team == team or not u.is_targetable:
				continue
			if u.kind == "structure" and not u.is_structure_attackable():
				continue
			var d = global_position.distance_to(u.world_pos())
			if d <= radius + u.size * 0.3:
				if ring and absf(d-radius)>22+u.size*.3:continue
				if cone_ang > -900:
					var to_ang = (u.world_pos() - global_position).angle()
					var diff = abs(wrapf(to_ang - cone_ang, -PI, PI))
					if diff > arc * 0.5: continue
				get_tree().call_group("game_main", "deal_damage", src, u, dmg, damage_type)
				hit_set.append(u)
				var guarded="buffs" in u and (u.buffs.has("cc_guard") or u.buffs.has("spell_guard"))
				if stun_time > 0 and "stun" in u and not guarded: u.stun = maxf(u.stun,stun_time)
				if slow_pct > 0 and "buffs" in u and not guarded:
					u.buffs["slow"] = {"pct": slow_pct, "time": slow_duration}
	queue_redraw()
	if elapsed >= duration:
		GameState.aoes.erase(self)
		queue_free()

func _draw_kit_effect() -> void:
	var frame=mini(3,int(elapsed/maxf(.01,duration)*4))
	if zone_kind in ["box","cage"]:frame=0 if elapsed<arm_delay else 3 if duration-elapsed<.35 else 1+int(elapsed*3)%2
	if effect_id=="veigar_w":frame=0 if elapsed<arm_delay*.6 else 1 if elapsed<arm_delay else 2 if elapsed<arm_delay+.2 else 3
	var sheet=KitEffectArt.sheet(effect_id);var region=KitEffectArt.region(effect_id,frame)
	var rect=Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2)
	if effect_id in ["veigar_w","veigar_e"]:rect=KitEffectArt.ground_rect(effect_id,radius)
	# Ground outlines show the exact collision boundary beneath the painted pillars.
	if zone_kind=="cage":draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(.7,.35,1.,.4 if elapsed>=arm_delay else .7),2.,true)
	if effect_id=="veigar_w" and elapsed<arm_delay:draw_arc(Vector2.ZERO,radius,0,TAU,64,Color(.75,.4,1.,.65),2.,true)
	if zone_kind=="box":
		for wall in range(5):
			if not broken_walls[wall]:draw_line(Vector2.from_angle(-PI/2+wall*TAU/5)*radius,Vector2.from_angle(-PI/2+(wall+1)*TAU/5)*radius,Color(.3,1.,.7,.4),2.,true)
	if effect_id=="thresh_e":
		draw_set_transform(Vector2.ZERO,effect_dir.angle());rect=Rect2(-220,-65,440,130)
	elif effect_id=="darius_e":draw_set_transform(Vector2.ZERO,effect_dir.angle());rect=Rect2(-25,-120,245,240)
	if zone_kind=="box" and broken_walls.has(true):
		for wall in range(5):
			if broken_walls[wall]:continue
			var a=Vector2.from_angle(-PI/2+wall*TAU/5)*radius*1.8
			var b=Vector2.from_angle(-PI/2+(wall+1)*TAU/5)*radius*1.8
			var wedge=PackedVector2Array([Vector2.ZERO,a,b])
			var clip=PackedVector2Array([rect.position,rect.position+Vector2(rect.size.x,0),rect.end,rect.position+Vector2(0,rect.size.y)])
			for points in Geometry2D.intersect_polygons(wedge,clip):
				var uv=PackedVector2Array()
				for point in points:uv.append((region.position+(point-rect.position)/rect.size*region.size)/sheet.get_size())
				draw_colored_polygon(points,Color.WHITE,uv,sheet)
	else:draw_texture_rect_region(sheet,rect,region,Color(1,1,1,.9))
	if zone_kind=="lantern" and is_instance_valid(GameState.player) and GameState.player.team==team:
		draw_string(ThemeDB.fallback_font,Vector2(-44,38),"RIGHT-CLICK",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("b9ffe6"))
func _update_zone() -> void:
	if zone_kind=="lantern":
		if not is_instance_valid(src) or src.dead:return
		for ally in GameState.champions:
			if ally.dead or ally.team!=team or hit_set.has(ally) or ally.world_pos().distance_to(global_position)>100:continue
			ally.shield=maxf(ally.shield,dmg);hit_set.append(ally)
		return
	for unit in GameState.champions+GameState.minions:
		if unit.dead or unit.team==team or (zone_kind=="box" and unit.kind!="champion"):continue
		var key=unit.get_instance_id();var before=previous_positions.get(key,unit.world_pos());previous_positions[key]=unit.world_pos()
		if elapsed<arm_delay:continue
		# Blinks can bypass a cage; ordinary movement and forced movement cannot.
		if before.distance_to(unit.world_pos())>180:before=unit.world_pos()
		if zone_kind=="cage":
			if hit_set.has(unit):continue
			var closest=Geometry2D.get_closest_point_to_segment(global_position,before,unit.world_pos())
			if closest.distance_to(global_position)>radius+unit.size*.3+10 or maxf(before.distance_to(global_position),unit.world_pos().distance_to(global_position))<radius-unit.size*.3-10:continue
			hit_set.append(unit)
			if not unit.buffs.has("cc_guard") and not unit.buffs.has("spell_guard") and not ExpansionCombat.spell_block(unit,"magic"):
				unit.stun=maxf(unit.stun,stun_time)
				if "is_dashing" in unit:unit.is_dashing=false
		else:
			for wall in range(5):
				if broken_walls[wall]:continue
				var a=global_position+Vector2.from_angle(-PI/2+wall*TAU/5)*radius
				var b=global_position+Vector2.from_angle(-PI/2+(wall+1)*TAU/5)*radius
				var near=Geometry2D.get_closest_point_to_segment(unit.world_pos(),a,b).distance_to(unit.world_pos())<12+unit.size*.3
				if not near and Geometry2D.segment_intersects_segment(before,unit.world_pos(),a,b)==null:continue
				var first=not broken_walls.has(true);broken_walls[wall]=true
				if first:NewHeroKits.hit(src,unit,dmg,"magic")
				if not unit.dead and not unit.buffs.has("cc_guard") and not unit.buffs.has("spell_guard"):unit.buffs.slow={"pct":.99,"time":2. if first else 1.}
				break
func try_lantern(unit,point: Vector2) -> bool:
	if zone_kind!="lantern" or not is_instance_valid(src) or src.dead or unit==src or unit.team!=team or unit.dead or unit.stun>0 or point.distance_to(global_position)>55 or unit.world_pos().distance_to(global_position)>180:return false
	if unit.is_bot and not BotSafety.can_enter(unit,src.world_pos()):return false
	unit.stop_actions();unit.dash_target=src.world_pos();unit.is_dashing=true
	return true
