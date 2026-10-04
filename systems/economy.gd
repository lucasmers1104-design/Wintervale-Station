## Wirtschaft (Autoload "Economy"): Geld, Materiallager, Reservierungen und Kassenbuch.
##
## Kennt keine Grafik und keine anderen Spielsysteme – Güterbahnhof, Dorf,
## Bauwerkzeuge und Notizbuch rufen nur diese Schnittstelle auf und hören auf
## die Signale.
##
## Materialien ([GoodsType]) werden aus assets/goods/ geladen. Kosten werden
## überall als Dictionary angegeben: {"money": 350, "wood": 30, "brick": 12}.
##
## Materialfluss:
##   Güterzug entladen → [method add_stock] (Einkauf wird bezahlt)
##   Haus platzieren   → [method charge_build]: Geld bezahlt, Material reserviert
##   Baufortschritt    → [method consume]: reserviertes Material wird verbaut
##   Abriss / Undo     → [method refund_build]: alles kommt zurück ins Lager
extends Node

signal money_changed(money: int)
signal stock_changed(goods_id: String)
signal reservations_changed
signal ledger_changed
signal orders_changed

const SAVE_ID := "economy"
const GOODS_DIR := "res://assets/goods"
const START_MONEY := 3000
## So viele Buchungen behält das Kassenbuch.
const LEDGER_SIZE := 80
## Arten von Buchungen (für die Tagesübersicht im Notizbuch).
const KIND_LABELS := {
	"tickets": "Fahrkarten",
	"freight": "Frachterlöse",
	"taxes": "Gemeindeabgaben",
	"deposit": "Leergut-Pfand",
	"purchase": "Materialeinkauf",
	"build": "Baukosten",
	"refund": "Rückerstattung",
	"upkeep": "Unterhalt",
	"reward": "Finderlohn",
}

## Kostenlos bauen (Sandbox, automatische Tests).
var free_build := false
var money := START_MONEY
## Zählt jede Änderung an Geld, Lager oder Reservierungen (für Vorschauen, die neu prüfen müssen).
var revision := 0

var _goods: Array[GoodsType] = []
var _by_id: Dictionary[String, GoodsType] = {}
var _stock: Dictionary[String, int] = {}
var _orders: Dictionary[String, bool] = {}
## Schlüssel (z.B. "village:12") → {goods_id: Menge}
var _reservations: Dictionary = {}
var _ledger: Array[Dictionary] = []


func _ready() -> void:
	add_to_group(GameDefs.GROUP_SAVEABLE)
	_load_goods()
	money_changed.connect(func(_m: int) -> void: revision += 1)
	stock_changed.connect(func(_g: String) -> void: revision += 1)
	reservations_changed.connect(func() -> void: revision += 1)
	reset()


## Neues Spiel: Startgeld und Startbestände.
func reset() -> void:
	money = START_MONEY
	_reservations.clear()
	_ledger.clear()
	for goods in _goods:
		_stock[goods.id] = goods.start_stock
		_orders[goods.id] = true
	money_changed.emit(money)
	for goods in _goods:
		stock_changed.emit(goods.id)
	reservations_changed.emit()
	ledger_changed.emit()
	orders_changed.emit()


# --- Materialien ------------------------------------------------------------------------

func get_goods() -> Array[GoodsType]:
	return _goods


func get_goods_type(goods_id: String) -> GoodsType:
	return _by_id.get(goods_id)


func has_goods(goods_id: String) -> bool:
	return _by_id.has(goods_id)


func get_label(goods_id: String) -> String:
	var goods := get_goods_type(goods_id)
	return goods.display_name if goods else goods_id


func get_stock(goods_id: String) -> int:
	return _stock.get(goods_id, 0)


func get_max(goods_id: String) -> int:
	var goods := get_goods_type(goods_id)
	return goods.max_stock if goods else 0


## Freier Platz im Lager.
func get_space(goods_id: String) -> int:
	return maxi(0, get_max(goods_id) - get_stock(goods_id))


## Für Bauprojekte zurückgelegt (liegt noch im Lager, ist aber verplant).
func get_reserved(goods_id: String) -> int:
	var total := 0
	for key: String in _reservations:
		total += int((_reservations[key] as Dictionary).get(goods_id, 0))
	return total


