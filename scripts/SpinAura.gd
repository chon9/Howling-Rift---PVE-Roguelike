extends Node2D
# Tiny visual: pulsing yellow ring around a champion using Judgment (Garen E).

var t: float = 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func _process(delta: float) -> void:
	if GameState.paused: return
	t += delta
	queue_redraw()

func _draw() -> void:
	var pulse = 1.0 + sin(t * 20.0) * 0.08
	var r = 70.0 * pulse
	draw_texture_rect_region(SpellArt.impacts, Rect2(Vector2.ONE * -r, Vector2.ONE * r * 2), SpellArt.frame(SpellArt.impacts, 2, 3 + int(t * 12) % 4), Color(1, 1, 1, 0.8))
	draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(1.0, 0.87, 0.2, 0.7), 3.0, true)
	draw_circle(Vector2.ZERO, r - 2, Color(1.0, 0.93, 0.33, 0.12))
