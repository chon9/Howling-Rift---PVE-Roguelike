class_name GraphicsQuality
extends CanvasLayer
# A single world-only canvas pass. HUD, menus and cursor render above layer 1.
var screen: ColorRect
func _ready() -> void:
 name = "GraphicsQuality"
 layer = 1
 screen = ColorRect.new()
 screen.name = "WorldEdgeSmoothing"
 screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
 screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var fx = ShaderMaterial.new()
 fx.shader = preload("res://assets/shaders/world-fxaa.gdshader")
 screen.material = fx
 add_child(screen)
 apply()
func _process(_delta: float) -> void:
 screen.visible = Progression.edge_smoothing and GameState.started
func apply() -> void:
 screen.visible = Progression.edge_smoothing and GameState.started
 # Headless checks don't render; don't throttle simulation tests.
 if DisplayServer.get_name() != "headless":
  Engine.max_fps = Progression.frame_limit
  DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if Progression.vsync_enabled else DisplayServer.VSYNC_DISABLED)
static func settings_row(parent: Control,quality: CanvasLayer) -> void:
 var smooth = CheckButton.new()
 smooth.name = "EdgeSmoothing"
 smooth.text = "WORLD EDGE SMOOTHING (FXAA)"
 smooth.button_pressed = Progression.edge_smoothing
 smooth.tooltip_text = "Smooths sprite and spell edges at native resolution. HUD text stays sharp. One extra GPU pass; turn off for maximum FPS. FSR/DLSS do not apply to this 2D renderer."
 smooth.toggled.connect(func(enabled): Progression.edge_smoothing = enabled; quality.apply(); Progression.save_profile())
 parent.add_child(smooth)
 var vsync = CheckButton.new()
 vsync.name = "VSync"
 vsync.text = "V-SYNC (PREVENT SCREEN TEARING)"
 vsync.button_pressed = Progression.vsync_enabled
 vsync.tooltip_text = "On: sync to your display refresh rate. Off: permit higher FPS with lower latency, but tearing may appear. The frame limit still applies."
 vsync.toggled.connect(func(enabled): Progression.vsync_enabled = enabled; quality.apply(); Progression.save_profile())
 parent.add_child(vsync)
 var row = HBoxContainer.new()
 row.add_child(RiftMenus.label("FRAME LIMIT",20))
 var limit = OptionButton.new()
 limit.name = "FrameLimit"
 limit.custom_minimum_size = Vector2(200,40)
 var values = [60,120,144,240,0]
 for fps in values: limit.add_item("UNLIMITED" if fps == 0 else "%d FPS" % fps)
 limit.select(maxi(0,values.find(Progression.frame_limit)))
 limit.tooltip_text = "A cap reduces unnecessary GPU/CPU work. Unlimited can improve response on fast PCs; smoothing costs some GPU time."
 limit.item_selected.connect(func(index): Progression.frame_limit = values[index]; quality.apply(); Progression.save_profile())
 row.add_child(limit)
 parent.add_child(row)
