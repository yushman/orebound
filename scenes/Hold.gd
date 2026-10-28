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
		e += c.fill * Tuning.resources[c.type].energy
	return e


static func burn_order(cells: Array[HoldCell]) -> Array[HoldCell]:
	var order: Array[HoldCell] = []
	for type in [&"ice", &"fuel"]:
		for c in cells:
			if c.type == type and c.fill < 1.0:
				order.append(c)
		for c in cells:
			if c.type == type and c.fill >= 1.0:
				order.append(c)
	return order


static func drain(s: ShipState, amount: float) -> float:
	var order := burn_order(s.tank)
	var left := amount
	for c in order:
		if left <= 0.0:
			break
		var per: float = Tuning.resources[c.type].energy
		if per <= 0.0:
			continue
		var d := minf(left, c.fill * per)
		c.fill -= d / per
		left -= d
		if c.fill <= EPS:
			s.tank.erase(c)
	return amount - left


static func heaviest(s: ShipState) -> int:
	var best := -1
	var best_mass := -1.0
	for i in s.hold.size():
		var m: float = s.hold[i].fill * Tuning.resources[s.hold[i].type].mass
		if m > best_mass:
			best_mass = m
			best = i
	return best


static func effective_pick(s: ShipState) -> int:
	if s.jettison_pick < 0 or s.jettison_pick >= s.hold.size():
		return heaviest(s)
	return s.jettison_pick


static func next_pick(s: ShipState) -> int:
	if s.hold.is_empty():
		return s.jettison_pick
	return (effective_pick(s) + 1) % s.hold.size()


static func remove_at(s: ShipState, i: int) -> HoldCell:
	var c := s.hold[i]
	s.hold.remove_at(i)
	return c


static func _transfer_source(s: ShipState) -> int:
	var first := -1
	for i in s.hold.size():
		if s.hold[i].type != &"ice":
			continue
		if s.hold[i].fill < 1.0 - EPS:
			return i
		if first < 0:
			first = i
	return first


static func can_transfer(s: ShipState) -> bool:
	var i := _transfer_source(s)
	if i < 0:
		return false
	var f: float = s.hold[i].fill
	if Tuning.ship.refiner:
		return room(s, &"fuel") >= _refined(f)
	return used_volume(s.tank) + Tuning.resources[&"ice"].volume <= Tuning.ship.tank_capacity


static func transfer(s: ShipState) -> bool:
	if not can_transfer(s):
		return false
	var i := _transfer_source(s)
	var c := remove_at(s, i)
	if i < s.jettison_pick:
		s.jettison_pick -= 1
	elif i == s.jettison_pick:
		s.jettison_pick = -1
	if Tuning.ship.refiner:
		add(s, &"fuel", _refined(c.fill))
	else:
		s.tank.append(c)
	return true


static func _refined(fill: float) -> float:
	return fill * Tuning.resources[&"ice"].energy / Tuning.resources[&"fuel"].energy
