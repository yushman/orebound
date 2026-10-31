class_name Tow
extends RefCounted


static func refusal(pos: Vector2) -> String:
	if pos.length() < WellGenerator.tiers()["tow"]:
		return "ниже границы буксира"
	return ""


static func fee(s: ShipState) -> float:
	var p: PlanetParams = Tuning.planet
	return p.tow_base + p.tow_markup * p.energy_price * Fuel.climb_energy(s.pos.length(), s.vel.length(), Hold.mass(s))


static func cargo_value(s: ShipState) -> float:
	var v := 0.0
	for c in s.hold:
		v += c.fill * Tuning.resources[c.type].price
	return v


static func seized_share(s: ShipState) -> float:
	var v := cargo_value(s)
	if v <= 0.0:
		return 0.0
	return minf(1.0, fee(s) / v)


static func pay(s: ShipState) -> Dictionary:
	var f := fee(s)
	var share := seized_share(s)
	var seized := {}
	var kept: Array[HoldCell] = []
	for c in s.hold:
		var taken := c.fill * share
		if taken > 0.0:
			seized[c.type] = seized.get(c.type, 0.0) + taken * Tuning.resources[c.type].mass
		c.fill *= 1.0 - share
		if c.fill > Hold.EPS:
			kept.append(c)
	s.hold = kept
	var drained := Hold.energy(s)
	s.tank = []
	return {"seized": seized, "share": share, "fee": f, "drained_energy": drained}
