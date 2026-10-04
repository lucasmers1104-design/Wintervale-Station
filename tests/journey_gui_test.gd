## Real native-control flows and responsive bounds for the reference GUI.
extends Node
var checks := 0
var failures := 0
var main: Node3D
var region: RegionRailway
var panel: RegionPanel

func _ready() -> void:
	_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	failures += 0 if ok else 1
	print("PASS " if ok else "FAIL ",label)
func frames(count := 5) -> void:
	for i in count:
		await get_tree().process_frame
func button(root: Node,caption: String) -> Button:
	for child in root.get_children():
		if child is Button and caption in child.text:
			return child
		var found := button(child,caption)
		if found:
			return found
	return null
func pickers(root: Node) -> Array[OptionButton]:
	var found: Array[OptionButton] = []
	for child in root.get_children():
		if child is OptionButton:
			found.append(child)
		found.append_array(pickers(child))
	return found

func preview_in(root: Node) -> JourneyTrainPreview:
	if root is JourneyTrainPreview:
		return root
	for child in root.get_children():
		var found := preview_in(child)
		if found:
			return found
	return null

func _run() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await frames(12)
	region = main.get("region")
	panel = main.get_node("RegionPanel")
	var tutorial := main.get_node("JourneyTutorial") as JourneyTutorial
	check(not tutorial._large_intro and tutorial._card.size.x<550,"new journey begins with a compact tutorial")
	tutorial.set_process(false)
	main.get_node("JourneyGuide").set_process(false)
	WorldClock.paused = true
	Economy.money = 100000
	region.progression.set_epoch(2,true)
	region.progression.set_process(false)
	var build := main.get_node("BuildMode") as BuildMode
	build.set_active(true)
	build.select_tool(&"rail")
	build.set_process(false)
	var rail := build.get_tool(&"rail") as RailPlaceTool
	var portal := region.portals[0]
	var stub := portal.get_stub_end()
	rail.click_at(stub,true)
	rail.click_at(stub+Vector3(0,0,50),true)
	rail.click_at(stub+Vector3(0,0,100),true)
	rail.cancel()
	build.set_active(false)
	var station := region.build_station(region.placement(stub+Vector3(4,0,55)),false)
	check(station!=null,"fixture has a real reachable station")
	if station==null:
		get_tree().quit(1)
		return
	station.level = 2
	station.rebuild()
	panel._station_id = station.station_id
	for resolution in [Vector2i(1280,720),Vector2i(1672,941),Vector2i(1920,1080)]:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		get_tree().root.content_scale_size = resolution
		get_tree().root.size = resolution
		await frames()
		check(get_viewport().get_visible_rect().size==Vector2(resolution),"UI viewport uses the requested resolution")
		panel.close()
		tutorial._update_ribbon()
		await frames()
		var launch := panel._launcher.get_global_rect()
		var factor := JourneyStyle.screen_factor(Vector2(resolution))
		check(launch.position.y<=13*factor and absf(launch.end.x-(resolution.x-12*factor))<1,"launcher sits in the top right corner at %s: %s, expected right %.2f" % [resolution,launch,resolution.x-12*factor])
		check(not launch.intersects(main.get_node("HUD")._status_bar.get_global_rect()),"launcher leaves the centered status bar clear")
		check(panel._launcher_title.get_minimum_size().x<=panel._launcher_title.size.x,"launcher text fits its paper face")
		check(panel._help_button.get_theme_stylebox("normal") is StyleBoxTexture,"help uses the snowy wood and brass seal")
		for page in ["epochs","stations","fleet","lines","station"]:
			panel._selected_train = "reference_freight"
			panel.open_page(page)
			tutorial._update_ribbon()
			await frames()
			check(get_viewport().get_visible_rect().grow(1).encloses(panel._panel.get_global_rect()),"board fits %s at %s" % [page,resolution])
			check(panel._content.size.x<=panel._scroll.size.x+1,"no clipped horizontal content: %s at %s" % [page,resolution])
			check(not panel._launcher.visible,"launcher does not cover modal tabs: "+page)
			check(not tutorial._intro_shade.visible,"introduction blur does not cover the open book: "+page)
		panel.close()
		for step in [0,1,8]:
			region.progression.tutorial_step = step
			tutorial._show_current()
			tutorial._update_ribbon()
			await frames()
			check(get_viewport().get_visible_rect().grow(1).encloses(tutorial._card.get_global_rect()),"compact introduction step %d fits %s" % [step,resolution])
			check(not tutorial._intro_shade.visible and not tutorial._large_intro,"small tutorial keeps the landscape clear")
	region.progression.tutorial_step = -1
	tutorial._show_current()
	panel._selected_train = "reference_freight"
	panel.open_page("fleet")
	await frames()
	var freight := preview_in(panel._content)
	check(freight!=null and freight.train_type==EpochCatalog.train("reference_freight"),"freight opens directly as its real 3D model")
	check(button(panel._content,"3D ansehen")==null and panel._viewport.render_target_update_mode==SubViewport.UPDATE_WHEN_VISIBLE,"no illustration overlay or extra 3D switch")
	if freight:
		var before := freight._preview.rotation.y
		var drag := InputEventMouseMotion.new()
		drag.button_mask = MOUSE_BUTTON_MASK_LEFT
		drag.relative = Vector2(40,0)
		freight.container.gui_input.emit(drag)
		check(absf(freight._preview.rotation.y-before-0.48)<0.001,"dragging rotates the actual freight consist")
	panel.open_page("epochs")
	for level in range(1,7):
		panel._selected_epoch = level
		panel._refresh()
		await frames()
		var epoch_preview := preview_in(panel._content)
		check(epoch_preview!=null and epoch_preview.train_type==EpochCatalog.train(EpochCatalog.epoch(level)["trains"][0]),"epoch %d previews its actual unlocked train" % level)
		if epoch_preview:
			var cars := 0
			for child in epoch_preview._preview.get_children():
				cars += 1 if child is TrainCar else 0
			check(cars==epoch_preview.train_type.consist.size(),"epoch %d shows the full consist" % level)
	check(not region.progression.is_train_unlocked("reference_freight"),"viewing locked trains does not unlock them")
	panel.show_train("nostalgic_regional")
	await frames()
	var choices := pickers(panel._content)
	check(choices.size()==3,"unlocked train presents live origin, destination and vehicle pickers")
	if choices.size()==3:
		check(choices[0].get_selected_id()==portal.station_id and choices[1].get_selected_id()==station.station_id,"pickers point to real reachable endpoints")
		check(choices[2].get_item_metadata(choices[2].selected)=="nostalgic_regional","selected vehicle matches its illustration and data")
	check(panel._assign_button!=null and not panel._assign_button.disabled,"valid route can be dispatched")
	if panel._assign_button and not panel._assign_button.disabled:
		panel._assign_button.pressed.emit()
		await frames()
	check(region.lines.size()==1 and not panel.is_open(),"dispatch button creates a real service and shows its arrival")
	if not region.lines.is_empty():
		var line: Dictionary = region.lines[0]
		panel.open_page("lines")
		await frames()
		var pause := button(panel._content,"Pausieren")
		check(pause!=null,"service card has a pause control")
		if pause:
			pause.pressed.emit()
			await frames()
			check(not line["enabled"],"pause button changes real service state")
		var resume := button(panel._content,"Fortsetzen")
		if resume:
			resume.pressed.emit()
			await frames()
		check(line["enabled"],"resume button restores service state")
		var remove := button(panel._content,"Aufheben")
		if remove:
			remove.pressed.emit()
			await frames()
		check(region.lines.is_empty(),"remove button cancels the actual service")
	region.progression.set_epoch(6,true)
	station.rename_station("Mein großer Bahnhof am Winterwald")
	get_tree().root.size = Vector2i(1280,720)
	get_tree().root.content_scale_size = Vector2i(1280,720)
	for id in ["diesel_heritage","nostalgic_regional","reference_freight","modern_local","intercity","high_speed"]:
		panel.show_train(id)
		await frames()
		check(panel._content.size.x<=panel._scroll.size.x+1,"unlocked vehicle form and long station name fit: "+id)
	panel.close()
	region.progression.tutorial_step = 1
	tutorial._show_current()
	tutorial._update_ribbon()
	build.set_active(true)
	tutorial._evaluate()
	check(tutorial._advancing,"build action still completes the illustrated tutorial step")
	tutorial._advance()
	check(region.progression.tutorial_step>1 and not tutorial._large_intro,"building task returns to a compact guide and skips completed construction")
	tutorial.finish()
	check(tutorial.is_finished(),"skip action is saved as a completed introduction")
	print("JOURNEY GUI RESULTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
