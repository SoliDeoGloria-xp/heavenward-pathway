extends Control
## End of the first-session demo: summary over the key art.

func _ready() -> void:
	UIKit.full_rect(self); theme = G.theme
	var art: Control = load("res://scripts/screens/title.gd").KeyArt.new(); UIKit.full_rect(art); add_child(art)
	var cc := CenterContainer.new(); UIKit.full_rect(cc); add_child(cc)
	var w := UIKit.window("End of the first-session demo", Vector2(820, 0))
	var b: VBoxContainer = w.body
	var q := UIKit.label("So I saw in my dream that the pilgrim ran…", 30, UIKit.BLUE_INK)
	q.add_theme_font_override("font", G.font_title)
	b.add_child(q)
	var mins := maxi(1, int((Time.get_ticks_msec() - G.start_ms) / 60000.0))
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 8)
	var sec := 0
	for k in G.secrets.keys(): sec += G.secrets[k].size()
	for kv in [["Time", "%d min" % mins], ["Base Level", str(G.lvl)], ["Job Level", str(G.job)], ["Manna", str(snappedf(G.manna, 0.1))], ["Rests (KO)", str(G.kos)], ["Secrets found", "%d / 4" % sec],
		["Fellowship Marks", str(G.marks)], ["Waymarks raised", str(G.my_waymarks.size())], ["Snapshots", str(G.snaps)]]:
		var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/slot.png", 8, 10)); p.custom_minimum_size = Vector2(250, 0)
		var h := HBoxContainer.new(); var l := UIKit.label(kv[0], 20); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l); h.add_child(UIKit.label(kv[1], 20, UIKit.INK, true)); p.add_child(h); grid.add_child(p)
	b.add_child(grid)
	b.add_child(UIKit.label("You walked the Way alone, met the pilgrims in the House, and answered a Muster. In the full game the Slough, the Wicket Gate, the Interpreter's House and the Cross come between the City and the Palace, and the Valley meadows open as the first shared Wild.", 19, UIKit.SUB, false, true))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; row.add_theme_constant_override("separation", 10)
	row.add_child(UIKit.button("Replay the City", func():
		G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = false
		G.goto("world", {"map": "city"}), 240))
	row.add_child(UIKit.button("Return to the House", func():
		G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = false
		G.goto("world", {"map": "palace"}), 260))
	row.add_child(UIKit.button("Start over", func(): G.reset(); G.goto("title"), 200, true))
	b.add_child(row)
	b.add_child(UIKit.label("Placeholder art and no audio yet. Scripture appears as [BSB references]; the build pulls the text. Bunyan quotations are public domain (1678).", 15, UIKit.SUB, false, true))
	cc.add_child(w.root)
