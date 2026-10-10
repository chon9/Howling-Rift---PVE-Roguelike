extends Node
var failures = 0
var role: String = "host"
var game
func check(value: bool,text: String) -> void:
 if not value: failures += 1; push_error("FAIL "+role+": "+text)
func until(predicate: Callable,seconds: float = 12) -> bool:
 var deadline = Time.get_ticks_msec()+int(seconds*1000)
 while not predicate.call() and Time.get_ticks_msec() < deadline:
  await get_tree().create_timer(0.05).timeout
 return predicate.call()
func _ready() -> void:
 role = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "host"
 GameState.reset()
 Progression.persistent = false
 Progression.levels.clear();Progression.gear_stash.clear();Progression.gear_equipped.clear();Progression.daily.clear()
 var gear_rng=RandomNumberGenerator.new();gear_rng.seed=17 if role=="host" else 28 if role=="client1" else 39
 for index in range(3):
  var relic=GearLoot.roll(5,gear_rng,role+"_relic_%d" % index);Progression.gear_stash.append(relic)
  Progression.equip_gear(relic.id,"ring_1" if relic.slot=="ring" else relic.slot)
 game = load("res://scripts/Main.gd").new()
 add_child(game)
 if role == "host":
  check(LanSession.host_game() == OK,"server starts")
  LanSession.ready_player("yasuo",["flash","ignite"],Progression.bonuses())
  if not await until(func(): return LanSession.players.size() == 3 and LanSession.can_start()):
   check(false,"three ready peers join"); get_tree().quit(1); return
  LanSession.start_match()
  check(GameState.champions.size() == 6 and GameState.player.hero_key == "yasuo","host starts shared ARAM")
  check(GameState.champions[1].owner_peer != 0 and not GameState.champions[1].is_bot and not GameState.champions[2].is_bot,"three humans own separate blue heroes")
  await until(func(): return GameState.time >= 3)
  for c in GameState.champions.slice(1,3): c.grant_xp(Constants.xp_to_level(3)); c.gold = 20000
  var lee = GameState.champions.filter(func(c): return c.hero_key == "leesin" and c.team == Constants.BLUE)[0]
  var marked = GameState.champions.filter(func(c): return c.hero_key == "zed" and c.team == Constants.BLUE)[0]
  marked.buffs.sonic_mark = {"time":4.0,"src":lee}
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://tests/34-lan-host.png")
  await until(func(): return GameState.time >= 6)
  for c in GameState.champions.slice(1,3): game._handle_death(GameState.champions[3],c)
  await until(func(): return GameState.time >= 9)
  for c in GameState.champions.slice(1,3):
   check(c.inventory.has("dagger"),"guest purchase reached host")
   check(c.consumable_counts.get("training_ad",0)==2 and c.consumable_bonus.get("bonus_ad",0)==50,"guest stacked consumables reached host")
   check(c.skill_ranks[0] == 2,"guest skill upgrade reached host")
   check(not c.run_bonus.is_empty(),"guest draft applied only to owned hero")
  game._end_game(Constants.BLUE)
  await get_tree().create_timer(1.5).timeout
  check(Progression.last_reward > 0,"host earns match credits")
  check(Progression.daily.claimed.size()>=2 and Progression.gear_stash.size()>=5,"host saves daily quest gear drops")
  check(GameState.champions[1].is_bot and GameState.champions[2].is_bot,"disconnected guests hand control to AI")
 else:
  check(LanSession.join_game("127.0.0.1") == OK,"guest connects")
  if not await until(func(): return LanSession.players.has(multiplayer.get_unique_id())):
   check(false,"lobby sync arrives"); get_tree().quit(1); return
  LanSession.ready_player("leesin" if role == "client1" else "zed",["heal","ghost"],Progression.bonuses())
  if not await until(func(): return GameState.started):
   check(false,"shared match begins"); get_tree().quit(1); return
  var p = GameState.player
  for stat in Progression.bonuses():check(is_equal_approx(p.permanent_bonus.get(stat,0.),Progression.bonuses()[stat]),"guest equipment stat replicated: "+stat)
  check(p.owner_peer == multiplayer.get_unique_id() and p.hero_key == ("leesin" if role == "client1" else "zed"),"guest controls chosen hero")
  game._issue_player_order({"type":"smart","point":Vector2(600,270)})
  check(await until(func(): return p.animator.pose().action == "run",2),"guest sees the replicated articulated run cycle")
  check(await until(func(): return p.world_pos().x >= 540,5),"movement replicated from server")
  p.try_cast_skill(1,p.world_pos()+Vector2(60,0))
  check(await until(func(): return p.skill_cds[1] > 0,2),"skill executes on host")
  check(p.anim_action == "w","guest receives the authoritative W cast animation")
  game.cast_summoner(p,1)
  check(await until(func(): return p.summoner_cds[1] > 0,2),"chosen summoner executes on host")
  check(await until(func(): return game.lane_augments.pending == [4],4),"own level-up draft replicated")
  check(game.lane_augments.choices.size() == 3,"guest receives three stable draft options")
  if role == "client1":
   check(await until(func(): return not NewHeroKits.recast_info(p,0).is_empty(),1),"Q marked-target countdown replicated to guest")
   var mark = NewHeroKits.recast_info(p,0)
   check(not mark.is_empty() and mark.time>0 and mark.time<=4.0,"guest Q recast carries the authoritative remaining time")
  var rolled={}
  if not game.lane_augments.choices.is_empty():
   var index=game.lane_augments.choices[0]
   rolled=game.lane_augments.offers.get(index,{}).get("stats",{}).duplicate()
   check(not rolled.is_empty(),"host rolls exact stat values for guest choices")
   game.lane_augments.choose(index)
  p.try_level_skill(0)
  check(await until(func(): return p.skill_ranks[0] == 2 and game.lane_augments.picked.size() == 1,2),"rank and draft confirmed by server")
  for stat in rolled:check(is_equal_approx(p.run_bonus.get(stat,0.),rolled[stat]),"guest receives the exact offered stat magnitude: "+stat)
  if DisplayServer.get_name() != "headless":
   await RenderingServer.frame_post_draw
   get_viewport().get_texture().get_image().save_png("res://tests/35-lan-"+role+".png")
  check(await until(func(): return p.dead,5),"death replicated")
  check(game.world_root.get_children().any(func(n):return n is AnimatedCorpse),"guest renders animated corpses when death is replicated")
  check(await until(func(): return game.sound_fx.announcement_counts.get("double_kill",0)>0,1),"double-kill voice announcement replicated")
  p.try_buy_item("dagger")
  check(await until(func(): return p.inventory.has("dagger"),2),"guest shops while dead")
  p.try_buy_item("training_ad")
  check(await until(func():return p.consumable_counts.get("training_ad",0)==1,1),"guest receives first consumed stat bonus")
  p.try_buy_item("training_ad")
  check(await until(func():return p.consumable_counts.get("training_ad",0)==2 and p.consumable_bonus.get("bonus_ad",0)==50,1),"guest repeat purchase uses increasing price and replicated stats")
  check(p.gold<1200 and not p.inventory.has("training_ad"),"guest consumables spend gold without a slot")
  var cooldown = p.summoner_cds[1]
  await get_tree().create_timer(0.4).timeout
  check(p.summoner_cds[1] < cooldown,"cooldown continues while dead")
  check(await until(func(): return not GameState.running,6),"shared match result arrives")
  check(Progression.last_reward > 0,"guest earns permanent completion credits")
  check(Progression.daily.claimed.size()>=2 and Progression.gear_stash.size()>=5,"guest receives daily quest drops after authoritative result")
 print("LAN "+role+": "+str(failures)+" failures")
 await get_tree().create_timer(.2).timeout
 LanSession.leave()
 game.queue_free()
 GameState.reset()
 await get_tree().process_frame
 await get_tree().process_frame
 get_tree().quit(1 if failures else 0)
