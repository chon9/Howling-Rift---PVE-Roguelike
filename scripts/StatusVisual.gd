extends Node2D
# Persistent statuses follow the unit and use authoritative remaining durations.
var unit
var phase: float = 0.0
var stun_remaining: float = 0.0
var ignite_remaining: float = 0.0
var shield_amount: float = 0.0
var shield_pulse: float = 0.0
var fire_texture: Texture2D
var font: Font = ThemeDB.fallback_font

func _ready() -> void:
 z_index = Constants.Z_FX-Constants.Z_UNITS
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 fire_texture = load("res://assets/vfx/ignite-status-v1.png")
 refresh()

func refresh() -> void:
 if not is_instance_valid(unit): return
 stun_remaining = maxf(0,unit.stun) if not unit.dead else 0.0
 ignite_remaining = maxf(0,float(unit.buffs.get("ignite",{}).get("time",0))) if not unit.dead else 0.0
 var next_shield = maxf(0, unit.shield) if unit.kind == "champion" and not unit.dead else 0.0
 if next_shield != shield_amount: shield_pulse = 0.3 if next_shield > shield_amount else 0.18
 shield_amount = next_shield
 visible = not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty() or stun_remaining>0 or ignite_remaining>0 or shield_amount>0 or ["grand_challenge","rifle_mark","artillery","arcanopulse","parry","roster_attack"].any(func(k):return unit.buffs.has(k)) or unit.buffs.keys().any(func(k):return k.begins_with("vital_"))
 queue_redraw()

func _process(delta: float) -> void:
 if not GameState.paused:
  phase += delta
  shield_pulse = maxf(0, shield_pulse-delta)
 refresh()

func fire_frame() -> Rect2:
 if fire_texture == null: return Rect2()
 var cell = Vector2(fire_texture.get_width()/4.0,fire_texture.get_height())
 return Rect2(Vector2(int(phase*12)%4,0)*cell,cell)

