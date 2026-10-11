class_name RiftMenus
extends RefCounted
static func label(text: String, font: int = 24) -> Label:
 var item = Label.new()
 item.text = text
 item.add_theme_font_size_override("font_size",font)
 item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 return item
static func button(text: String, action: Callable) -> Button:
 var item = Button.new()
 item.text = text
 item.custom_minimum_size = Vector2(520,62)
 item.add_theme_font_size_override("font_size",26)
 item.focus_mode = Control.FOCUS_NONE
 item.pressed.connect(action)
 return item
static func backdrop(game, page: String) -> Control:
 if is_instance_valid(game.menu):
  game.remove_child(game.menu)
  game.menu.queue_free()
 game.menu = CanvasLayer.new()
 game.menu.name = "Menu"
 game.menu.layer = 20
 game.add_child(game.menu)
 game.menu_page = page
 var root = ColorRect.new()
 root.name = page.capitalize()
 root.color = Color("08121f")
 root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 game.menu.add_child(root)
 var art = TextureRect.new()
 art.texture = preload("res://assets/environment/rift-chasm.png")
 art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
 art.modulate = Color(0.35,0.4,0.5,0.55)
 art.mouse_filter = Control.MOUSE_FILTER_IGNORE
 root.add_child(art)
 return root
static func centered(root: Control, top: float = 180) -> VBoxContainer:
 var panel = VBoxContainer.new()
 panel.anchor_left = 0.5; panel.anchor_right = 0.5
 panel.offset_left = -260; panel.offset_right = 260
 panel.offset_top = top
 panel.add_theme_constant_override("separation",18)
 root.add_child(panel)
 return panel
static func start(game) -> void:
 var root=backdrop(game,"main")
 var screen=load("res://scripts/GoldenMainMenu.gd").new()
 screen.game=game
 root.add_child(screen)
static func lobby(game) -> void:
 if LanSession.is_pvp():pvp_lobby(game);return
 var root = backdrop(game,"lobby")
 var panel = centered(root,85)
 panel.add_theme_constant_override("separation",12)
 panel.add_child(label("STEAM CO-OP" if LanSession.transport=="steam" else "LAN CO-OP",48))
 panel.add_child(label("Up to three players on the blue team",22))
 if LanSession.is_host():
  difficulty_picker(panel)
  bot_picker(panel)
 else: panel.add_child(label("The host chooses N1–N99 before starting.",20))
 game.menu_status = label("",20)
 game.menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 game.menu_status.custom_minimum_size = Vector2(520,80)
 panel.add_child(game.menu_status)
 game.lobby_roster = label("",26)
 game.lobby_roster.custom_minimum_size.y = 120
 panel.add_child(game.lobby_roster)
 panel.add_child(button("CHOOSE HERO & SUMMONERS",func(): game._show_menu()))
 game.lobby_start = button("START CO-OP MATCH",func(): LanSession.start_match())
 game.lobby_start.visible = LanSession.is_host()
 panel.add_child(game.lobby_start)
 if LanSession.transport=="steam":
  var row=HBoxContainer.new();row.add_theme_constant_override("separation",12)
  var invite=button("INVITE FRIENDS",func():SteamSession.invite_friends())
  invite.custom_minimum_size.x=254;invite.add_theme_font_size_override("font_size",21)
  row.add_child(invite)
  var copy=button("COPY LOBBY CODE",func():DisplayServer.clipboard_set(str(SteamSession.lobby_id)))
  copy.custom_minimum_size.x=254;copy.add_theme_font_size_override("font_size",21)
  row.add_child(copy);panel.add_child(row)
 panel.add_child(button("LEAVE LOBBY",func(): LanSession.leave(); game._show_main_menu()))
 game._refresh_lobby()
static func pause(game, root: Control) -> void:
 var panel = centered(root,170)
 panel.add_child(label("MATCH MENU",46))
 panel.add_child(label("The multiplayer match continues while menus are open" if LanSession.active else "MATCH PAUSED",20))
 panel.add_child(button("RESUME [ESC]",func(): game.toggle_in_game_menu()))
 panel.add_child(button("SETTINGS" if GameState.is_pvp() else "PERMANENT UPGRADES / SETTINGS",func(): game._show_pause_upgrades()))
 panel.add_child(label("PVP • Equal starting stats • Level-up builds enabled" if GameState.is_pvp() else "N%d • %s\nDifficulty locked until the next game" % [GameState.difficulty,Progression.reward_preview(GameState.difficulty)],20))
 panel.add_child(button("RETURN TO MAIN MENU",func(): game._request_return()))
 panel.add_child(button("QUIT GAME",func(): game._request_quit()))
 panel.add_child(label("PvP rules are locked for this match." if GameState.is_pvp() else "The host chooses difficulty before a co-op match." if LanSession.active else "Permanent progress stays saved between matches.",20))

