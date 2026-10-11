extends Node
var failures=0
var checks=0
var game
func check(ok: bool,message: String) -> void:
 checks+=1
 if not ok:failures+=1;push_error("FAIL PACE: "+message)
func total_xp(c) -> float:
 var result=c.xp
 for lv in range(3,c.level):result+=Constants.xp_to_level(lv)
 return result
func _ready() -> void:
 Progression.persistent=false;Progression.allied_bots=false;Progression.difficulty=1;Progression.levels.clear();Progression.gear_equipped.clear()
 game=load("res://scripts/Main.gd").new();add_child(game);game.set_process(false);game._start_game("lux")
 var p=GameState.player;var enemy=GameState.champions[3];var off=GameState.champions[1]
 var money=p.gold
 game._tick_economy(.4);check(p.gold==money and p.xp==0.,"fractional income waits for full second")
 game._tick_economy(.6);check(p.gold==money+12 and p.xp==35.,"one second gives increased gold and passive XP")
 var xp=p.xp;game._tick_economy(3.2);check(p.gold==money+48 and p.xp==xp+105.,"catch-up accounts for all whole seconds")
 check(off.gold==1000 and off.xp==0.,"disabled bot earns no income")
 GameState.paused=true;money=p.gold;xp=p.xp;game._tick_economy(30.);check(p.gold==money and p.xp==xp,"paused match awards nothing");GameState.paused=false
 p.dead=true;game._tick_economy(1.);check(p.gold==money+12 and p.xp==xp,"dead hero gets gold but no passive XP");p.dead=false
 GameState.running=false;money=p.gold;game._tick_economy(20.);check(p.gold==money,"finished match awards nothing");GameState.running=true
 for kind in ["melee","caster","siege","super"]:
  var m=load("res://scripts/Minion.gd").new();game.world_root.add_child(m);m.setup(1,kind,p.world_pos(),1.);GameState.minions.append(m)
  var before=total_xp(p);money=p.gold;var cs=p.cs
  game._handle_death(p,m)
  check(p.gold==money+m.gold_val and m.gold_val==m.SPECS[kind].gold*3,"triple last-hit gold "+kind)
  check(is_equal_approx(total_xp(p)-before,m.xp_val*4.8*1.25),"quadruple soak with last-hit bonus "+kind)
  check(p.cs==cs+1,"CS preserved "+kind)
 # A large enemy kill crosses several levels, without losing augment milestones.
 enemy.level=25;var before=total_xp(p);money=p.gold
 game._handle_death(p,enemy)
 check(p.gold==money+1000,"hero kill awards 1000g")
 check(is_equal_approx(total_xp(p)-before,3100.),"hero kill XP scales with defeated level")
 check(game.lane_augments.pending.has(4) and game.lane_augments.pending.has(6),"multi-level rewards keep all draft milestones")
 game._handle_death(p,enemy);check(p.gold==money+1000,"duplicate kill cannot award currency twice")
 # Higher N still multiplies the same passive source reward exactly once.
 enemy.dead=false;enemy.level=3;enemy.xp=0.;enemy.difficulty_stats=Progression.scaling(99)
 var earned=total_xp(enemy);game._tick_economy(1.)
 check(is_equal_approx(total_xp(enemy)-earned,35.*Progression.scaling(99).experience),"enemy difficulty XP applies once to passive income")
 # Deterministic lane-income budget: all waves soaked, half last-hit, one kill/minute.
 # This measures progression, not whether any particular battle lasts ten minutes.
 p.level=3;p.xp=0.;p.gold=1000;p.skill_points=0;p.level_bonus.clear();p.skill_ranks=[1,1,1,0];p.position=Vector2(1400,270)
 for wave in range(37):
  game._tick_economy(16.)
  for index in range(7 if wave%3==2 else 6):
   var kind="melee" if index<3 else "caster" if index<6 else "siege"
   var m=load("res://scripts/Minion.gd").new();game.world_root.add_child(m);m.setup(1,kind,p.world_pos(),1.);GameState.minions.append(m)
   game._handle_death(p if index%2==wave%2 else null,m)
  if wave%4==0:
   game._respawn_champion(enemy);enemy.level=p.level;game._handle_death(p,enemy)
  for m in GameState.minions:m.queue_free()
  GameState.minions.clear()
  await get_tree().process_frame
 print("PACE ten-minute lane budget: level %d, %dg, %d CS" % [p.level,p.gold,p.cs])
 check(p.level>=35 and p.level<=65,"active ten-minute lane budget reaches veteran levels")
 check(p.gold>=24000,"ten-minute farm/kill budget supports full builds and stat consumables")
 var packet=LanSnapshot.encode();check(packet.champs[0].level==p.level and packet.champs[0].gold==p.gold,"fast progression uses replicated level/gold state")
 Progression.allied_bots=true;game.queue_free();GameState.reset();await get_tree().process_frame
 print("FAST PACE: %d checks, %d failures" % [checks,failures]);get_tree().quit(1 if failures else 0)