func _badge(text: String, y: float, color: Color, spiral: bool = false) -> void:
 var width = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x+16
 var left = -width/2+10 if spiral else -width/2
 draw_style_box(_background(color),Rect2(left-4,y-18,width+8,24))
 draw_string_outline(font,Vector2(left+8,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,1,Color.BLACK)
 draw_string(font,Vector2(left+8,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color.lightened(0.45))
 draw_line(Vector2(left,y+4),Vector2(left+width,y+4),color,2,true)
 if spiral:
  var center = Vector2(left-17,y-7)
  draw_circle(center,14,Color(0.04,0.02,0.09,0.9))
  var points = PackedVector2Array()
  for i in range(65):
   var progress = float(i)/64.0
   var angle = progress*TAU*1.8-phase*3
   points.append(center+Vector2(cos(angle),sin(angle))*(2+progress*10))
  draw_polyline(points,color.lightened(0.3),2.8,true)

func _background(color: Color) -> StyleBoxFlat:
 var box = StyleBoxFlat.new()
 box.bg_color = Color(0.025,0.035,0.055,0.94)
 box.border_color = Color(color,0.8)
 box.set_border_width_all(1)
 box.set_corner_radius_all(3)
 return box

func _draw() -> void:
 if not is_instance_valid(unit) or unit.dead: return
 _draw_deadeye()
 _draw_roster_status()
 var hero = unit.kind == "champion"
 var head_y = -Constants.CHAMP_ART_HEIGHT-56 if hero else unit.art_rect().position.y-24.0
 if shield_amount>0:
  var center = Vector2(0,-Constants.CHAMP_ART_HEIGHT*.48)
  var pulse = shield_pulse/0.3
  var points = PackedVector2Array()
  for i in range(65):
   var angle = TAU*i/64.0
   points.append(center+Vector2(cos(angle)*Constants.CHAMP_ART_HEIGHT*.34,sin(angle)*Constants.CHAMP_ART_HEIGHT*.53))
  draw_colored_polygon(points,Color(0.42,0.77,1.0,0.065+pulse*0.1))
  draw_polyline(points,Color(0.5,0.82,1,0.15+pulse*0.2),6*Constants.CHAMP_ART_SCALE,true)
  draw_polyline(points,Color(0.77,0.94,1,0.48+pulse*0.4),1.6,true)
  for offset in [0.0,PI]:
   var arc = PackedVector2Array()
   for i in range(18):
    var angle = phase*0.6+offset+float(i)/17*0.6
    arc.append(center+Vector2(cos(angle)*Constants.CHAMP_ART_HEIGHT*.34,sin(angle)*Constants.CHAMP_ART_HEIGHT*.53))
   draw_polyline(arc,Color(0.86,0.97,1,0.72),2.4,true)
 if ignite_remaining>0:
  # The atlas leaves the torso transparent while flames climb its sides.
  if fire_texture != null:
   var effect_scale = Constants.CHAMP_ART_SCALE if hero else unit.size*2.7/108.0
   draw_texture_rect_region(fire_texture,Rect2(Vector2(-48,-100)*effect_scale,Vector2(96,120)*effect_scale),fire_frame(),Color(1,1,1,0.85))
  var burn_y = head_y-30 if stun_remaining>0 else head_y
  _badge("IGNITE %.1fs" % ignite_remaining,burn_y,Color("ff8640"))
 if stun_remaining>0:
  _badge(("AIRBORNE" if unit.buffs.has("airborne") else "STUNNED")+" %.1fs" % stun_remaining,head_y-HeroControl.lift(unit),Color("ba8bff"),not unit.buffs.has("airborne"))

func _draw_roster_status() -> void:
 var vital_key="vital_"+str(GameState.champions.find(GameState.player)) if is_instance_valid(GameState.player) else ""
 if unit.buffs.has(vital_key) or unit.buffs.has("grand_challenge"):
  var challenge=unit.buffs.has("grand_challenge");var b=unit.buffs.grand_challenge if challenge else unit.buffs[vital_key]
  for side in range(4):
   if challenge and int(b.mask)&(1<<side):continue
   if not challenge and side!=int(b.side):continue
   var direction=Vector2.from_angle(side*PI/2);var point=direction*42;var tangent=direction.orthogonal()
   draw_colored_polygon(PackedVector2Array([point-direction*9,point+direction*5+tangent*8,point+direction*5-tangent*8]),Color("f4c46f"))
   draw_arc(Vector2.ZERO,42,side*PI/2-.3,side*PI/2+.3,12,Color("fff1bc"),3.,true)
 if unit.buffs.has("rifle_mark"):draw_arc(Vector2(0,-45),22,0,TAU,32,Color("e6b4ff"),2.5,true)
 if unit.kind!="champion":return
 var y=-Constants.CHAMP_ART_HEIGHT-90
 if unit.hero_key=="xinzhao" and unit.buffs.has("roster_attack"):_badge("Q • %d HITS • %.1fs" % [unit.buffs.roster_attack.hits,unit.buffs.roster_attack.time],y,Color("edc895"))
 elif unit.buffs.has("artillery"):_badge("ARTILLERY %d • %.1fs" % [unit.buffs.artillery.shots,unit.buffs.artillery.time],y,Color("8adfff"))
 elif unit.buffs.has("arcanopulse"):_badge("CHARGING • Q TO FIRE",y,Color("8adfff"))
 elif unit.buffs.has("parry"):_badge("PARRY %.1fs" % unit.buffs.parry.time,y,Color("b4d9ff"))

func _draw_deadeye() -> void:
 var charge=DeadeyeCue.channel(unit)
 var gold=Color("ffd176")
 if not charge.is_empty() and DeadeyeCue.visible(charge.target):
  _badge("DEADEYE • %.1fs" % (ceilf(charge.time*10)/10.),-Constants.CHAMP_ART_HEIGHT-70,gold)
  var direction=(charge.target.world_pos()-unit.world_pos()).normalized()
  var muzzle=Vector2(0,-28)+direction*22
  var end=charge.target.world_pos()-unit.world_pos()+Vector2(0,-28)
  draw_line(muzzle,end,Color(0.02,0.02,0.03,.8),3.5,true)
  draw_line(muzzle,end,Color(gold,.55+.3*sin(phase*18)),1.3,true)
  draw_circle(muzzle,6+charge.progress*4,Color(gold,.18))
  draw_arc(muzzle,10,phase*4,phase*4+TAU*charge.progress,32,gold,2,true)
  draw_circle(muzzle,2+charge.progress*2,Color("fff4d9"))
  draw_line(Vector2(-40,-Constants.CHAMP_ART_HEIGHT-62),Vector2(40,-Constants.CHAMP_ART_HEIGHT-62),Color(0,0,0,.9),5,true)
  draw_line(Vector2(-40,-Constants.CHAMP_ART_HEIGHT-62),Vector2(-40+80*charge.progress,-Constants.CHAMP_ART_HEIGHT-62),gold,3,true)
 var locks=DeadeyeCue.locks_on(unit)
 if locks.is_empty():return
 locks.sort_custom(func(a,b):return a.time<b.time)
 var lock=locks[0]
 var tint=Color("ff6e68") if is_instance_valid(GameState.player) and unit.team==GameState.player.team else gold
 var center=Vector2(0,-28)
 var radius=30-6*lock.progress
 draw_arc(center,radius,0,TAU,48,Color(0,0,0,.9),4,true)
 draw_arc(center,radius,-PI/2,-PI/2+TAU*(1-lock.progress),48,tint,2.5,true)
 for side in range(4):
  var d=Vector2.from_angle(side*PI/2+phase*.35)
  draw_line(center+d*(radius-5),center+d*(radius+5),tint,2,true)
 _badge("LOCKED • %.1fs" % (ceilf(lock.time*10)/10.),-Constants.CHAMP_ART_HEIGHT-(102 if not charge.is_empty() else 70),tint)
