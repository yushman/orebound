class_name WarningEvents
extends RefCounted

const RESERVE_TEXTS := ["", "запас на пределе", "топлива не хватит на подъём"]


static func detect(prev: Dictionary, now: Dictionary) -> Array:
	var out := []
	var tow: float = WellGenerator.tiers().tow
	if prev.r >= tow and now.r < tow:
		if Tuning.ship.service_boat:
			out.append([&"boundary", "ниже границы: принудительный буксир через %d с" % ceili(Tuning.planet.violation_time)])
		else:
			out.append([&"boundary", "граница буксира: ниже буксир не придёт"])
	var edge: float = Tuning.field.atmosphere_edge
	if prev.r >= edge and now.r < edge:
		out.append([&"atmosphere", "атмосфера"])
	if now.reserve > prev.reserve:
		out.append([&"reserve", RESERVE_TEXTS[now.reserve]])
	if prev.hull - now.hull > now.atmo_loss + 1e-6:
		out.append([&"impact", "удар"])
	if prev.violation == "" and now.violation == "ceiling":
		out.append([&"ceiling", "потолок: буксир через %d с" % ceili(Tuning.planet.violation_time)])
	if prev.tow_left < 0.0 and now.tow_left >= 0.0:
		out.append([&"tow", "буксир вызван · через %d с" % ceili(now.tow_left)])
	if now.notice_left > prev.notice_left:
		out.append([&"tow_refused", now.notice])
	return out
