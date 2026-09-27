extends Node
## Tries every wardrobe item (and every death preview, BONK and CHEER) on the turntable.
## Any script error shows up in the output.
##   xvfb-run -a godot --rendering-driver opengl3 --path . -- --qa --tool=res://tools/wardrobe_test.gd
var out := "/tmp/claude-0/wardrobe"


func _ready() -> void:
	Profile.ephemeral = true
	Profile.coins = 99999
	DirAccess.make_dir_recursive_absolute(out)
	await get_tree().create_timer(0.8).timeout
	var app := get_parent()
	app.call(&"_open_wardrobe")
	await get_tree().create_timer(1.0).timeout
	var w: Wardrobe = null
	for c in get_tree().root.find_children("*", "Wardrobe", true, false):
		w = c
	var n := 0
	for cat: StringName in [&"hat", &"face", &"cup", &"skin", &"death", &"title"]:
		w.set("_category", cat)
		w.call(&"_refresh")
		await get_tree().process_frame
		if cat == &"title":
			continue
		var catalog: Dictionary = Cosmetics.CATEGORIES[cat]
		for id: StringName in catalog:
			var look := Profile.look()
			look[String(cat)] = id
			w.call(&"_rebuild_guest", look)
			await get_tree().process_frame
			await get_tree().process_frame
			n += 1
			if cat == &"death":
				w.call(&"_preview_death")
				await get_tree().create_timer(1.6).timeout
			if n % 6 == 0:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [out, cat, id])
		# Buy and wear the first paid item of each category.
		for id: StringName in catalog:
			if not Profile.owns(cat, id) and Profile.can_buy(cat, id) == "":
				Profile.buy(cat, id)
				Profile.equip(cat, id)
				w.call(&"_rebuild_guest", Profile.look())
				w.call(&"_refresh")
				break
	var g: Guest = w.get("_guest")
	g.bonk(Vector3(0, 0, -1), Color.PINK)
	await get_tree().create_timer(0.5).timeout
	g.gesture(&"cheer")
	await get_tree().create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/final.png" % out)
	print("WARDROBE tried %d items" % n)
	get_tree().quit()
