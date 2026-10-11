extends Node2D
# Read only presentation. All durations come from host gameplay / replicated buffs.
var unit
var phase: float = 0.0
var stun_remaining: float = 0.0
var ignite_remaining: float = 0.0
var silence_remaining: float = 0.0
var shield_amount: float = 0.0
var shield_pulse: float = 0.0
var heal_remaining: float = 0.0
var previous_hp: float = -1.0
var previous_hp_max: float = -1.0
var statuses: Array = []
var primary_status: Dictionary = {}
var fire_texture: Texture2D
var font: Font = WorldTextFont.get_font()
var badge_boxes: Dictionary = {}

func _ready() -> void:
 z_index = Constants.Z_FX-Constants.Z_UNITS
 texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
 fire_texture = StatusArt.texture("burn")
 refresh()

func refresh() -> void:
 if not is_instance_valid(unit):return
 stun_remaining=maxf(0.,unit.stun) if not unit.dead else 0.
 ignite_remaining=maxf(0.,float(unit.buffs.get("ignite",{}).get("time",0.))) if not unit.dead else 0.
 silence_remaining=maxf(0.,float(unit.buffs.get("silence",{}).get("time",0.))) if not unit.dead else 0.
 var next_shield=maxf(0.,unit.shield) if unit.kind=="champion" and not unit.dead else 0.
 if next_shield!=shield_amount:shield_pulse=.3 if next_shield>shield_amount else .18
 shield_amount=next_shield
 if not unit.dead and previous_hp>=0 and is_equal_approx(previous_hp_max,unit.hp_max) and unit.hp-previous_hp>=maxf(1.,unit.hp_max*.005):heal_remaining=.7
 previous_hp=unit.hp;previous_hp_max=unit.hp_max
 if unit.dead:heal_remaining=0.
 statuses=StatusArt.collect(unit)
 if heal_remaining>0:statuses.append({"id":"heal","label":"HEALING","time":heal_remaining,"stacks":0,"detail":"Health restored."})
 primary_status={}
 for status in statuses:
  if status.id in ["airborne","stun","silence","root"]:primary_status=status;break
 if primary_status.is_empty() and ignite_remaining>0:
  primary_status={"id":"burn","label":"IGNITE","time":ignite_remaining}
 visible=not unit.dead and (not statuses.is_empty() or not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty() or ["artillery","arcanopulse","parry","roster_attack"].any(func(k):return unit.buffs.has(k)))
 queue_redraw()

func _process(delta: float) -> void:
 if not GameState.paused:
  phase+=delta
  shield_pulse=maxf(0.,shield_pulse-delta)
  heal_remaining=maxf(0.,heal_remaining-delta)
 refresh()

func fire_frame() -> Rect2:return StatusArt.frame_rect("burn",phase)

func _badge(text: String,y: float,color: Color,_spiral: bool=false) -> void:
 var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16
 draw_style_box(_background(color),Rect2(-width/2,y-17,width,23))
 draw_string_outline(font,Vector2(-width/2+8,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,1,Color.BLACK)
 draw_string(font,Vector2(-width/2+8,y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,color.lightened(.35))
 draw_line(Vector2(-width/2,y+5),Vector2(width/2,y+5),color,1.5,true)

func _background(color: Color) -> StyleBoxFlat:
 if badge_boxes.has(color):return badge_boxes[color]
 var box=StyleBoxFlat.new();box.bg_color=Color(.025,.035,.055,.94);box.border_color=Color(color,.8)
 box.set_border_width_all(1);box.set_corner_radius_all(3);badge_boxes[color]=box
 return box

func _sprite(id: String,rect: Rect2,alpha: float=1.) -> void:
 draw_texture_rect_region(StatusArt.texture(id),rect,StatusArt.frame_rect(id,phase),Color(1,1,1,alpha))

func overhead_statuses() -> Array:
 # One icon per family, CC first. Full named buffs remain available in the HUD.
 var result=[];var seen={}
 if not primary_status.is_empty():seen[primary_status.id]=true
 for status in statuses:
  if unit!=GameState.player and status.id in ["haste","empower","heal","guard"]:continue
  if not seen.has(status.id):result.append(status);seen[status.id]=true
 return result

func _draw() -> void:
 if not is_instance_valid(unit) or unit.dead:return
 _draw_deadeye();_draw_roster_status()
 var hero=unit.kind=="champion"
 var height=Constants.CHAMP_ART_HEIGHT if hero else unit.size*2.7
 var head_y=-height-56. if hero else unit.art_rect().position.y-24.
 var lift=HeroControl.lift(unit)
 if not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty():head_y-=40.
 if shield_amount>0:_sprite("shield",Rect2(-height*.66,-height*1.12-lift,height*1.32,height*1.32),.42+shield_pulse*.5)
 if statuses.any(func(status):return status.id=="guard"):_sprite("guard",Rect2(-height*.69,-height*1.15-lift,height*1.38,height*1.38),.45)
 if statuses.any(func(status):return status.id=="burn"):
  # Flames stay at the body edges; they do not obscure the torso or health bar.
  for side in [-1.,1.]:_sprite("burn",Rect2(side*height*.32-height*.18,-height*.45-lift,height*.36,height*.48),.75)
 if not primary_status.is_empty():
  var text=primary_status.label+" %.1fs" % (ceilf(primary_status.time*10.)/10.)
  var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+16
  _badge(text,head_y-lift,StatusArt.color(primary_status.id))
  _sprite(primary_status.id,Rect2(-width/2-29,head_y-24-lift,28,28))
 var items=overhead_statuses();var limit=2 if hero else 1;var count=mini(items.size(),limit)
 var row_y=head_y-34.-lift if not primary_status.is_empty() else head_y-22.-lift
 # Avoid stacking status icons onto Deadeye/channel captions.
 if not DeadeyeCue.channel(unit).is_empty() or not DeadeyeCue.locks_on(unit).is_empty() or unit.buffs.has("artillery") or unit.buffs.has("arcanopulse") or unit.buffs.has("parry") or unit.buffs.has("roster_attack"):row_y-=48.
 for i in range(count):
  var status=items[i];var x=(float(i)-(count-1)*.5)*29.
  draw_circle(Vector2(x,row_y+12),13,Color(.02,.035,.06,.9))
  _sprite(status.id,Rect2(x-12,row_y,24,24))
  var text=""
  if status.stacks>0:text="x%d" % status.stacks
  var width=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,9).x
  draw_string_outline(font,Vector2(x-width/2,row_y+30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,2,Color.BLACK)
  draw_string(font,Vector2(x-width/2,row_y+30),text,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color.WHITE)
 if items.size()>limit:draw_string(font,Vector2(count*14.5+3,row_y+17),"+%d" % (items.size()-limit),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color.WHITE)

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
