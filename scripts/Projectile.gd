extends Node2D
class_name Projectile

var src = null
var team: int = 0
var dir: Vector2 = Vector2.RIGHT
var speed: float = 400
var dmg: float = 0
var pierce: int = 0
var life: float = 2.0
var size: float = 6
var color: Color = Color.WHITE
var stun_time: float = 0
var pull_distance: float = 0
var knockback_distance: float = 0
var wall_stun: float = 0
var slow_pct: float = 0
var slow_dur: float = 0
var refund_mp_on_kill: float = 0
var trail: bool = false
var is_ult: bool = false
var is_turret: bool = false
var homing = null
var hit_set: Array = []
var trail_t: float = 0.0
var shape: String = "orb"   # orb | arrow | fireball | bolt | ice
var damage_type: String = "auto"
var targeted: bool = false
var boomerang: bool = false
var returning: bool = false
var return_at: float = 0.0
var mark_bonus: float = 0.0
var art_row: int = -1
var expansion_art: bool = false
var animation_time: float = 0.0
var sonic_mark: bool = false
var explosion: float = 0.0
var wind_kind: int = -1
# Visual altitude/size are independent of ground-plane collision radius.
var visual_height: float = 0.0
var visual_dimensions: Vector2 = Vector2.ZERO
var visual_scale: float = 1.0
var hook_chain: bool = false
var effect_id: String = ""
var thresh_mark: bool = false
func configure_presentation() -> void:
	var hero = is_instance_valid(src) and src.kind == "champion"
	visual_scale = Constants.CHAMP_ART_SCALE if hero else 1.0
	visual_height = 52.0*Constants.CHAMP_ART_SCALE if hero else 18.0 if is_instance_valid(src) and src.kind == "minion" else 0.0
	var body_height = Constants.CHAMP_ART_HEIGHT if hero else 70.0
	var width = clampf(size*3.8,22.0,body_height*(0.85 if is_ult else 0.60))
	if damage_type=="auto" and hero: width=body_height*0.32
	visual_dimensions=Vector2(width,width*(0.44 if is_ult else 0.58))
func visual_rect() -> Rect2:
	return Rect2(-visual_dimensions*0.5,visual_dimensions)
func visual_origin() -> Vector2:
	# Convert screen-up to the projectile's rotated local space.
	return Vector2(0,-visual_height).rotated(-rotation)

func setup(_src, pos: Vector2, _dir: Vector2, opts: Dictionary) -> void:
	effect_id = opts.get("effect_id", "")
	thresh_mark = opts.get("thresh_mark",false)
	src = _src
	team = _src.team
	global_position = pos
	dir = _dir.normalized()
	if dir.length_squared() < 0.01: dir = Vector2.RIGHT
	speed = opts.get("speed", 400)
	dmg = opts.get("dmg", 0)
	pierce = opts.get("pierce", 0)
	life = opts.get("life", 2)
	size = opts.get("size", 6)
	color = opts.get("color", Color.WHITE)
	stun_time = opts.get("stun", 0)
	pull_distance=opts.get("pull_distance",0.)
	knockback_distance=opts.get("knockback_distance",0.)
	wall_stun=opts.get("wall_stun",0.)
	slow_pct = opts.get("slow", 0)
	slow_dur = opts.get("slow_dur", 0)
	refund_mp_on_kill = opts.get("refund_mp_on_kill", 0)
	trail = opts.get("trail", false)
	is_ult = opts.get("is_ult", false)
	is_turret = opts.get("is_turret", false)
	homing = opts.get("homing", null)
	targeted = homing != null
	damage_type = opts.get("damage_type", "auto" if is_turret or _src.kind != "champion" else "skill")
	boomerang = opts.get("boomerang", false)
	return_at = life * 0.5
	mark_bonus = opts.get("mark_bonus", 0.0)
	sonic_mark = opts.get("sonic_mark",false)
	explosion = opts.get("explosion",0.0)
	shape = opts.get("shape", "orb")
	wind_kind = int(opts.get("wind_kind",-1))
	hook_chain = opts.get("hook_chain",false)
	z_index = Constants.Z_PROJ
	rotation = dir.angle()
	art_row = SpellArt.row_for(src)
	if is_instance_valid(src) and src.kind == "champion" and ExpansionRoster.KEYS.has(src.hero_key):
		expansion_art = true
		art_row = ExpansionRoster.KEYS.find(src.hero_key)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	configure_presentation()