static func difficulty_picker(panel: VBoxContainer) -> void:
 var row = HBoxContainer.new()
 row.alignment = BoxContainer.ALIGNMENT_CENTER
 row.add_theme_constant_override("separation",16)
 panel.add_child(row)
 row.add_child(label("DIFFICULTY  N",24))
 var stage = SpinBox.new()
 stage.name = "PreGameDifficulty"
 stage.min_value = 1; stage.max_value = 99; stage.step = 1
 stage.value = Progression.difficulty
 stage.custom_minimum_size = Vector2(140,48)
 stage.add_theme_font_size_override("font_size",24)
 stage.get_line_edit().add_theme_font_size_override("font_size",24)
 row.add_child(stage)
 var preview = label(Progression.reward_preview(Progression.difficulty),20)
 preview.add_theme_color_override("font_color",Color("ecd18b"))
 panel.add_child(preview)
 stage.value_changed.connect(func(value):
  if GameState.started or LanSession.is_client(): return
  Progression.difficulty = clampi(int(value),1,99)
  Progression.save_profile()
  preview.text = Progression.reward_preview(Progression.difficulty))

static func bot_picker(parent: Control) -> CheckButton:
 var toggle = CheckButton.new()
 toggle.name = "AlliedBots"
 toggle.text = "FILL ALLIED SLOTS WITH AI"
 toggle.button_pressed = Progression.allied_bots
 toggle.add_theme_font_size_override("font_size",18)
 toggle.tooltip_text = "Choose before starting. Off: play solo or with human co-op teammates against three enemy heroes. Allied minions remain. Disconnected players are not replaced by bots. The host chooses this rule for everyone."
 toggle.toggled.connect(func(enabled): Progression.allied_bots = enabled; Progression.save_profile())
 parent.add_child(toggle)
 return toggle

static func pvp(game) -> void:
 var root=backdrop(game,"pvp");var panel=centered(root,125)
 panel.add_child(label("PVP ARAM",48))
 panel.add_child(label("Equal starting stats • Defeat the enemy throne",20))
 var size=OptionButton.new();size.name="PvpRoomSize"
 for value in ["1v1","2v2","3v3"]:size.add_item(value)
 size.select(2);size.custom_minimum_size=Vector2(520,50);size.add_theme_font_size_override("font_size",24);panel.add_child(size)
 var fill=CheckButton.new();fill.name="PvpFillBots";fill.text="FILL EMPTY SLOTS WITH AI";fill.button_pressed=true
 fill.add_theme_font_size_override("font_size",22);panel.add_child(fill)
 panel.add_child(button("HOST STEAM PVP",func():
  var error=SteamSession.host_game("pvp",size.selected+1,fill.button_pressed)
  if error!=OK:game.menu_status.text=SteamSession.status if error==ERR_UNAVAILABLE else error_string(error)))
 panel.add_child(button("HOST LAN PVP",func():
  var error=LanSession.host_game("pvp",size.selected+1,fill.button_pressed)
  if error==OK:game._show_lobby()
  else:game.menu_status.text=error_string(error)))
 panel.add_child(button("JOIN STEAM ROOM",func():SteamLobbyMenu.show_browser(game)))
 var row=HBoxContainer.new();var address=LineEdit.new();address.name="PvpLanAddress";address.placeholder_text="Host's LAN IP";address.text=game.last_lan_address
 address.custom_minimum_size=Vector2(310,54);address.add_theme_font_size_override("font_size",22);row.add_child(address)
 var join=button("JOIN LAN",func():
  game.last_lan_address=address.text.strip_edges()
  var error=LanSession.join_game(game.last_lan_address)
  if error==OK:game._show_lobby()
  else:game.menu_status.text=error_string(error))
 join.custom_minimum_size.x=210;row.add_child(join);panel.add_child(row)
 game.menu_status=label("Permanent upgrades, relics and N difficulty apply to PvE.\nLevel-up builds and the normal shop remain active in PvP.",19)
 game.menu_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(game.menu_status)
 panel.add_child(button("BACK TO MAIN MENU",func():game._show_main_menu()))