## Bestand, über den man noch frei verfügen kann.
func get_available(goods_id: String) -> int:
	return get_stock(goods_id) - get_reserved(goods_id)


## Ins Lager legen (z.B. beim Entladen). Rückgabe: tatsächlich eingelagerte Menge.
func add_stock(goods_id: String, amount: int) -> int:
	if not has_goods(goods_id) or amount <= 0:
		return 0
	var accepted := mini(amount, get_space(goods_id))
	if accepted > 0:
		_stock[goods_id] = get_stock(goods_id) + accepted
		stock_changed.emit(goods_id)
	return accepted


## Aus dem Lager nehmen. Rückgabe: tatsächlich entnommene Menge.
func remove_stock(goods_id: String, amount: int) -> int:
	var taken := clampi(amount, 0, get_stock(goods_id))
	if taken > 0:
		_stock[goods_id] = get_stock(goods_id) - taken
		stock_changed.emit(goods_id)
	return taken


# --- Daueraufträge ----------------------------------------------------------------------

## Soll der Güterbahnhof dieses Material abnehmen (und bezahlen)?
func is_ordered(goods_id: String) -> bool:
	return _orders.get(goods_id, true)


func set_ordered(goods_id: String, ordered: bool) -> void:
	if is_ordered(goods_id) != ordered:
		_orders[goods_id] = ordered
		orders_changed.emit()


# --- Geld --------------------------------------------------------------------------------

## Einnahme verbuchen. [param kind]: Schlüssel aus [constant KIND_LABELS].
func earn(amount: int, text: String, kind := "freight") -> void:
	if amount <= 0:
		return
	money += amount
	_book(amount, text, kind)
	money_changed.emit(money)


## Ausgabe verbuchen. Rückgabe: false, wenn das Geld nicht reicht (dann passiert nichts).
func pay(amount: int, text: String, kind := "purchase") -> bool:
	if amount <= 0:
		return true
	if amount > money:
		return false
	money -= amount
	_book(-amount, text, kind)
	money_changed.emit(money)
	return true


func get_ledger() -> Array[Dictionary]:
	return _ledger


## Einnahmen und Ausgaben eines Tages: {"income", "expense", "kinds": {kind: Summe}}.
func get_day_summary(day: int) -> Dictionary:
	var income := 0
	var expense := 0
	var kinds := {}
	for entry in _ledger:
		if int(entry["day"]) != day:
			continue
		var amount := int(entry["amount"])
		if amount > 0:
			income += amount
		else:
			expense -= amount
		kinds[entry["kind"]] = int(kinds.get(entry["kind"], 0)) + amount
	return {"income": income, "expense": expense, "kinds": kinds}


func _book(amount: int, text: String, kind: String) -> void:
	# Gleichartige Buchungen kurz hintereinander zusammenfassen (z.B. viele Fahrkarten)
	if not _ledger.is_empty():
		var last := _ledger[0]
		if last["kind"] == kind and last["text"] == text and int(last["day"]) == WorldClock.day \
				and absf(WorldClock.time_of_day - float(last["hours"])) < 1.0 and signi(int(last["amount"])) == signi(amount):
			last["amount"] = int(last["amount"]) + amount
			last["count"] = int(last.get("count", 1)) + 1
			ledger_changed.emit()
			return
	_ledger.push_front({"day": WorldClock.day, "hours": WorldClock.time_of_day, "text": text,
		"amount": amount, "kind": kind, "count": 1})
	if _ledger.size() > LEDGER_SIZE:
		_ledger.resize(LEDGER_SIZE)
	ledger_changed.emit()


# --- Kosten ------------------------------------------------------------------------------

## Was fehlt noch für [param cost]? Rückgabe {"money": n, "<goods>": n} (leer = alles da).
## Mit [member material_shop] werden fehlende Baustoffe zu Geld umgerechnet.
func get_missing(cost: Dictionary) -> Dictionary:
	var missing := {}
	if free_build:
		return missing
	var shop := get_shop_cost(cost)
	for key: String in cost:
		var need := int(cost[key]) + (shop if key == "money" else 0)
		var have := money if key == "money" else get_available(key)
		if key != "money" and _shop_covers(key, need - have):
			continue
		if need > have:
			missing[key] = need - have
	if shop > 0 and not cost.has("money") and shop > money:
		missing["money"] = shop - money
	return missing


