extends Node

const NAMES = ["bow", "blade", "magic", "fire", "frost", "light", "spirit", "impact", "hurt", "dash", "coin", "click", "level", "kill", "death", "victory", "defeat", "blade_ultimate", "fire_ultimate", "frost_ultimate", "magic_ultimate", "spirit_ultimate", "light_ultimate", "wind", "wind_ultimate", "fist", "fist_ultimate", "gun", "gun_ultimate"]
const ANNOUNCER_NAMES = ["first_blood","double_kill","triple_kill","quadra_kill","penta_kill","killing_spree","mega_kill","unstoppable","monster_kill","godlike","legendary","enemy_slain"]
const SUPPLIED_CLIPS={"first_blood":"first_blood","double_kill":"double_kill","triple_kill":"triple_kill","quadra_kill":"maniac","penta_kill":"savage","killing_spree":"killing_spree","mega_kill":"mega_kill","unstoppable":"unstoppable","monster_kill":"monster_kill","godlike":"godlike","legendary":"legendary","enemy_slain":"enemy_slain"}
var announcer_clips: Dictionary = {}
var announcer_voice: AudioStreamPlayer
var announcement_counts: Dictionary = {}
var announcer_priority: int = 0
var clips: Dictionary = {}
var voices: Array = []
var last_played: Dictionary = {}
var counts: Dictionary = {}
var enabled: bool = true
var next_voice: int = 0
var next_priority_voice: int = 0

func _ready() -> void:
	for key in NAMES: clips[key] = load("res://assets/audio/combat-v2/%s.wav" % key)
	# Voice playback uses only supplied recordings. Missing callouts stay silent.
	for key in SUPPLIED_CLIPS:
		announcer_clips[key] = load("res://assets/audio/mobile-announcer-v1/%s.wav" % SUPPLIED_CLIPS[key])
	announcer_voice = AudioStreamPlayer.new()
	announcer_voice.volume_db = -5
	add_child(announcer_voice)
	for i in range(12):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)

func play(event: String, actor = null) -> void:
	if not enabled or event == "minion_impact": return
	var key = "impact" if event == "minion_impact" else event
	if is_instance_valid(actor):
		var camera = get_viewport().get_camera_2d()
		if camera != null and actor.world_pos().distance_to(camera.global_position) > 900 and actor != GameState.player: return
		if event == "attack":
			key = "fist" if actor.hero_key == "leesin" else ("blade" if actor.auto_type == "melee" else ("bow" if actor.hero_key == "ashe" else ("gun" if actor.hero_key == "jinx" else ("fire" if actor.hero_key == "annie" else "magic"))))
		elif event in ["spell", "ultimate"]:
			key = {"ashe":"frost", "annie":"fire", "garen":"blade", "lux":"light", "ahri":"spirit", "ezreal":"magic", "yasuo":"wind", "leesin":"fist", "zed":"blade", "jinx":"gun", "katarina":"blade", "kayle":"light"}.get(actor.hero_key, "magic")
			if event == "ultimate": key += "_ultimate"
	if not clips.has(key): return
	var now = Time.get_ticks_msec()
	var gap = 180 if event == "minion_impact" else (110 if event in ["attack", "impact", "hurt", "spell"] else 50)
	var gate = "wave_impact" if event == "minion_impact" else key + (str(actor.get_instance_id()) if is_instance_valid(actor) else "")
	if now - int(last_played.get(gate, -10000)) < gap: return
	last_played[gate] = now
	var important = event in ["ultimate", "victory", "defeat", "death", "level"]
	var index = 8 + next_priority_voice if important else next_voice
	var voice = voices[index]
	if important: next_priority_voice = (next_priority_voice + 1) % 4
	else: next_voice = (next_voice + 1) % 8
	voice.stream = clips[key]
	var mix = -25 if event == "minion_impact" else -15 if event in ["attack","impact","hurt"] else (-9 if event == "ultimate" else -14)
	if event != "minion_impact" and is_instance_valid(actor) and actor.kind == "minion": mix -= 5
	voice.set_meta("mix_volume",mix)
	voice.volume_db = mix-5 if announcer_voice.playing else mix
	voice.pitch_scale = randf_range(0.98, 1.02) if event in ["attack", "impact", "hurt", "spell"] else 1.0
	# Headless runs validate dispatch/assets without queuing inaudible driver playback.
	if DisplayServer.get_name() != "headless": voice.play()
	counts[key] = int(counts.get(key, 0)) + 1

func announce(key: String) -> void:
	if not enabled or not announcer_clips.has(key): return
	var priority = 4 if key in ["victory_voice","defeat_voice"] else 3 if key in ["double_kill","triple_kill","quadra_kill","penta_kill"] else 2 if key in ["killing_spree","mega_kill","unstoppable","monster_kill","godlike","legendary","shutdown"] else 1
	# Ordinary slain calls cannot cut off an ongoing multikill announcement.
	if announcer_voice.playing and priority < announcer_priority: return
	announcer_priority = priority
	announcer_voice.stop()
	announcer_voice.stream = announcer_clips[key]
	if DisplayServer.get_name() != "headless": announcer_voice.play()
	announcement_counts[key] = int(announcement_counts.get(key,0))+1

func _process(_delta: float) -> void:
	for voice in voices:
		if voice.has_meta("mix_volume"): voice.volume_db = float(voice.get_meta("mix_volume"))-(5 if announcer_voice.playing else 0)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		announcer_voice.stop()
		for voice in voices: voice.stop()

func _exit_tree() -> void:
	announcer_voice.stop()
	announcer_voice.stream = null
	announcer_clips.clear()
	for voice in voices:
		voice.stop()
		voice.stream = null
	clips.clear()
