extends Node2D
# Draws a LoL-style range indicator under the player when the user hovers a
# skill slot in the HUD (or holds a skill key). Shows:
#   * cast range as a dashed circle around champion
#   * a skillshot preview that follows the cursor (line, cone, or target circle)

var aiming_idx: int = -1
var player = null
var override_aim: bool = false
var override_point: Vector2 = Vector2.ZERO

func _ready() -> void:
	z_index = Constants.Z_AOE
	process_mode = Node.PROCESS_MODE_ALWAYS

func set_aim(p, idx: int) -> void:
	player = p
	aiming_idx = idx
	queue_redraw()

func clear_aim() -> void:
	aiming_idx = -1
	override_aim = false
	queue_redraw()

func _process(_delta: float) -> void:
	if aiming_idx >= 0:
		if player == null or player.dead:
			aiming_idx = -1
		queue_redraw()

func _draw() -> void:
	if aiming_idx < 0 or player == null or player.dead: return
	var sk = player.hero["skills"][aiming_idx]
	var rng = sk.get("range", 0.0)
	var kind = sk.get("kind", "self")
	var ppos = player.global_position
	var mouse = override_point if override_aim else get_global_mouse_position()
	var atk_col = Color(1.0, 0.86, 0.33, 0.9)
	var line_col = Color(1.0, 0.86, 0.33, 0.5)

	# Base: dashed range circle
	if rng > 0:
		_draw_dashed_arc(ppos, rng, 72, line_col, 2.0, 10, 6)
	# Skillshot preview
	var cursor_dir = (mouse - ppos)
	var cursor_dist = cursor_dir.length()
	if cursor_dist < 0.001: cursor_dir = Vector2.RIGHT
	else: cursor_dir = cursor_dir.normalized()
	# Clamp to range for the aim point
	var aim_pt = ppos + cursor_dir * min(cursor_dist, rng if rng > 0 else cursor_dist)
	if sk.cast_id=="thresh_e":
		var across=cursor_dir.orthogonal()*65
		var along=cursor_dir*220
		var corners=PackedVector2Array([ppos-along-across,ppos+along-across,ppos+along+across,ppos-along+across])
		draw_colored_polygon(corners,Color(atk_col,.18))
		corners.append(corners[0]);draw_polyline(corners,atk_col,2.,true)
		draw_line(ppos-cursor_dir*100,ppos+cursor_dir*100,atk_col,3.,true)
		draw_line(ppos+cursor_dir*100,ppos+cursor_dir*75+across*.3,atk_col,3.,true)
		draw_line(ppos+cursor_dir*100,ppos+cursor_dir*75-across*.3,atk_col,3.,true)
		return
	if sk.cast_id=="thresh_r":
		var corners=PackedVector2Array()
		for i in range(6):corners.append(ppos+Vector2.from_angle(-PI/2+i*TAU/5)*180)
		draw_polyline(corners,atk_col,3.,true)
		return
	match kind:
		"line":
			# Narrow line to aim point
			var perp = Vector2(-cursor_dir.y, cursor_dir.x) * 12
			var pts = PackedVector2Array([
				ppos + perp, aim_pt + perp,
				aim_pt - perp, ppos - perp
			])
			draw_colored_polygon(pts, Color(atk_col.r, atk_col.g, atk_col.b, 0.25))
			# Volley specifically has a fan shape (9 arrows at 0.09 rad)
			if sk["cast_id"] == "ashe_w":
				var base_ang = cursor_dir.angle()
				var span = 0.09 * 4.0
				var fan = PackedVector2Array([ppos])
				for i in range(17):
					var t = float(i) / 16.0
					var a = base_ang - span + span * 2 * t
					fan.append(ppos + Vector2(cos(a), sin(a)) * rng)
				draw_colored_polygon(fan, Color(atk_col.r, atk_col.g, atk_col.b, 0.18))
		"cone":
			# Cone centered on aim direction (~1.2 rad spread like Annie W)
			var base_ang = cursor_dir.angle()
			var span = 0.6
			var cx = ppos + cursor_dir * (rng * 0.5)
			var fan = PackedVector2Array([ppos])
			for i in range(17):
				var t = float(i) / 16.0
				var a = base_ang - span + span * 2 * t
				fan.append(ppos + Vector2(cos(a), sin(a)) * rng)
			draw_colored_polygon(fan, Color(atk_col.r, atk_col.g, atk_col.b, 0.25))
			# Cone AoE circle at mid
			draw_arc(cx, 180.0 * 0.5, 0, TAU, 32, atk_col, 2.0, true)
		"point", "target":
			# Circle at aim point
			var impact_r = 90.0
			if sk.cast_id=="veigar_w":impact_r=150.
			elif sk.cast_id=="veigar_e":impact_r=155.
			elif sk["cast_id"] == "annie_r": impact_r = 200.0
			elif sk["cast_id"] == "garen_r": impact_r = 60.0
			if sk.cast_id in ["veigar_w","veigar_e"]:
				var preview=KitEffectArt.ground_rect(sk.cast_id,impact_r)
				preview.position+=aim_pt
				draw_texture_rect_region(KitEffectArt.sheet(sk.cast_id),preview,KitEffectArt.region(sk.cast_id,0),Color(1,1,1,.55))
			draw_arc(aim_pt, impact_r, 0, TAU, 48,
				Color(atk_col.r, atk_col.g, atk_col.b, 0.9), 2.0, true)
			draw_circle(aim_pt, impact_r,
				Color(atk_col.r, atk_col.g, atk_col.b, 0.15))
		"self":
			# Just show the AoE/self circle around champion
			draw_arc(ppos, max(rng, 70.0), 0, TAU, 48, atk_col, 2.0, true)
			draw_circle(ppos, max(rng, 70.0),
				Color(atk_col.r, atk_col.g, atk_col.b, 0.1))

func _draw_dashed_arc(center: Vector2, radius: float, pts: int, col: Color,
		width: float, on_segs: int, off_segs: int) -> void:
	var period = on_segs + off_segs
	var prev = Vector2(center.x + radius, center.y)
	for i in range(1, pts + 1):
		var a = TAU * i / float(pts)
		var p = center + Vector2(cos(a), sin(a)) * radius
		if (i - 1) % period < on_segs:
			draw_line(prev, p, col, width, true)
		prev = p
