extends Node
# Host runs all combat and validates commands; guests display replicated state.
const PORT = 24567
var network_port: int = PORT
var active: bool = false
var transport: String = "lan"
var main = null
var status: String = ""
var players: Dictionary = {}
var draft_states: Dictionary = {}
var replica_minions: Dictionary = {}
var replica_projectiles: Dictionary = {}
var replica_aoes: Dictionary = {}
var positions: Dictionary = {}
var state_timer: float = 0.0
var last_state_time: float = -1.0
var match_started: bool = false
var last_commands: Dictionary = {}
var pending_player: Dictionary = {}
func _ready() -> void:
 var args = OS.get_cmdline_user_args()
 var override_index = args.find("--test-lan-port")
 if override_index >= 0 and override_index+1 < args.size(): network_port = clampi(args[override_index+1].to_int(),1024,65535)
 multiplayer.peer_disconnected.connect(_peer_left)
 multiplayer.connected_to_server.connect(_connected)
 multiplayer.connection_failed.connect(_failed)
 multiplayer.server_disconnected.connect(_server_left)
 multiplayer.peer_connected.connect(_peer_connected)
func is_host() -> bool: return active and multiplayer.is_server()
func is_client() -> bool: return active and not multiplayer.is_server()
func is_local(c) -> bool: return is_client() and c == GameState.player
func leave() -> void:
 active = false
 var previous_peer = multiplayer.multiplayer_peer
 var was_steam = transport == "steam"
 # Replacing the transport releases it after SceneMultiplayer detaches.
 # Explicit ENet close can resend queued packets to already disconnected peers.
 multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
 # Steam listen sockets must close even when another object retains the peer.
 if was_steam: previous_peer.close()
 SteamSession.leave()
 transport = "lan"
 players.clear(); draft_states.clear(); positions.clear()
 replica_minions.clear(); replica_projectiles.clear(); replica_aoes.clear()
 match_started = false
 state_timer = 0; last_state_time = -1
 pending_player.clear()
 last_commands.clear()
func attach_steam(peer: MultiplayerPeer, host: bool) -> void:
 transport = "steam"
 multiplayer.multiplayer_peer = peer
 active = true
 if host:
  players[1] = {"peer":1,"name":str(SteamSession.api.getPersonaName()).left(40),"hero":"ashe","spells":["flash","ignite"],"bonuses":Progression.bonuses(),"ready":false}
func _peer_connected(peer: int) -> void:
 if is_host() and transport == "steam" and (players.size() >= 3 or not SteamSession.peer_allowed(peer)):
  multiplayer.multiplayer_peer.disconnect_peer(peer)
func host_game() -> Error:
 leave()
 var peer = ENetMultiplayerPeer.new()
 var error = peer.create_server(network_port,2,3)
 if error != OK: return error
 multiplayer.multiplayer_peer = peer
 active = true
 players[1] = {"peer":1,"name":"Host","hero":"ashe","spells":["flash","ignite"],"bonuses":Progression.bonuses(),"ready":false}
 var addresses: PackedStringArray = []
 for address in IP.get_local_addresses():
  if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."): addresses.append(address)
 status = "HOST • UDP %d\nLAN IP: %s\nChoose a hero, then wait for your friends." % [network_port,", ".join(addresses) if not addresses.is_empty() else "127.0.0.1"]
 return OK
func join_game(address: String) -> Error:
 if address.is_empty() or not address.is_valid_ip_address(): return ERR_INVALID_PARAMETER
 leave()
 var peer = ENetMultiplayerPeer.new()
 var error = peer.create_client(address,network_port,3)
 if error != OK: return error
 multiplayer.multiplayer_peer = peer
 active = true
 status = "Connecting to %s..." % address
 return OK
func _connected() -> void:
 if not active: return
 if transport == "steam": SteamSession.connected()
 status = "Connected • choose a hero and press Ready."
 if pending_player.is_empty(): _submit_player.rpc_id(1,"ashe",["flash","ignite"],Progression.bonuses(),false)
 else: _submit_player.rpc_id(1,pending_player.hero,pending_player.spells,pending_player.bonuses,pending_player.ready)
 refresh_lobby()
func _failed() -> void:
 if not active: return
 var steam = transport == "steam"
 leave()
 status = "Steam connection failed. Check Steam is online and ask the host to create a new lobby." if steam else "Connection failed. Check the host's IP and that both PCs are on the same LAN."
 if is_instance_valid(main): main._show_main_menu()
func _server_left() -> void:
 if not active: return
 leave()
 status = "Host disconnected. The co-op session ended."
 if is_instance_valid(main): main._return_to_main_menu()
func _peer_left(peer: int) -> void:
 if not is_host(): return
 players.erase(peer)
 if GameState.started:
  for c in GameState.champions:
   if c.owner_peer == peer:
    c.owner_peer = 0
    c.is_bot = true
    c.stop_actions()
    c.char_name += " (AI)"
    c.name_label.text = c.char_name
 else: _lobby.rpc(players)
 refresh_lobby()
