class_name Palette
extends RefCounted

const BACKGROUND := Color("0B0F1A")
const ICE := Color("7FC8F8")
const ORE := Color("F2A93B")
const ORE_BRIGHT := Color("FFE27A")
const DANGER := Color("FF5A36")
const HALO := Color("B8D8C0")
const SAFE := Color("FFD45C")
const OBOD_ACCENT := Color("C9A27A")
const MOON := Color(0.6, 0.6, 0.6)
const HULL := Color(0.85, 0.88, 0.92)
const HULL_SHADE := Color(0.6, 0.65, 0.72)
const SHADE_FACTOR := 0.35
const LIGHT_DIR := Vector2(-0.6, -0.8)

static func shade(c: Color) -> Color:
	return Color(c.r * SHADE_FACTOR, c.g * SHADE_FACTOR, c.b * SHADE_FACTOR, c.a)

static func lit_half(radius: float, n: int, light_dir: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a := -PI * 0.5 + PI * float(i) / float(n)
		pts.append(light_dir.rotated(a) * radius)
	return pts
