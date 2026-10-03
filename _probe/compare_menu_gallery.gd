extends SceneTree

const PAGES := [
	"load_save", "achievements", "settings_graphics", "settings_audio",
	"settings_controls", "settings_gameplay", "credits",
]


func _initialize() -> void:
	var largest := 0.0
	for page in PAGES:
		var reference := Image.new()
		var rendered := Image.new()
		reference.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/ui/menu_screens/%s.png" % page))
		rendered.load_png_from_buffer(FileAccess.get_file_as_bytes("res://docs/menu_gallery_%s.png" % page))
		if reference.get_size() != rendered.get_size():
			push_error("Size mismatch: " + page)
			quit(1)
			return
		var sum := 0.0
		var count := 0
		for y in range(0, 941, 4):
			for x in range(0, 1672, 4):
				var a := reference.get_pixel(x, y)
				var b := rendered.get_pixel(x, y)
				sum += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				count += 3
		var mean := sum / float(count)
		largest = maxf(largest, mean)
		print(page, " sampled mean channel difference: ", snappedf(mean * 255.0, 0.01), "/255")
	print("largest sampled mean: ", snappedf(largest * 255.0, 0.01), "/255")
	quit()