func _draw() -> void:
	if hook_chain and is_instance_valid(src):
		draw_set_transform(Vector2.ZERO,-rotation)
		var start=src.world_pos()-global_position-Vector2(0,visual_height)
		var end=Vector2(0,-visual_height)
		draw_line(start,end,Color(.1,.8,.65,.25),5,true)
		draw_line(start,end,Color(.62,.95,.8,.8),1.8,true)
		var length=start.distance_to(end)
		for i in range(0,int(length),15):
			draw_circle(start.lerp(end,float(i)/maxf(1,length)),2,Color(.6,.9,.75,.75))
		draw_set_transform(Vector2.ZERO)
	draw_set_transform(visual_origin())
	if wind_kind >= 0:
		var frame = int(animation_time*14)%4
		var art_scale = visual_scale
		if wind_kind == 1:
			# The funnel stays upright while its ground position travels along the skillshot.
			draw_set_transform(Vector2.ZERO,-rotation)
			draw_texture_rect_region(WindArt.texture,Rect2(Vector2(-30,-104)*art_scale,Vector2(60,104)*art_scale),WindArt.frame(1,frame))
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(WindArt.texture,Rect2(Vector2(-38,-14)*art_scale,Vector2(76,28)*art_scale),WindArt.frame(0,frame))
		return
	if art_row >= 0:
		var sheet = KitEffectArt.sheet(effect_id) if KitEffectArt.has_effect(effect_id) else SpellArt.missile_sheet(expansion_art)
		if damage_type != "auto":
			draw_line(Vector2(-visual_dimensions.x*.45,0),Vector2(visual_dimensions.x*.3,0),Color(color.r,color.g,color.b,.45),maxf(3,visual_dimensions.y*.45),true)
		draw_texture_rect_region(sheet, visual_rect(), KitEffectArt.region(effect_id,int(animation_time*16)%4) if KitEffectArt.has_effect(effect_id) else SpellArt.missile_frame(sheet, art_row, int(animation_time * 18) % 8))
		if shape == "heart": draw_arc(Vector2.ZERO, size * 1.2, 0, TAU, 24, Color("f69ed4"), 2, true)
		return
	# All shapes are drawn in local space with +X being "forward" (direction of travel).
	match shape:
		"heart":
			draw_circle(Vector2(-3, -4), size * 0.55, color)
			draw_circle(Vector2(3, -4), size * 0.55, color)
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -3), Vector2(9, -3), Vector2(0, 10)]), color)
		"wave":
			draw_arc(Vector2(-10, 0), size, -PI / 2, PI / 2, 32, Color(color.r, color.g, color.b, 0.3), 16, true)
			draw_arc(Vector2(-10, 0), size, -PI / 2, PI / 2, 32, color, 6, true)
		"arrow":
			# Halo
			draw_circle(Vector2.ZERO, size * 1.3, Color(color.r, color.g, color.b, 0.3))
			# Shaft
			draw_line(Vector2(-size * 1.4, 0), Vector2(size * 1.2, 0), Color.WHITE, 2.0)
			# Arrowhead
			draw_colored_polygon(PackedVector2Array([
				Vector2(size * 2.0, 0),
				Vector2(size * 0.8, size * 0.7),
				Vector2(size * 0.8, -size * 0.7)
			]), color)
			# Fletching
			draw_colored_polygon(PackedVector2Array([
				Vector2(-size * 1.6, 0),
				Vector2(-size * 0.8, size * 0.5),
				Vector2(-size * 0.8, -size * 0.5)
			]), Color(color.r, color.g, color.b, 0.8))
		"fireball":
			# Outer flames
			draw_circle(Vector2.ZERO, size * 2.0, Color(1.0, 0.4, 0.0, 0.3))
			draw_circle(Vector2.ZERO, size * 1.4, Color(1.0, 0.5, 0.1, 0.6))
			draw_circle(Vector2.ZERO, size, color)
			# White-hot core
			draw_circle(Vector2.ZERO, size * 0.5, Color(1, 1, 0.7, 0.95))
			# Trailing flame tail
			draw_colored_polygon(PackedVector2Array([
				Vector2(-size * 2.5, 0),
				Vector2(-size * 0.3, size * 0.6),
				Vector2(-size * 0.3, -size * 0.6)
			]), Color(1.0, 0.3, 0.0, 0.5))
		"bolt":
			# Turret shot — long energy bolt
			draw_circle(Vector2.ZERO, size * 1.6, Color(color.r, color.g, color.b, 0.3))
			draw_colored_polygon(PackedVector2Array([
				Vector2(size * 1.8, 0),
				Vector2(0, size * 0.5),
				Vector2(-size * 1.2, 0),
				Vector2(0, -size * 0.5)
			]), color)
			draw_circle(Vector2.ZERO, size * 0.6, Color(1, 1, 1, 0.9))
		"ice":
			# Ice crystal (Ashe R)
			draw_circle(Vector2.ZERO, size * 1.8, Color(color.r, color.g, color.b, 0.4))
			draw_colored_polygon(PackedVector2Array([
				Vector2(size * 1.7, 0),
				Vector2(0, size * 1.0),
				Vector2(-size * 1.2, 0),
				Vector2(0, -size * 1.0)
			]), color)
			draw_colored_polygon(PackedVector2Array([
				Vector2(size * 0.9, 0),
				Vector2(0, size * 0.5),
				Vector2(-size * 0.6, 0),
				Vector2(0, -size * 0.5)
			]), Color(1, 1, 1, 0.9))
		_:  # "orb" default
			draw_circle(Vector2.ZERO, size * 1.7, Color(color.r, color.g, color.b, 0.35))
			draw_circle(Vector2.ZERO, size, color)
			draw_circle(Vector2.ZERO, size * 0.5, Color(1, 1, 1, 0.75))