func sanitize_bonuses(bonuses: Dictionary) -> Dictionary:
 var result = {}
 for field in GearLoot.STAT_NAMES:
  var value = float(bonuses.get(field,0))
  if is_finite(value): result[field] = clampf(value,0,0.615 if field == "bonus_ms" else 5 if field == "bonus_as" else 0.4 if field == "bonus_cdr" else 1.0 if field in ["bonus_crit","bonus_lifesteal"] else 10000)
 return result
@rpc("any_peer","call_remote","reliable",1)
func _submit_player(hero: String, spells: Array, bonuses: Dictionary, ready: bool) -> void:
 if not is_host() or match_started or not ChampionData.CHAMPIONS.has(hero): return
 var peer = multiplayer.get_remote_sender_id()
 if peer <= 1 or not multiplayer.get_peers().has(peer): return
 if transport == "steam" and not SteamSession.peer_allowed(peer): return
 if not players.has(peer) and players.size() >= 3: multiplayer.multiplayer_peer.disconnect_peer(peer); return
 if not valid_spells(spells): return
 players[peer] = {"peer":peer,"name":"Player %d" % (players.size()+1 if not players.has(peer) else players.keys().find(peer)+1),"hero":hero,"spells":spells.duplicate(),"bonuses":sanitize_bonuses(bonuses),"ready":ready}
 if transport == "steam": players[peer].name = SteamSession.peer_name(peer)
 _lobby.rpc(players)
 refresh_lobby()
func valid_spells(spells: Array) -> bool:
 return spells.size() == 2 and spells[0] != spells[1] and SummonerData.SPELLS.has(spells[0]) and SummonerData.SPELLS.has(spells[1])
func ready_player(hero: String, spells: Array, bonuses: Dictionary, ready: bool = true) -> void:
 if not active: return
 pending_player = {"hero":hero,"spells":spells.duplicate(),"bonuses":bonuses.duplicate(),"ready":ready}
 if not ChampionData.CHAMPIONS.has(hero) or not valid_spells(spells): return
 if is_host():
  players[1].hero = hero
  players[1].spells = spells.duplicate()
  players[1].bonuses = bonuses.duplicate()
  players[1].ready = ready
  _lobby.rpc(players)
 elif multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
  _submit_player.rpc_id(1,hero,spells,bonuses,ready)
func can_start() -> bool:
 if match_started: return false
 if not is_host() or players.is_empty(): return false
 for config in players.values():
  if not config.ready: return false
 return true
@rpc("authority","call_remote","reliable",1)
func _lobby(configs: Dictionary) -> void:
 players = configs.duplicate(true)
 refresh_lobby()
func refresh_lobby() -> void:
 if is_instance_valid(main): main._refresh_lobby()
func start_match() -> void:
 if not can_start(): return
 var configs: Array = []
 var peers = players.keys()
 peers.sort()
 for peer in peers: configs.append(players[peer].duplicate(true))
 var reds = ChampionData.CHAMPIONS.keys()
 reds.shuffle()
 var blues: Array = []
 for player in configs: blues.append(player.hero)
 for hero in reds:
  if blues.size() >= 3: break
  if not blues.has(hero): blues.append(hero)
 var config = {"players":configs,"blue":blues,"red":MatchRoster.enemy_team(blues),"stage":Progression.difficulty}
 match_started = true
 multiplayer.multiplayer_peer.refuse_new_connections = true
 if transport == "steam": SteamSession.lock_match()
 _begin_match.rpc(config)
@rpc("authority","call_local","reliable",1)
func _begin_match(config: Dictionary) -> void:
 match_started = true
 draft_states.clear(); last_state_time = -1
 if is_instance_valid(main): main._start_network_match(config)
func send_command(kind: String, data: Dictionary = {}) -> void:
 if not is_client() or not GameState.started: return
 _command.rpc_id(1,kind,data)
@rpc("any_peer","call_remote","reliable",1)
func _command(kind: String, data: Dictionary) -> void:
 if not is_host() or not GameState.started or not GameState.running: return
 var sender = multiplayer.get_remote_sender_id()
 var c = null
 for hero in GameState.champions:
  if hero.owner_peer == sender and sender > 1: c = hero; break
 if c == null: return
 var now = Time.get_ticks_msec()
 var stamp = str(sender)+kind
 if now-int(last_commands.get(stamp,0)) < 15: return
 last_commands[stamp] = now
 execute(c,kind,data)
