extends SceneTree
var failures=0
func _initialize() -> void:call_deferred("run")
func check(value: bool,message: String) -> void:
 if not value:failures+=1;push_error("FAIL EXPORTED: "+message)
func run() -> void:
 await process_frame
 var steam=root.get_node("SteamSession")
 var lan=root.get_node("LanSession")
 var state=root.get_node("GameState")
 root.get_node("Progression").persistent=false
 check(steam.available,"exported release DLL initializes Spacewar")
 var manifest=JSON.parse_string(FileAccess.get_file_as_string("res://assets/animations/manifest.json"))
 check(manifest is Dictionary and not manifest.is_empty(),"animation manifest ships in PCK")
 var game=load("res://scripts/Main.gd").new();root.add_child(game)
 check(game.menu_page=="main","export boots to main menu")
 var updater=root.get_node("GameUpdates")
 check(FileAccess.file_exists("res://assets/updater/UpdateGame.ps1"),"exported updater helper ships")
 check(game.menu.find_child("UpdateAction",true,false)!=null,"exported menu shows update action")
 updater.auto_download=false;updater.check_latest()
 var check_deadline=Time.get_ticks_msec()+25000
 while updater.phase=="checking" and Time.get_ticks_msec()<check_deadline:await process_frame
 check(updater.checked and not updater.latest.is_empty(),"export checks real GitHub latest release")
 var profile=root.get_node("Progression");var loot=load("res://scripts/GearLoot.gd")
 var rng=RandomNumberGenerator.new();rng.seed=410
 var relic=loot.roll(25,rng,"export_test_relic")
 profile.gear_stash.append(relic)
 var slot="ring_1" if relic.slot=="ring" else relic.slot
 check(profile.equip_gear(relic.id,slot),"exported permanent relic equips")
 game._show_equipment();await process_frame;await process_frame
 check(game.menu.find_child("EquipmentScreen",true,false)!=null,"exported daily quest and equipment screen opens")
 check(load("res://scripts/GearArt.gd").icon_for(relic.base_id)!=null,"exported permanent gear art loads")
 var gear_art=load("res://scripts/GearArt.gd")
 for key in gear_art.KEYS:check(gear_art.icon_for(key)!=null and gear_art.icon_for(key).atlas.resource_path==gear_art.PATH,"exported dedicated equipment icon: "+key)
 check(relic.name.ends_with(loot.resolve_base(relic)[0]),"exported relic name matches depicted equipment")
 game._show_main_menu()
 check(steam.host_game()==OK,"export can request Steam lobby")
 var deadline=Time.get_ticks_msec()+27000
 while steam.operation=="host" and Time.get_ticks_msec()<deadline:await process_frame
 check(lan.is_host(),"release native Steam peer hosts real lobby")
 if lan.is_host():
  lan.ready_player("malphite",["flash","heal"],profile.bonuses())
  lan.start_match()
  await create_timer(1).timeout
  check(state.started and state.champions.size()==6,"exported ARAM runs with all six heroes")
  check(state.player.animator.texture()!=null,"exported action sprites load")
  check(state.player.mp_max>0,"exported Granite has a real mana pool")
  var hook_owner=state.player
  var expansion=load("res://scripts/ExpansionKits.gd")
  check(expansion.cast(hook_owner,"thresh_q",hook_owner.world_pos()+Vector2(200,0)),"export can produce a hook")
  var hook_state=load("res://scripts/LanSnapshot.gd").encode().projectiles.back()
  check(hook_state.source.kind=="champion" and hook_state.hook_chain and hook_state.damage_type=="magic","exported hook snapshot carries its caster and skill presentation")
  for stat in profile.bonuses():check(is_equal_approx(state.player.permanent_bonus.get(stat,0.),profile.bonuses()[stat]),"exported co-op starts with equipped stat: "+stat)
  check(load("res://assets/vfx/expansion-projectiles-v1.png")!=null,"exported new projectile sheet loads")
  var kit_art=load("res://scripts/KitEffectArt.gd")
  var roster12=load("res://scripts/RosterExpansion12.gd");var actions12=load("res://scripts/ActionSpriteArt.gd");var icons12=load("res://scripts/AbilityArt.gd")
  check(root.get_node("ChampionData").CHAMPIONS.size()==30,"export has all thirty heroes")
  var passives=load("res://scripts/HeroPassives.gd");var portraits=load("res://scripts/HeroArt.gd")
  for hero in root.get_node("ChampionData").CHAMPIONS:
   check(passives.DATA.has(hero),"exported passive metadata "+hero)
   var portrait=portraits.texture_for(hero)
   check(portrait.filter_clip and is_equal_approx(portrait.get_width(),portrait.get_height()),"exported square portrait "+hero)
  check(load("res://scripts/SteamSession.gd").PROTOCOL=="5","export uses passive/vision network protocol")
  var passive_snapshot=load("res://scripts/LanSnapshot.gd").encode().champs[0]
  check(passive_snapshot.has("passive_state") and passive_snapshot.vision_teams.size()==2,"export serializes passive counters and team visibility")
  check(root.get_node("ChampionData").CHAMPIONS.vayne.skills[1].kind=="passive","exported Vesper W stays passive")
  for hero in roster12.KEYS:
   for action in ["idle","run","attack","q","w","e","r","hit","death","recall"]:
    for frame in range(6):check(actions12.texture_for_frame("hero_"+hero,action,frame)!=null and actions12.region("hero_"+hero,action,frame).has_area(),"exported action "+hero+action+str(frame))
   for i in range(4):
    check(icons12.icon_for(hero,i)!=null,"exported new icon "+hero+str(i))
    var id=hero+"_"+["q","w","e","r"][i]
    check(kit_art.sheet(id)!=null and kit_art.region(id,3).has_area(),"exported new skill atlas "+id)
  var feedback_art=load("res://scripts/CombatFeedbackArt.gd")
  check(not game.sound_fx.announcer_clips.has("ally_slain") and not game.sound_fx.announcer_clips.has("victory_voice") and game.sound_fx.announcer_clips.values().all(func(clip):return clip.resource_path.begins_with("res://assets/audio/mobile-announcer-v1/")),"exported voice bank contains no TTS fallbacks")
  check(kit_art.sheet("veigar_e").resource_path.ends_with("vexel-ground-v2.png"),"exported Vexel uses corrected circular ground sheet")
  check(feedback_art.impact_texture()!=null and feedback_art.banner_texture()!=null,"exported impact and complete crest load")
  for tier in range(6):
   check(feedback_art.banner_texture(tier).resource_path.begins_with("res://assets/vfx/crests-v2/"),"exported separate complete crest loads")
  for hero in ["thresh","veigar","darius","malphite","morgana","vayne"]:
   for key in ["q","w","e","r"]:
    var id=hero+"_"+key
    check(kit_art.sheet(id)!=null and kit_art.region(id,3).has_area(),"exported dedicated skill atlas: "+id)
  root.get_node("Progression").smart_cast=false
  state.champions[3].global_position=state.player.world_pos()+Vector2(200,0)
  game._player_cast_skill(0)
  check(game.pending_skill==0,"exported normal cast enters targeting")
  var before=state.projectiles.size()
  var click=InputEventMouseButton.new();click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true
  click.position=game.get_canvas_transform()*state.champions[3].world_pos()
  game._unhandled_input(click)
  check(game.pending_skill==-1 and state.projectiles.size()==before+1,"exported normal cast confirms a real spell")
  check(root.get_node("ItemData").ITEMS.size()==76,"exported shop contains expanded tank and AD items")
  state.player.gold=10000
  check(state.player.try_buy_item("sunfire"),"exported tank item can be purchased")
  check(load("res://assets/ui/tank-ad-item-icons-v1.png")!=null,"exported new item art loads")
  state.player.gold=100000
  check(state.player.try_buy_item("training_hp") and state.player.consumable_counts.get("training_hp",0)==1,"exported stat consumable applies real match bonus")
  var gold=state.player.gold
  check(state.player.try_buy_item("training_hp") and state.player.gold==gold-10800,"exported repeat consumable uses increasing price")
  check(state.player.recall_duration==1.0,"exported recall uses one-second timer")
  var shop=game.hud.get_node("HudRoot").shop_panel
  shop.category="mage";shop.rebuild_catalog()
  check(shop.category_buttons.any(func(b):return b.get_meta("category")=="mage") and shop.grid.get_child_count()>=20,"exported Mage build filter lists complete mage options")
  check(load("res://assets/environment/frost-brush-v1.png")!=null,"exported painted brush asset loads")
  var crops=JSON.parse_string(FileAccess.get_file_as_string("res://assets/vfx/missile-crops-v1.json"))
  check(crops is Dictionary and crops.get("expansion",[]).size()==6,"exported projectile mapping metadata ships")
  check(game.lane_augments.AUGMENTS.size()==30,"exported game has expanded role upgrade pool")
  check(root.get_node("ItemData").upgrades_for("long_sword").has("maw"),"exported upgrade browser includes later recipe descendants")
  state.player.inventory[0]="long_sword"
  var ui=game.hud.get_node("HudRoot");ui.refresh(0)
  check(ui.kill_feed_frame.clip_contents,"exported kill feed clips to its bounds")
  game.announce_kill("penta_kill",state.player.team,state.player.hero.name)
  check(ui.kill_celebration.visible and ui.kill_celebration.row==4 and ui.kill_celebration.headline=="SAVAGE","exported Savage crest plays")
  check(game.sound_fx.announcer_voice.stream.resource_path.ends_with("mobile-announcer-v1/savage.wav"),"exported Savage recording plays")
  check(game.music.players.battle.stream is AudioStreamMP3 and game.music.players.battle.stream.loop,"exported supplied battle theme loops")
  ui.inv_slots[0].panel.mouse_entered.emit()
  check(root.get_node("ItemHover").panel!=null,"exported item hover renders an in-viewport tooltip")
  game.deal_damage(state.champions[3],state.player,state.player.hp+state.player.shield+100000,"exec")
  check(state.player.dead,"exported player death resolves safely")
  ui.inv_slots[0].panel.mouse_entered.emit()
  check(root.get_node("ItemHover").panel!=null,"exported item tooltip stays usable while dead")
  await create_timer(.2).timeout
  game._respawn_champion(state.player)
  check(not state.player.dead and state.player.hp==state.player.hp_max,"exported player respawns safely")
  var opponent=state.champions[3];var opponent_gold=opponent.gold
  opponent.deaths=10;game._respawn_champion(opponent);game._handle_death(state.player,opponent)
  check(opponent.last_comeback_gold==600 and opponent.gold==opponent_gold+600,"exported enemy death 11 grants comeback gold")
  state.player.level=18;state.player.xp=0.;state.player.skill_points=0
  for index in range(4):state.player.skill_ranks[index]=state.player.hero.skills[index].max
  state.player.grant_xp(root.get_node("Constants").xp_to_level(18))
  check(state.player.level==19 and state.player.level_bonus.get("bonus_ap",0.)==5. and state.player.skill_points==0,"exported level 19 grants veteran stats instead of skill points")
  game._end_game(0)
  check(profile.daily.claimed.size()>=2 and profile.last_drops.size()>=2,"exported match completion grants daily equipment rewards")
 lan.leave();game.queue_free();await process_frame
 print("STEAM EXPORT SMOKE: ",failures," failures")
 quit(1 if failures else 0)
