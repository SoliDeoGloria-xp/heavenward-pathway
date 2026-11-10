extends Control
## End of Acts I-II: the first Calling is taken up. Summary over the key art.

const NEXT := "Next: Vanity Fair, where Faithful will be tried. The road goes on in the next chapter."

func _ready() -> void:
	UIKit.full_rect(self); theme = G.theme
	var art: Control = load("res://scripts/screens/title.gd").KeyArt.new(); UIKit.full_rect(art); add_child(art)
	var cc := CenterContainer.new(); UIKit.full_rect(cc); add_child(cc)
	var w := UIKit.window("Two pilgrims on the road · end of this chapter", Vector2(860, 0))
	var b: VBoxContainer = w.body
	var q := UIKit.label("So %s the %s went on the way." % [G.pname, G.job_name()], 30, UIKit.BLUE_INK)
	q.add_theme_font_override("font", G.font_title)
	b.add_child(q)
	var grid := GridContainer.new(); grid.columns = 3; grid.add_theme_constant_override("h_separation", 12); grid.add_theme_constant_override("v_separation", 8)
	var secrets := 0
	for k in G.secrets.keys(): secrets += G.secrets[k].size()
	var rows := [["Time", "%d min" % G.minutes_played()], ["Base Level", str(G.lvl)], ["Calling", "%s (Job %d)" % [G.job_name(), G.job]],
		["Dreamer's Pages", "%d / %d" % [Quests.pages_found(), G.data("acts").order.size() - 1]], ["Secrets found", str(secrets)], ["Manna", str(snappedf(G.manna, 0.1))],
		["Rests (KO)", str(G.kos)], ["Fellowship Marks", str(G.marks)], ["Snapshots", str(G.snaps)]]
	for kv in rows:
		var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", UIKit.sb("res://assets/ui/slot.png", 8, 10)); p.custom_minimum_size = Vector2(264, 0)
		var h := HBoxContainer.new(); var l := UIKit.label(kv[0], 20); l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l); h.add_child(UIKit.label(kv[1], 20, UIKit.INK, true)); p.add_child(h); grid.add_child(p)
	b.add_child(grid)
	b.add_child(UIKit.label("From the garden to the gate, the cross, the hill, the House and the two valleys. " + NEXT, 19, UIKit.SUB, false, true))
	var row := HBoxContainer.new(); row.alignment = BoxContainer.ALIGNMENT_END; row.add_theme_constant_override("separation", 10)
	row.add_child(UIKit.button("Return to the House", func() -> void:
		G.hp = G.hp_max; G.zeal = G.zeal_max; G.weary = false
		G.map_state.erase("palace"); G.goto("world", {"map": "palace"}), 260, true))
	row.add_child(UIKit.button("Title", func() -> void: G.goto("title"), 160))
	b.add_child(row)
	b.add_child(UIKit.label("Placeholder art; music and sound play when audio files are added. Scripture is cited as [BSB: reference]. Bunyan quotations are public domain (1678).", 16, UIKit.SUB, false, true))
	cc.add_child(w.root)
