class_name Hold
extends RefCounted

const EPS := 1e-6


static func mass(s: ShipState) -> float:
	var m: float = Tuning.ship.hull_mass
	for cells in [s.hold, s.tank]:
		for c in cells:
			m += c.fill * Tuning.resources[c.type].mass
	return m


static func used_volume(cells: Array[HoldCell]) -> float:
	var v := 0.0
	for c in cells:
		v += Tuning.resources[c.type].volume
	return v


static func add(s: ShipState, type: StringName, amount: float) -> float:
	var p: ShipParams = Tuning.ship
	var to_tank: bool = type == &"fuel"
	var cells: Array[HoldCell] = s.tank if to_tank else s.hold
	var capacity: float = p.tank_capacity if to_tank else p.hold_capacity
	var volume: float = Tuning.resources[type].volume
	var left := amount
	for i in range(cells.size() - 1, -1, -1):
		if cells[i].type == type and cells[i].fill < 1.0 - EPS:
			var d := minf(left, 1.0 - cells[i].fill)
			cells[i].fill += d
			if cells[i].fill > 1.0 - EPS:
				cells[i].fill = 1.0
			left -= d
			break
	while left > EPS and used_volume(cells) + volume <= capacity:
		var c := HoldCell.new()
		c.type = type
		c.fill = minf(left, 1.0)
		cells.append(c)
		left -= c.fill
	return amount - left


static func room(s: ShipState, type: StringName) -> float:
	var p: ShipParams = Tuning.ship
	var cells: Array[HoldCell] = s.tank if type == &"fuel" else s.hold
	var capacity: float = p.tank_capacity if type == &"fuel" else p.hold_capacity
	var volume: float = Tuning.resources[type].volume
	var free := 0.0
	for i in range(cells.size() - 1, -1, -1):
		if cells[i].type == type and cells[i].fill < 1.0 - EPS:
			free = 1.0 - cells[i].fill
			break
	if volume > 0.0:
		free += maxf(floorf((capacity - used_volume(cells)) / volume + EPS), 0.0)
	return free


static func energy(s: ShipState) -> float:
	var e := 0.0
	for c in s.tank:
		if c.type == &"fuel":
			e += c.fill * Tuning.resources[c.type].energy
	return e


static func drain(s: ShipState, amount: float) -> float:
	var per: float = Tuning.resources[&"fuel"].energy
	if per <= 0.0:
		return 0.0
	var order: Array[HoldCell] = []
	for c in s.tank:
		if c.type == &"fuel" and c.fill < 1.0:
			order.append(c)
	for c in s.tank:
		if c.type == &"fuel" and c.fill >= 1.0:
			order.append(c)
	var left := amount
	for c in order:
		if left <= 0.0:
			break
		var d := minf(left, c.fill * per)
		c.fill -= d / per
		left -= d
		if c.fill <= EPS:
			s.tank.erase(c)
	return amount - left
