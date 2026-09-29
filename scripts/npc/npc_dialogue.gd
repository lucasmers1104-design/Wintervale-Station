## Was Bewohner sagen, wenn man sie anspricht (Taste E).
##
## Ein Gespräch besteht aus einer kleinen Folge von Sätzen: Begrüßung (passend
## zur Tageszeit, beim ersten Mal mit Vorstellung), dann ein Thema aus dem
## Moment – das laufende Fest, das Wetter, die Jahreszeit, der eigene Zug, was
## man gerade vorhat – und ein freundlicher Abschied. Die Auswahl ist zufällig,
## aber je Bewohner und Tag stabil (dieselbe Person erzählt nicht ständig anderes).
class_name NpcDialogue
extends RefCounted


## Sätze für ein Gespräch mit [param npc].
static func conversation(npc: Npc, met_before: bool) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(npc.name) + WorldClock.day * 7919 + int(WorldClock.time_of_day * 2.0)
	var lines: Array[String] = []
	lines.append(_greeting(npc, met_before, rng))
	var topics := _topics(npc, rng)
	for i in mini(2, topics.size()):
		lines.append(topics[i])
	lines.append(_pick(rng, _farewells(npc)))
	return lines


static func _greeting(npc: Npc, met_before: bool, rng: RandomNumberGenerator) -> String:
	var hour := WorldClock.time_of_day
	var hello := "Guten Morgen" if hour < 10.5 else ("Guten Tag" if hour < 17.5 else "Guten Abend")
	if is_child(npc):
		hello = _pick(rng, ["Hallo!", "Hi!", "Huhu!"])
		if npc.profile and not met_before:
			return "%s Ich bin %s. Und du?" % [hello, first_name(npc)]
		return "%s Schön, dass du da bist!" % hello
	if npc.has_meta(&"festival_guest"):
		return _pick(rng, ["%s! Ich bin extra aus dem Tal zum Fest gekommen." % hello,
			"%s! Was für ein schönes Fest – das hat sich herumgesprochen!" % hello])
	if npc.profile == null:
		return _pick(rng, ["%s! Ich bin nur auf der Durchreise." % hello, "%s. Hübsches Dörfchen haben Sie hier!" % hello,
			"%s – ist das hier Wintervale? Wie gemütlich!" % hello])
	if not met_before:
		return "%s! Ich bin %s, ich wohne bei den %ss." % [hello, npc.display_name, npc.profile.home_name] \
			if npc.profile.home_name != "" else "%s! Ich bin %s." % [hello, npc.display_name]
	return _pick(rng, ["%s! Schön, Sie wiederzusehen." % hello, "Ach, hallo! Da sind Sie ja wieder.",
		"%s! Na, wie geht's?" % hello])


## Themen, das Wichtigste zuerst (Fest, eigener Plan, dann Wetter und Jahreszeit).
static func _topics(npc: Npc, rng: RandomNumberGenerator) -> Array[String]:
	var topics: Array[String] = []
	var festival := FestivalDirector.find(npc.get_tree())
	var child := is_child(npc)
	if festival and festival.get_active_id() != "":
		topics.append(_pick(rng, festival_lines(festival, child)))
	var plan := _plan_line(npc)
	if plan != "":
		topics.append(plan)
	var pool: Array[String] = []
	pool.append_array(_weather_lines(npc, child))
	pool.append_array(_season_lines(child))
	pool.append_array(_village_lines(npc, child))
	# Mischen, ohne Doppelungen
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	for line in pool:
		if not topics.has(line):
			topics.append(line)
	return topics


static func festival_lines(festival: FestivalDirector, child: bool) -> Array[String]:
	var winter := festival.get_active_id() == FestivalDirector.CHRISTMAS
	var open := festival.is_open()
	var lines: Array[String] = []
	var highlight := TimetableEntry.format_time(festival.get_highlight_hour())
	if winter:
		if child:
			lines.append_array(["Ich will nochmal Karussell fahren! Das mit dem weißen Pferd!",
				"Weißt du, dass die Lebkuchenherzen nach Zimt riechen? Ich hab schon zwei gegessen!",
				"Um %s gehen am großen Baum die Lichter an. Das ist das Schönste am ganzen Winter!" % highlight])
		else:
			lines.append_array(["Waren Sie schon auf dem Weihnachtsmarkt? Der Glühwein bei der roten Bude ist himmlisch.",
				"Jeden Abend um %s leuchtet der große Baum auf. Das ganze Dorf kommt dann zusammen." % highlight,
				"Die Maronen duften bis zum Bahnhof herüber – da kann man einfach nicht vorbeigehen.",
				"Mit dem Sonderzug kommen jetzt sogar Leute aus dem Tal zu unserem Markt. Wer hätte das gedacht!"])
			if not open:
				lines.append("Der Markt öffnet erst um %s. Ich freu mich schon den ganzen Tag drauf." % \
					TimetableEntry.format_time(festival.get_open_hour()))
	else:
		if child:
			lines.append_array(["Heute Abend ist Laternenumzug! Meine Laterne ist ein Mond – selbst gebastelt!",
				"Hast du die riesigen Kürbisse gesehen? Einer ist größer als ich!",
				"Wenn die Musik spielt, tanzen alle im Kreis. Das ist lustig!"])
		else:
			lines.append_array(["Das Herbstfest ist das gemütlichste Wochenende im ganzen Jahr.",
				"Probieren Sie unbedingt den Apfelmost – die Äpfel sind von der Wiese hinterm See.",
				"Um %s ziehen die Kinder mit ihren Laternen durchs Dorf. Da wird mir immer ganz warm ums Herz." % highlight,
				"Das Lagerfeuer brennt bis in den Abend. Ein schöner Platz, um die Hände zu wärmen."])
	return lines


