class_name HoldCell
extends RefCounted

var type: StringName
var fill: float


func copy() -> HoldCell:
	var c := HoldCell.new()
	c.type = type
	c.fill = fill
	return c