func execute(c, kind: String, data: Dictionary) -> void:
 var raw_point = data.get("point",c.world_pos())
 if not raw_point is Vector2: return
 var point: Vector2 = raw_point
 if not point.is_finite(): return
 var index = int(data.get("index",-1))
 match kind:
  "order":
   if data.get("type") in ["smart","amove"]: main._issue_champion_order(c,{"type":data.type,"point":point})
  "skill":
   if index >= 0 and index < 4: c.try_cast_skill(index,point)
  "summoner":
   if index >= 0 and index < 2:
    var previous = main.mouse_world
    main.mouse_world = point
    main.cast_summoner(c,index)
    main.mouse_world = previous
  "rank":
   if index >= 0 and index < 4: c.try_level_skill(index)
  "recall": c.start_recall()
  "stop": c.stop_actions()
  "buy": c.try_buy_item(str(data.get("id","")))
  "sell": c.try_sell_item(index)
  "draft": choose_draft(c,index)
  "permanent": return # Starting bonuses are captured by lobby configuration.
func award_draft(c) -> void:
 if not main.lane_augments.MILESTONES.has(c.level): return
 if not draft_states.has(c.owner_peer): draft_states[c.owner_peer] = {"pending":[],"choices":[],"picked":[],"awarded":[],"offers":{}}
 var draft = draft_states[c.owner_peer]
 if draft.awarded.has(c.level): return
 draft.awarded.append(c.level)
 draft.pending.append(c.level)
 fill_choices(draft,c)
func fill_choices(draft: Dictionary,c) -> void:
 if draft.pending.is_empty() or not draft.choices.is_empty(): return
 draft.choices = main.lane_augments.roll_choices(c)
 draft.offers = {}
 for index in draft.choices:draft.offers[index]=main.lane_augments.roll_offer(index,int(draft.pending[0]))
func choose_draft(c,index: int) -> void:
 var draft = draft_states.get(c.owner_peer,{})
 if draft.is_empty() or draft.pending.is_empty() or not draft.choices.has(index): return
 main.lane_augments.apply_augment(c,index,draft.offers.get(index,{}))
 draft.picked.append(main.lane_augments.AUGMENTS[index].name)
 draft.pending.pop_front()
 draft.choices.clear()
 fill_choices(draft,c)
func replicate(delta: float) -> void:
 if not is_host() or not GameState.started or not GameState.running: return
 state_timer += delta
 if state_timer < 0.05: return
 state_timer = 0
 var packet = LanSnapshot.encode()
 for peer in multiplayer.get_peers():
  var state = packet.duplicate()
  state.draft = draft_states.get(peer,{"pending":[],"choices":[],"picked":[]})
  _state.rpc_id(peer,var_to_bytes(state).compress(FileAccess.COMPRESSION_DEFLATE))
@rpc("authority","call_remote","reliable",0)
func _state(compressed: PackedByteArray) -> void:
 if not is_client() or not GameState.started: return
 var packet = bytes_to_var(compressed.decompress_dynamic(4*1024*1024,FileAccess.COMPRESSION_DEFLATE))
 if not packet is Dictionary or packet.time < last_state_time: return
 last_state_time = packet.time
 LanSnapshot.apply(packet,self)
func _process(delta: float) -> void:
 if not is_client() or not GameState.started: return
 for c in GameState.champions:
  if c.hit_flash>0:
   c.hit_flash=maxf(0.,c.hit_flash-delta);c.queue_redraw()
 for node in positions.keys():
  if not is_instance_valid(node): positions.erase(node); continue
  node.global_position = node.global_position.lerp(positions[node],1-exp(-delta*22))
func send_effect(kind: String, actor, point: Vector2, data: Dictionary = {}) -> void:
 if not is_host() or not GameState.started or not GameState.running: return
 _effect.rpc(kind,GameState.champions.find(actor),point,data)
@rpc("authority","call_remote","unreliable",2)
func _effect(kind: String, actor_index: int, point: Vector2, data: Dictionary) -> void:
 if not is_client() or not GameState.started or not is_instance_valid(main): return
 var actor = GameState.champions[actor_index] if actor_index >= 0 and actor_index < GameState.champions.size() else null
 match kind:
  "announce": main.announce_kill(data.event,int(data.team),str(data.hero),actor)
  "sound": main.play_sfx(data.event,actor)
  "melee":
   if actor != null: main.spawn_melee_strike(actor,point,data.get("light_hit",false))
  "burst":
   if actor != null: main.spawn_spell_burst(actor,point,data.radius)
  "beam":
   if actor != null: main.spawn_beam(actor,data.direction,data.length,data.width,0,data.color)
  "minion_hit": main.spawn_minion_hit(point)
  "impact": main.spawn_impact(point,data.color,data.size)
  "hero_impact": main.spawn_hero_impact(point,int(data.row),float(data.radius),float(data.angle),actor)
  "text": main.floating_text(point,data.text,data.color,data.big)
  "kill":
   var victim = GameState.champions[data.victim]
   main.hud.get_node("HudRoot").log_kill(actor,victim)
func finish(winner: int) -> void:
 if is_host(): _finish.rpc(winner,LanSnapshot.encode())
@rpc("authority","call_remote","reliable",1)
func _finish(winner: int, packet: Dictionary) -> void:
 if not is_client() or not GameState.started: return
 last_state_time = packet.time
 LanSnapshot.apply(packet,self)
 main._end_game(winner)
