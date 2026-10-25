extends Node2D
## Well view (D35): honest arcs of the planet surface, atmosphere edge and
## r = const orbits, read from Tuning.field on every draw (no cache). Never
## writes to flight state.

const HIGHLIGHT_ZOOM := 22.0

# Playtest-tunable stroke colors.
const SURFACE_COLOR := Color(0.75, 0.55, 0.35, 0.9)
const ATMOSPHERE_COLOR := Color(0.45, 0.75, 1.0, 0.35)
const ORBIT_COLOR := Color(1.0, 1.0, 1.0, 0.3)
const ORBIT_HIGHLIGHT_COLOR := Color(1.0, 1.0, 1.0, 0.8)
const CARRIER_ORBIT_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const CARRIER_MARKER_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const TOW_COLOR := Color(1.0, 0.85, 0.2, 0.7)
const CEILING_COLOR := Color(1.0, 0.25, 0.2, 0.7)
# Placeholder tier tints, bottom to top.
const TIER_COLORS: Array[Color] = [
	Color(0.9, 0.3, 0.2, 0.18),
	Color(0.95, 0.75, 0.2, 0.18),
	Color(0.3, 0.8, 0.4, 0.18),
	Color(0.3, 0.5, 0.95, 0.18),
]
# Stroke sizes are constant SCREEN pixels: world width = px * semantic zoom s.
const SURFACE_PX := 2.0
const ATMOSPHERE_PX := 1.5
const ORBIT_PX := 1.0
const ORBIT_HIGHLIGHT_PX := 2.5
const CARRIER_ORBIT_PX := 1.5
const CARRIER_MARKER_PX := 4.0
const TOW_PX := 2.0
const CEILING_PX := 2.0
# Segment count keeps the chord sagitta under ARC_SAGITTA world units.
const ARC_SAGITTA := 2.0
const MIN_SEGMENTS := 8
const MAX_SEGMENTS := 512
# Half extents of the base 1280x800 viewport; the world half extent is this
# divided by Camera2D.zoom (semantic N x zoom shows N x more world).
const VIEW_HALF := Vector2(640.0, 400.0)
const VIEW_MARGIN := 1.1


static func orbit_radii() -> Array[float]:
	var radii: Array[float] = [Tuning.field.carrier_orbit_radius]
	for b in Tuning.field.bodies:
		if b.parent == 0 and b.orbit_radius > 0.0:
			radii.append(b.orbit_radius)
	radii.sort()
	return radii


static func highlight_orbits(zoom: float) -> bool:
	return zoom >= HIGHLIGHT_ZOOM


## Orbit stroke style: the carrier band keeps its own, stronger style at any
## zoom; other orbits are regular, or highlighted when zoomed far out.
static func orbit_style(radius: float, highlight: bool) -> Dictionary:
	if radius == Tuning.field.carrier_orbit_radius:
		return {"color": CARRIER_ORBIT_COLOR, "px": CARRIER_ORBIT_PX}
	if highlight:
		return {"color": ORBIT_HIGHLIGHT_COLOR, "px": ORBIT_HIGHLIGHT_PX}
	return {"color": ORBIT_COLOR, "px": ORBIT_PX}


## Special boundary stroke style (own colors, distinct from orbit_style).
static func boundary_style(kind: String) -> Dictionary:
	match kind:
		"tow":
			return {"color": TOW_COLOR, "px": TOW_PX}
		"ceiling":
			return {"color": CEILING_COLOR, "px": CEILING_PX}
	return {"color": ATMOSPHERE_COLOR, "px": ATMOSPHERE_PX}


## Special boundary circles (atmosphere edge, tow, ceiling) at generator radii.
static func special_rings() -> Array:
	var t := WellGenerator.tiers()
	return [
		{"radius": Tuning.field.atmosphere_edge, "kind": "atmosphere"},
		{"radius": t["tow"], "kind": "tow"},
		{"radius": t["ceiling"], "kind": "ceiling"},
	]


## The 4 tier bands bottom to top on the generator boundaries.
static func tier_bands() -> Array:
	var b: Array = WellGenerator.tiers()["boundaries"]
	var bands := []
	for i in b.size() - 1:
		bands.append({"r_in": b[i], "r_out": b[i + 1], "color": TIER_COLORS[i]})
	return bands