## Was der Bewohner gerade vorhat (eigener Zug, Heimweg, Fest …).
static func _plan_line(npc: Npc) -> String:
	match npc.state:
		Npc.State.AT_STATION:
			var routine := npc.get_routine()
			if routine and routine.activity == NpcRoutine.Activity.TRAVEL:
				return "Ich warte auf meinen Zug nach %s. Hoffentlich ist er pünktlich!" % routine.destination
			if npc.profile == null and npc.trip_destination != "":
				return "Ich fahre gleich weiter nach %s." % npc.trip_destination
			return "Ich schaue einfach gern den Zügen zu. Das beruhigt so schön."
		Npc.State.GOING_HOME:
			return "Jetzt geht's heim – der Ofen wartet schon." if not is_child(npc) else "Ich muss nach Hause, es gibt gleich Essen!"
		Npc.State.STROLLING:
			return "Ein kleiner Spaziergang tut gut. Die Luft ist heute so klar."
		Npc.State.FESTIVAL:
			return npc.get_festival_remark()
	return ""


static func _weather_lines(npc: Npc, child: bool) -> Array[String]:
	var weather := npc.get_tree().get_first_node_in_group(WeatherSystem.GROUP) as WeatherSystem
	if weather == null:
		return []
	match weather.current:
		WeatherSystem.Weather.HEAVY_SNOW:
			return ["So ein Schneetreiben! Da bleibt man am besten in der Nähe vom Ofen."] if not child \
				else ["Soooo viel Schnee! Morgen bauen wir einen Riesen-Schneemann!"]
		WeatherSystem.Weather.LIGHT_SNOW:
			return ["Ich mag es, wenn es so leise schneit. Dann ist das ganze Dorf ganz still."] if not child \
				else ["Ich fange Schneeflocken mit der Zunge!"]
		WeatherSystem.Weather.CLEAR_EVENING:
			return ["Was für ein klarer Abend. Nachher sieht man bestimmt jeden Stern."]
		WeatherSystem.Weather.RAIN:
			return ["Ein bisschen Regen schadet nicht – die Wiesen freuen sich."]
		WeatherSystem.Weather.FOG:
			return ["Bei dem Nebel hört man die Züge, bevor man sie sieht."]
		WeatherSystem.Weather.SUNNY:
			return ["Herrlich, diese Sonne! Da muss man einfach rausgehen."]
	return ["Ein bisschen grau heute. Aber gemütlich."]


static func _season_lines(child: bool) -> Array[String]:
	match Seasons.get_season():
		Seasons.Season.WINTER:
			return ["Der Winter ist hier die schönste Zeit. Alles glitzert."] if not child \
				else ["Mit dem Schlitten den Hügel runter ist das Beste überhaupt!"]
		Seasons.Season.SPRING:
			return ["Die ersten Blumen sind da! Endlich wird es wieder grün."]
		Seasons.Season.SUMMER:
			return ["Die langen Sommerabende sind einfach wunderbar. Hört man die Grillen?"]
		Seasons.Season.AUTUMN:
			return ["Die Bäume sehen aus wie angemalt. Gold und Rot, überall."]
	return []


static func _village_lines(npc: Npc, child: bool) -> Array[String]:
	if child:
		return ["Wenn ich groß bin, werde ich Lokführerin. Oder Lokführer. Oder beides!",
			"Der rote Zug ist der schnellste. Ich hab's genau gesehen!"]
	var lines: Array[String] = ["Seit die Bahn wieder fährt, ist hier richtig Leben im Dorf.",
		"Die Leute vom Güterbahnhof arbeiten so fleißig. Bald haben wir noch mehr Nachbarn.",
		"Ich kenne jeden Zug am Klang. Der Regionalexpress brummt ein bisschen tiefer."]
	if npc.profile == null:
		lines = ["Mein Zug hält nur kurz, aber ich komme bestimmt wieder.", "Man merkt, dass hier alle aufeinander achten."]
	return lines


static func _farewells(npc: Npc) -> Array[String]:
	if is_child(npc):
		return ["Tschüss! Bis später!", "Ich muss weiter – tschüüüss!"]
	return ["Einen schönen Tag noch!", "Machen Sie's gut – und ziehen Sie sich warm an!", "Bis bald im Dorf!",
		"Schön, dass wir geplaudert haben."]


static func is_child(npc: Npc) -> bool:
	return npc.model != null and npc.model.appearance != null and npc.model.appearance.height_scale < 0.85


static func first_name(npc: Npc) -> String:
	return npc.display_name.split(" ")[0] if npc.display_name != "" else "ich"


static func _pick(rng: RandomNumberGenerator, options: Array) -> String:
	return String(options[rng.randi() % options.size()]) if not options.is_empty() else ""
