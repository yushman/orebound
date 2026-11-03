class_name Style
extends RefCounted
## View-only stylization knobs shared by the body shader, the 3D solid
## shader and the 3D layer silhouette; switched from `Tuning.view.style_*`.

enum Shading { PLAIN, DITHER, HATCH }

const OUTLINE_PX := 1.5
const EDGE_PX := 1.0
const DITHER_PX := 2.0
const HATCH_PX := 5.0
const HATCH_ANGLE := 0.785398
## Depth-step outline: minimum step in world units, and the slope (world
## units of depth per world unit across) a single surface may have unlined.
const DEPTH_EDGE_MIN := 2.0
const DEPTH_EDGE_SLOPE := 4.0
## Moon craters (`moon.gdshader`): cell sizes as fractions of the moon
## radius, share of cells with a crater, bowl depth and rim height per
## crater radius, bump strength.
const MOON_CRATER_SCALES := Vector3(0.2, 0.08, 0.03)
const MOON_CRATER_DENSITY := 0.6
const MOON_CRATER_DEPTH := 0.25
const MOON_CRATER_RIM := 0.08
const MOON_CRATER_BUMP := 1.0
## Asteroid ore look (`apply_ore`, the `Layer3D` rim): inner dome ring
## vertices of decimated rocks, share of top facets that are ore inclusions
## and the chance an inclusion grows from a neighbour; the grey of the other
## facets, inclusion brightness and unshadowing; rim width in screen px and
## strength; facet edge darkening (lit side only).
const DOME_INNER_POINTS := 6
const INCLUSION_FRACTION := 0.2
const INCLUSION_CLUSTER := 0.5
const INCLUSION_GREY := Color("808080")
const INCLUSION_GREY_MIX := 1.0
const INCLUSION_BOOST := 1.4
const INCLUSION_UNSHADOW := 0.5
const PIECE_BOOST := 2.5
const RIM_PX := 11.5
const RIM_STRENGTH := 1.0
const EDGE_DARK_COLOR := Color("000000")
const EDGE_DARK_STRENGTH := 0.5
const EDGE_DARK_PX := 2.0
const EDGE_DARK_LIT_ONLY := true
## Sawing cracks on the beam target (`apply_crack`, `solid.gdshader`
## crack_*): front radius at ratio 1 as a fraction of the radius, Voronoi
## cells across the radius, share of cell borders kept, line warp in cell
## units, core width and glow falloff in screen px, glow opacity, type colour
## multiplier. Shake of the target: per-axis amplitude at ratio 1 in screen
## px, frequency at ratio 0+ and at ratio 1.
const CRACK_REACH := 0.9
const CRACK_CELLS := 5.0
const CRACK_BRANCHES := 0.45
const CRACK_JAG := 0.35
const CRACK_PX := 1.5
const CRACK_GLOW := 3.0
const CRACK_GLOW_ALPHA := 0.5
const CRACK_BOOST := 1.6
const SHAKE_PX_MAX := 3.0
const SHAKE_HZ_MIN := 6.0
const SHAKE_HZ_MAX := 24.0


static func apply(m: ShaderMaterial) -> void:
	var v: ViewParams = Tuning.view
	m.set_shader_parameter("shading", v.style_shading)
	m.set_shader_parameter("dither_px", DITHER_PX)
	m.set_shader_parameter("hatch_px", HATCH_PX)
	m.set_shader_parameter("hatch_angle", HATCH_ANGLE)
	m.set_shader_parameter("outline", v.style_outline)
	m.set_shader_parameter("outline_color", Palette.OUTLINE)
	m.set_shader_parameter("outline_px", OUTLINE_PX)
	m.set_shader_parameter("edges", v.style_outline and v.style_edges)
	m.set_shader_parameter("edge_color", Palette.OUTLINE)
	m.set_shader_parameter("edge_px", EDGE_PX)
	m.set_shader_parameter("depth_edge_min", DEPTH_EDGE_MIN)
	m.set_shader_parameter("depth_edge_slope", DEPTH_EDGE_SLOPE)


static func apply_craters(m: ShaderMaterial) -> void:
	m.set_shader_parameter("crater_scales", MOON_CRATER_SCALES)
	m.set_shader_parameter("crater_density", MOON_CRATER_DENSITY)
	m.set_shader_parameter("crater_depth", MOON_CRATER_DEPTH)
	m.set_shader_parameter("crater_rim", MOON_CRATER_RIM)
	m.set_shader_parameter("crater_bump", MOON_CRATER_BUMP)


static func apply_ore(m: ShaderMaterial) -> void:
	m.set_shader_parameter("incl_on", true)
	m.set_shader_parameter("incl_grey", _rgb(INCLUSION_GREY))
	m.set_shader_parameter("incl_grey_mix", INCLUSION_GREY_MIX)
	m.set_shader_parameter("incl_boost", INCLUSION_BOOST)
	m.set_shader_parameter("incl_unshadow", INCLUSION_UNSHADOW)
	m.set_shader_parameter("dark_strength", EDGE_DARK_STRENGTH)
	m.set_shader_parameter("dark_color", _rgb(EDGE_DARK_COLOR))
	m.set_shader_parameter("dark_px", EDGE_DARK_PX)
	m.set_shader_parameter("dark_lit_only", EDGE_DARK_LIT_ONLY)


static func apply_crack(m: ShaderMaterial) -> void:
	m.set_shader_parameter("crack_reach", CRACK_REACH)
	m.set_shader_parameter("crack_cells", CRACK_CELLS)
	m.set_shader_parameter("crack_branches", CRACK_BRANCHES)
	m.set_shader_parameter("crack_jag", CRACK_JAG)
	m.set_shader_parameter("crack_px", CRACK_PX)
	m.set_shader_parameter("crack_glow", CRACK_GLOW)
	m.set_shader_parameter("crack_glow_alpha", CRACK_GLOW_ALPHA)
	m.set_shader_parameter("crack_boost", CRACK_BOOST)


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