# --- Baustoffhandel (Epochen-Spiel) ------------------------------------------------------

## Fehlende Baustoffe kauft der Baustoffhandel in Nordtal mit Aufpreis dazu –
## so lässt sich das Dorf auch vor den Güterzügen frei gestalten.
var material_shop := false
const SHOP_MARKUP := 1.5

## Explicit small purchases use the same prices as automatic construction supply.
func buy_material(goods_id: String, amount: int) -> bool:
	if not material_shop or not has_goods(goods_id) or amount<=0:
		return false
	if get_stock(goods_id)+amount>get_max(goods_id):
		return false
	var price := ceili(amount*get_goods_type(goods_id).unit_price*SHOP_MARKUP)
	if not pay(price,"Baustoffhandel Nordtal: %d %s" % [amount,get_goods_type(goods_id).display_name],"purchase"):
		return false
	add_stock(goods_id,amount)
	return true


## Was der Baustoffhandel für die fehlenden Baustoffe von [param cost] verlangt.
func get_shop_cost(cost: Dictionary) -> int:
	if not material_shop or free_build:
		return 0
	var total := 0.0
	for key: String in cost:
		if key == "money" or not has_goods(key):
			continue
		var short := int(cost[key]) - get_available(key)
		if _shop_covers(key, short):
			total += short * get_goods_type(key).unit_price * SHOP_MARKUP
	return ceili(total)


func _shop_covers(goods_id: String, short: int) -> bool:
	return material_shop and short > 0 and has_goods(goods_id) and get_stock(goods_id) + short <= get_max(goods_id)


## Fehlende Baustoffe kaufen und einlagern (nur mit [member material_shop]).
func _buy_short_goods(cost: Dictionary, label: String) -> bool:
	var shop := get_shop_cost(cost)
	if shop <= 0:
		return true
	if not pay(shop, "Baustoffhandel: " + label, "purchase"):
		return false
	for key: String in cost:
		if key == "money" or not has_goods(key):
			continue
		var short := int(cost[key]) - get_available(key)
		if _shop_covers(key, short):
			add_stock(key, short)
	return true


func can_afford(cost: Dictionary) -> bool:
	return get_missing(cost).is_empty()


## "Fehlt: 12 Holz, 40 Taler" – oder "" wenn alles da ist.
func describe_missing(cost: Dictionary) -> String:
	var missing := get_missing(cost)
	if missing.is_empty():
		return ""
	return "Fehlt: " + format_cost(missing, ", ")


## "350 Taler · 30 Holz · 12 Ziegel"
func format_cost(cost: Dictionary, separator := " · ") -> String:
	var parts: PackedStringArray = []
	for goods in _goods:
		if int(cost.get(goods.id, 0)) > 0:
			parts.append("%d %s" % [int(cost[goods.id]), goods.display_name])
	if int(cost.get("money", 0)) > 0:
		parts.append(format_money(int(cost["money"])))
	return separator.join(parts)


## 1234 → "1.234 Taler"
static func format_money(amount: int, with_unit := true) -> String:
	var digits := str(absi(amount))
	var grouped := ""
	while digits.length() > 3:
		grouped = "." + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	grouped = ("-" if amount < 0 else "") + digits + grouped
	return grouped + (" Taler" if with_unit else "")


# --- Bauen -------------------------------------------------------------------------------

## Bauprojekt beginnt: Geld wird bezahlt, Material für später zurückgelegt.
## Rückgabe: false, wenn etwas fehlt (dann passiert nichts).
func charge_build(key: String, cost: Dictionary, label: String) -> bool:
	if free_build:
		_reservations[key] = {}
		return true
	if not can_afford(cost):
		return false
	if not _buy_short_goods(cost, label):
		return false
	pay(int(cost.get("money", 0)), label, "build")
	var goods := {}
	for goods_id: String in cost:
		if goods_id != "money" and int(cost[goods_id]) > 0:
			goods[goods_id] = int(cost[goods_id])
	_reservations[key] = goods
	reservations_changed.emit()
	return true


