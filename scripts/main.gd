extends Node
## Screen manager. Screens are plain scripts that build their own node trees.

const SCREENS := {
	"title": "res://scripts/screens/title.gd",
	"create": "res://scripts/screens/create.gd",
	"story": "res://scripts/screens/story.gd",
	"world": "res://scripts/screens/world.gd",
	"end": "res://scripts/screens/end.gd",
}

var current: Node
var fader: ColorRect
var autotest := false

func _ready() -> void:
	G.main = self
	var layer := CanvasLayer.new(); layer.layer = 100; add_child(layer)
	fader = ColorRect.new(); fader.color = Color(0, 0, 0, 0); fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.full_rect(fader); layer.add_child(fader)
	autotest = OS.get_cmdline_user_args().has("--autotest")
	show_screen("title", {})
	if autotest:
		var t: Node = load("res://scripts/autotest.gd").new()
		add_child(t)

func show_screen(name: String, data: Dictionary) -> void:
	var tw := create_tween()
	if current:
		tw.tween_property(fader, "color:a", 1.0, 0.25)
	tw.tween_callback(_swap.bind(name, data))
	tw.tween_property(fader, "color:a", 0.0, 0.35)

func _swap(name: String, data: Dictionary) -> void:
	if current:
		current.name = "Leaving"   # free the name so world -> world swaps keep "World"
		current.queue_free()
	var s: Node = load(SCREENS[name]).new()
	s.set_meta("data", data)
	s.name = name.capitalize()
	current = s
	add_child(s)
	move_child(s, 0)

func shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