func update_frame(delta: float) -> void:
	animation_time += delta
	# Homing adjust
	if not is_instance_valid(src): src = null
	if boomerang and not returning and (life <= return_at or global_position.y < 20 or global_position.y > Constants.WORLD_H - 20):
		returning = true
		hit_set.clear()
	if returning and src != null:
		dir = (src.world_pos() - global_position).normalized()
		if src.world_pos().distance_to(global_position) < 18:
			_destroy()
			return
	if targeted and (not is_instance_valid(homing) or homing.dead):
		_destroy()
		return
	if is_instance_valid(homing) and not homing.dead:
		var want = (homing.world_pos() - global_position).normalized()
		dir = dir.lerp(want, 1.0-exp(-13.4*delta)).normalized()
	global_position += dir * speed * delta
	rotation = dir.angle()
	life -= delta
	if trail or is_ult:
		trail_t += delta
		if trail_t > 0.03:
			trail_t = 0.0
			get_tree().call_group("game_main", "spawn_trail", global_position-Vector2(0,visual_height),
				color, minf(visual_dimensions.y*0.18,size*0.6))

	if life <= 0 or global_position.x < -50 or global_position.x > Constants.WORLD_W + 50 \
			or global_position.y < -50 or global_position.y > Constants.WORLD_H + 50:
		_destroy(); return

	for guard in GameState.champions:
		if guard.dead or guard.team == team or is_turret or not guard.buffs.has("wind_wall"): continue
		var wall_direction: Vector2 = guard.buffs.wind_wall.direction
		var offset = global_position-guard.world_pos()-wall_direction*50
		if absf(offset.dot(wall_direction)) < 25+size and absf(offset.dot(wall_direction.orthogonal())) < 90+size:
			_destroy()
			return
	# Hit scan
	var cands = GameState.minions + GameState.champions + GameState.structures
	for u in cands:
		if targeted and u != homing: continue
		if hit_set.has(u): continue
		if u == null or u.dead or u.team == team or not u.is_targetable: continue
		if u.kind == "structure" and not u.is_structure_attackable(): continue
		var dd = global_position.distance_to(u.world_pos())
		if dd < size + u.size * 0.7:
			get_tree().call_group("game_main", "deal_damage", src, u, dmg, damage_type)
			if thresh_mark and is_instance_valid(src) and not u.dead and "buffs" in u and not u.buffs.has("cc_guard") and not u.buffs.has("spell_guard"):
				u.buffs.chain_mark = {"time":1.5,"src":src}
			if sonic_mark and is_instance_valid(src) and not u.dead and "buffs" in u:
				u.buffs.sonic_mark = {"time":4.0,"src":src}
				src.sonic_target = u
			if explosion > 0:
				get_tree().call_group("game_main","spawn_aoe",src,u.world_pos(),{"radius":explosion,"dmg":dmg*0.65,"duration":0.35,"color":color,"hit_set":[u]})
			if mark_bonus > 0 and "buffs" in u:
				u.buffs["flux_mark"] = {"time":4.0, "src":src, "bonus":mark_bonus}
			var guarded="buffs" in u and (u.buffs.has("cc_guard") or u.buffs.has("spell_guard"))
			if pull_distance>0 and not guarded and u.kind!="structure" and is_instance_valid(src):
				if hook_chain:ForcedMotion.apply(u,src.world_pos()-u.world_pos(),pull_distance)
				else:u.global_position=GameState.clamp_walkable(u.world_pos()+(src.world_pos()-u.world_pos()).normalized()*pull_distance)
			if knockback_distance>0 and not guarded and not u.dead and u.kind!="structure":
				var destination=u.world_pos()+dir*knockback_distance
				u.global_position=GameState.clamp_walkable(destination)
				if wall_stun>0 and u.world_pos().distance_to(destination)>10:u.stun=maxf(u.stun,wall_stun)
			if stun_time > 0 and "stun" in u and not guarded: u.stun = max(u.stun, stun_time)
			if slow_pct > 0 and "buffs" in u and not guarded:
				var cur = u.buffs.get("slow", {"pct": 0.0, "time": 0.0})
				if slow_pct >= cur.get("pct", 0.0):
					u.buffs["slow"] = { "pct": slow_pct, "time": max(cur.get("time", 0.0), slow_dur) }
			if refund_mp_on_kill > 0 and u.dead and src != null and src.kind == "champion":
				src.mp = min(src.mp_max, src.mp + refund_mp_on_kill)
			hit_set.append(u)
			# Minion contact is handled once in damage resolution with a tiny spark.
			if u.kind != "minion": get_tree().call_group("game_main", "spawn_impact", global_position, color, size * 2)
			if pierce <= 0:
				_destroy(); return
			pierce -= 1
	queue_redraw()

func _destroy() -> void:
	GameState.projectiles.erase(self)
	queue_free()
