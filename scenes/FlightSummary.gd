class_name FlightSummary
extends RefCounted


static func build(state: ShipState, outcome: String, flight_time: float, tow := {}, real_time := 0.0) -> Dictionary:
	var cargo := {}
	for cell in state.hold:
		cargo[cell.type] = cargo.get(cell.type, 0.0) + cell.fill * Tuning.resources[cell.type].mass
	return {
		"outcome": outcome,
		"cargo": cargo,
		"cargo_lost": outcome == "crashed",
		"fuel": {
			"engine": state.fuel_engine,
			"boost": state.fuel_boost,
			"soft_brake": state.fuel_soft_brake,
			"sync": state.fuel_sync,
		},
		"time": flight_time,
		"real_time": real_time,
		"seized": tow.get("seized", {}),
		"seized_share": tow.get("share", 0.0),
		"tow_kind": tow.get("kind", "") if outcome == "towed" else "",
	}
