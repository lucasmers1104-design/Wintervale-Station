## Dauerhafte, kompakte Tastenlegende (unten rechts).
##
## Zeigt die Tasten des aktuellen Spielmodus als kleine Tastenkappen in zwei
## Spalten. Inhalt und Tastennamen kommen aus [InputConfig] – sie stimmen
## also immer mit der echten Steuerung überein. Eingeklappt bleibt nur ein
## kleiner Hinweis, wie man sie wieder öffnet.
class_name KeyLegend
extends PanelContainer

@export var columns := 2

var _mode: StringName = &"bird_eye"
var _expanded := true
var _grid: GridContainer
var _collapsed_row: HBoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme_type_variation = &"LegendPanel"
	_grid = GridContainer.new()
	_grid.columns = columns
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override("h_separation", 18)
	_grid.add_theme_constant_override("v_separation", 5)
	add_child(_grid)
	_collapsed_row = HBoxContainer.new()
	_collapsed_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_collapsed_row)
	_rebuild()


## Zeigt die Legende für einen Modus (&"explore", &"bird_eye", &"build_rail" …).
func show_mode(mode: StringName) -> void:
	if mode == _mode:
		return
	_mode = mode
	_rebuild()


func set_expanded(value: bool) -> void:
	_expanded = value
	_rebuild()


func is_expanded() -> bool:
	return _expanded


func get_mode() -> StringName:
	return _mode


## Die aktuell angezeigten Zeilen: [{"keys": [...], "text": "..."}].
func get_rows() -> Array[Dictionary]:
	return InputConfig.get_legend(_mode)


func _rebuild() -> void:
	if _grid == null:
		return
	for child in _grid.get_children() + _collapsed_row.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	_grid.visible = _expanded
	_collapsed_row.visible = not _expanded
	if _expanded:
		for row in get_rows():
			_grid.add_child(_make_row(row["keys"], row["text"]))
	else:
		_collapsed_row.add_child(_make_row([InputConfig.get_action_label(&"toggle_help")], "Tasten anzeigen"))


func _make_row(keys: Array, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	for key: String in keys:
		var cap := PanelContainer.new()
		cap.theme_type_variation = &"KeyCap"
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var key_label := Label.new()
		key_label.theme_type_variation = &"KeyCapText"
		key_label.text = key
		cap.add_child(key_label)
		row.add_child(cap)
	var description := Label.new()
	description.theme_type_variation = &"LegendText"
	description.text = text
	row.add_child(description)
	return row