static func pvp_lobby(game) -> void:
 var root=backdrop(game,"lobby");var panel=centered(root,65)
 panel.offset_left=-470;panel.offset_right=470
 panel.add_child(label("PVP ARAM • "+("STEAM" if LanSession.transport=="steam" else "LAN"),42))
 panel.add_child(label("Equal starting stats • Both teams must press Ready",20))
 var controls=HBoxContainer.new();controls.alignment=BoxContainer.ALIGNMENT_CENTER;controls.add_theme_constant_override("separation",24)
 game.lobby_size=OptionButton.new();game.lobby_size.name="PvpTeamSize"
 for value in ["1v1","2v2","3v3"]:game.lobby_size.add_item(value)
 game.lobby_size.custom_minimum_size=Vector2(180,42);game.lobby_size.add_theme_font_size_override("font_size",22)
 game.lobby_size.select(int(LanSession.rules.team_size)-1);game.lobby_size.disabled=not LanSession.is_host()
 game.lobby_size.item_selected.connect(func(index):LanSession.set_pvp_rules(index+1,bool(LanSession.rules.fill_bots)))
 controls.add_child(game.lobby_size)
 game.lobby_bots=CheckButton.new();game.lobby_bots.name="PvpLobbyBots";game.lobby_bots.text="FILL EMPTY SLOTS WITH AI";game.lobby_bots.button_pressed=LanSession.rules.fill_bots
 game.lobby_bots.disabled=not LanSession.is_host();game.lobby_bots.add_theme_font_size_override("font_size",20)
 game.lobby_bots.toggled.connect(func(enabled):LanSession.set_pvp_rules(int(LanSession.rules.team_size),enabled))
 controls.add_child(game.lobby_bots);panel.add_child(controls)
 game.menu_status=label(LanSession.status,18);game.menu_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(game.menu_status)
 var teams=HBoxContainer.new();teams.add_theme_constant_override("separation",20);game.lobby_team_rosters.clear()
 for team in range(2):
  var col=VBoxContainer.new();col.custom_minimum_size.x=460
  var title=label("BLUE TEAM" if team==0 else "RED TEAM",28);title.add_theme_color_override("font_color",Color("80c6f6") if team==0 else Color("f3958b"));col.add_child(title)
  var list=label("",21);list.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;list.custom_minimum_size=Vector2(460,160);col.add_child(list)
  game.lobby_team_rosters.append(list);teams.add_child(col)
 panel.add_child(teams)
 var selection=HBoxContainer.new();selection.alignment=BoxContainer.ALIGNMENT_CENTER;selection.add_theme_constant_override("separation",20)
 selection.add_child(label("YOUR TEAM",22));game.lobby_team=OptionButton.new();game.lobby_team.name="PvpTeam"
 game.lobby_team.add_item("BLUE");game.lobby_team.add_item("RED");game.lobby_team.custom_minimum_size=Vector2(180,44);game.lobby_team.add_theme_font_size_override("font_size",22)
 game.lobby_team.item_selected.connect(func(team):LanSession.change_team(team));selection.add_child(game.lobby_team)
 game.lobby_ready=button("READY",func():
  var local=LanSession.local_config()
  if not local.is_empty():LanSession.ready_player(local.hero,local.spells,{},not local.get("ready",false)))
 game.lobby_ready.name="PvpReady";game.lobby_ready.custom_minimum_size=Vector2(240,48);selection.add_child(game.lobby_ready);panel.add_child(selection)
 panel.add_child(button("CHOOSE HERO & SUMMONERS",func():
  var local=LanSession.local_config()
  if not local.is_empty():LanSession.ready_player(local.hero,local.spells,{},false)
  game._show_menu()))
 game.lobby_hint=label("",19);game.lobby_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;panel.add_child(game.lobby_hint)
 game.lobby_start=button("START PVP MATCH",func():LanSession.start_match());game.lobby_start.name="StartPvpMatch";game.lobby_start.visible=LanSession.is_host();panel.add_child(game.lobby_start)
 if LanSession.transport=="steam":
  var row=HBoxContainer.new();row.alignment=BoxContainer.ALIGNMENT_CENTER
  var invite=button("INVITE FRIENDS",func():SteamSession.invite_friends());invite.custom_minimum_size.x=280;row.add_child(invite)
  var code=button("COPY LOBBY CODE",func():DisplayServer.clipboard_set(str(SteamSession.lobby_id)));code.custom_minimum_size.x=280;row.add_child(code);panel.add_child(row)
 panel.add_child(button("LEAVE LOBBY",func():LanSession.leave();game._show_main_menu()))
 game._refresh_lobby()