## Tier band polygon: outer arc a0 -> a1, then inner arc a1 -> a0.
static func annulus_points(r_in: float, r_out: float, a0: float, a1: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var span := a1 - a0
	var n := _segments(r_out, absf(span))
	for i in n + 1:
		pts.append(Vector2.from_angle(a0 + span * i / n) * r_out)
	var m := _segments(r_in, absf(span))
	for i in m + 1:
		pts.append(Vector2.from_angle(a1 - span * i / m) * r_in)
	return pts


## World half extent visible through the viewport at a Camera2D.zoom value
## (zoom < 1 shows more world, so divide).
static func visible_half_extent(cam_zoom: float) -> float:
	return VIEW_HALF.length() / cam_zoom


## Semantic zoom s (s times more world per screen) from a Camera2D.zoom value.
static func semantic_zoom(cam_zoom: float) -> float:
	return 1.0 / cam_zoom


## World stroke size that renders as `px` screen pixels at semantic zoom s.
static func screen_px(px: float, s: float) -> float:
	return px if s <= 0.0 else px * s


## Carrier point (D35): the frame origin, read from Tuning on every call.
static func carrier_marker_pos() -> Vector2:
	return Vector2(Tuning.field.carrier_orbit_radius, 0.0)


func _ready() -> void:
	Tuning.preset_applied.connect(queue_redraw)


func _process(_delta: float) -> void:
	# The visible arc span moves with the camera.
	queue_redraw()


func _draw() -> void:
	var f: FieldParams = Tuning.field
	var s := semantic_zoom(_camera_zoom())
	for band: Dictionary in tier_bands():
		_draw_band(band["r_in"], band["r_out"], band["color"])
	_draw_ring(f.planet_surface_radius, SURFACE_COLOR, screen_px(SURFACE_PX, s))
	for ring: Dictionary in special_rings():
		var bs := boundary_style(ring["kind"])
		_draw_ring(ring["radius"], bs["color"], screen_px(bs["px"], s))
	var highlight := highlight_orbits(s)
	for r: float in orbit_radii():
		var style := orbit_style(r, highlight)
		_draw_ring(r, style["color"], screen_px(style["px"], s))
	draw_circle(carrier_marker_pos(), screen_px(CARRIER_MARKER_PX, s),
			CARRIER_MARKER_COLOR)


func _camera() -> Camera2D:
	var vp := get_viewport()
	return vp.get_camera_2d() if vp != null else null


func _camera_zoom() -> float:
	var cam := _camera()
	return cam.zoom.x if cam != null else 1.0


## Angular span (centered on the camera direction) of the circle of `radius`
## inside the visible disc of radius h around the camera; TAU = whole circle,
## 0 = nothing visible.
static func visible_span(cam_pos: Vector2, cam_zoom: float, radius: float) -> float:
	var d := cam_pos.length()
	var h := visible_half_extent(cam_zoom) * VIEW_MARGIN
	if d <= 0.0 or radius <= 0.0:
		return TAU
	var c := (radius * radius + d * d - h * h) / (2.0 * radius * d)
	if c <= -1.0:
		return TAU
	if c >= 1.0:
		return 0.0
	return 2.0 * acos(c)


static func band_span(cam_pos: Vector2, cam_zoom: float, r_in: float, r_out: float) -> float:
	var h := visible_half_extent(cam_zoom) * VIEW_MARGIN
	var r_near := clampf(sqrt(maxf(cam_pos.length_squared() - h * h, 0.0)), r_in, r_out)
	return maxf(visible_span(cam_pos, cam_zoom, r_near), maxf(visible_span(cam_pos, cam_zoom, r_in), visible_span(cam_pos, cam_zoom, r_out)))


static func band_polygons(r_in: float, r_out: float, mid: float, span: float) -> Array:
	if span >= TAU:
		return [annulus_points(r_in, r_out, mid - PI, mid), annulus_points(r_in, r_out, mid, mid + PI)]
	return [annulus_points(r_in, r_out, mid - span * 0.5, mid + span * 0.5)]


func _draw_band(r_in: float, r_out: float, color: Color) -> void:
	var cam := _camera()
	var span := TAU if cam == null else band_span(cam.position, cam.zoom.x, r_in, r_out)
	if span <= 0.0:
		return
	var mid: float = 0.0 if cam == null else cam.position.angle()
	for pts: PackedVector2Array in band_polygons(r_in, r_out, mid, span):
		draw_colored_polygon(pts, color)


func _draw_ring(radius: float, color: Color, width: float) -> void:
	var cam := _camera()
	var span := TAU if cam == null else visible_span(cam.position, cam.zoom.x, radius)
	if span >= TAU:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, _segments(radius, TAU), color, width)
		return
	if span <= 0.0:
		return
	var mid: float = cam.position.angle()
	draw_arc(Vector2.ZERO, radius, mid - span * 0.5, mid + span * 0.5,
			_segments(radius, span), color, width)


static func _segments(radius: float, span: float) -> int:
	var n := int(ceil(span * sqrt(radius / (2.0 * ARC_SAGITTA))))
	return clampi(n, MIN_SEGMENTS, MAX_SEGMENTS)
