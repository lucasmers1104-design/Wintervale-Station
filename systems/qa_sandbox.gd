## Schützt echte Spielerdaten vor automatischen Tests.
##
## Wird eine Szene aus res://tests/ oder res://_probe/ gestartet (oder das
## Spiel mit "-- --qa-sandbox"), schreiben SaveManager, GameSettings und
## GameInput nach user://qa_sandbox/ statt nach user://saves/,
## user://settings.cfg und user://keybindings.cfg.
class_name QaSandbox
extends RefCounted

const ROOT := "user://qa_sandbox/"


static func is_active() -> bool:
	if OS.get_cmdline_user_args().has("--qa-sandbox"):
		return true
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://tests/") or arg.begins_with("res://_probe/") \
				or arg.begins_with("tests/") or arg.begins_with("_probe/"):
			return true
	return false


## Liefert [param path] unverändert oder – in der Sandbox – umgeleitet.
static func redirect(path: String) -> String:
	if not is_active():
		return path
	DirAccess.make_dir_recursive_absolute(ROOT)
	return ROOT + path.trim_prefix("user://")