## Sofort fertige Objekte (Laterne, Baum …): bezahlen und Material gleich verbauen.
func charge_instant(key: String, cost: Dictionary, label: String) -> bool:
	if not charge_build(key, cost, label):
		return false
	for goods_id: String in (_reservations.get(key, {}) as Dictionary).keys():
		consume(key, goods_id, int(_reservations[key][goods_id]))
	_reservations.erase(key)
	reservations_changed.emit()
	return true


## Reserviertes Material eines Projekts verbauen. Rückgabe: verbaute Menge.
func consume(key: String, goods_id: String, amount: int) -> int:
	var reservation: Dictionary = _reservations.get(key, {})
	var used := mini(amount, int(reservation.get(goods_id, 0)))
	if used <= 0:
		return 0
	reservation[goods_id] = int(reservation[goods_id]) - used
	remove_stock(goods_id, used)
	reservations_changed.emit()
	return used


func get_reservation(key: String) -> Dictionary:
	return _reservations.get(key, {})


func has_reservation(key: String) -> bool:
	return _reservations.has(key)


## Projekt ist fertig: übrige Reservierung auflösen (sollte leer sein).
func finish_build(key: String) -> void:
	if _reservations.erase(key):
		reservations_changed.emit()


## Abriss oder Rückgängig: Geld und Material kommen vollständig zurück
## (auch schon verbautes Material – Abriss soll nichts kosten).
func refund_build(key: String, cost: Dictionary, label: String) -> void:
	if free_build:
		_reservations.erase(key)
		return
	var reservation: Dictionary = _reservations.get(key, {})
	for goods_id: String in cost:
		if goods_id == "money":
			continue
		var consumed := int(cost[goods_id]) - int(reservation.get(goods_id, 0)) \
			if _reservations.has(key) else int(cost[goods_id])
		if consumed > 0:
			# Beim Zurückgeben darf das Lager kurz überlaufen (Undo muss exakt sein)
			_stock[goods_id] = get_stock(goods_id) + consumed
			stock_changed.emit(goods_id)
	_reservations.erase(key)
	reservations_changed.emit()
	var amount := int(cost.get("money", 0))
	if amount > 0:
		money += amount
		_book(amount, label, "refund")
		money_changed.emit(money)


# --- Speichern ---------------------------------------------------------------------------

func get_save_id() -> String:
	return SAVE_ID


func save_state() -> Dictionary:
	return {"money": money, "stock": _stock.duplicate(), "orders": _orders.duplicate(),
		"reservations": _reservations.duplicate(true), "ledger": _ledger.duplicate(true)}


func load_state(data: Dictionary) -> void:
	reset()
	money = int(data.get("money", START_MONEY))
	var stock: Dictionary = data.get("stock", {})
	for goods_id: String in stock:
		if has_goods(goods_id):
			_stock[goods_id] = int(stock[goods_id])
	var orders: Dictionary = data.get("orders", {})
	for goods_id: String in orders:
		_orders[goods_id] = bool(orders[goods_id])
	_reservations.clear()
	var reservations: Dictionary = data.get("reservations", {})
	for key: String in reservations:
		var goods := {}
		for goods_id: String in (reservations[key] as Dictionary):
			goods[goods_id] = int(reservations[key][goods_id])
		_reservations[key] = goods
	_ledger.clear()
	for entry: Variant in data.get("ledger", []):
		if entry is Dictionary:
			_ledger.append(entry)
	money_changed.emit(money)
	for goods in _goods:
		stock_changed.emit(goods.id)
	reservations_changed.emit()
	ledger_changed.emit()
	orders_changed.emit()


func _load_goods() -> void:
	var dir := DirAccess.open(GOODS_DIR)
	if dir == null:
		push_error("Economy: Ordner %s fehlt." % GOODS_DIR)
		return
	var files := dir.get_files()
	for file in files:
		var path := GOODS_DIR.path_join(file.trim_suffix(".remap"))
		if not path.ends_with(".tres"):
			continue
		var goods := load(path) as GoodsType
		if goods and not _by_id.has(goods.id):
			_goods.append(goods)
			_by_id[goods.id] = goods
	_goods.sort_custom(func(a: GoodsType, b: GoodsType) -> bool: return a.sort_order < b.sort_order)
