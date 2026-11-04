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
## Moon archetypes (grey, ice, basalt, rust), indexed by the generator's
## `picture["archetypes"]`. lit: lit colour, alt: blotch colour, craters:
## crater density multiplier, maria: coverage multiplier, rays: ray crater
## count, lineae: crack strength, blotch: albedo blotch strength.
const MOON_ARCHETYPES := [
	{"lit": Palette.MOON, "alt": Palette.MOON, "craters": 1.0, "maria": 1.0, "rays": 2, "lineae": 0.0, "blotch": 0.0},
	{"lit": Palette.MOON_ICE, "alt": Palette.MOON_ICE, "craters": 0.35, "maria": 0.0, "rays": 1, "lineae": 0.6, "blotch": 0.0},
	{"lit": Palette.MOON_BASALT, "alt": Palette.MOON_BASALT, "craters": 0.8, "maria": 2.0, "rays": 1, "lineae": 0.0, "blotch": 0.0},
	{"lit": Palette.MOON_RUST, "alt": Palette.MOON_RUST_ALT, "craters": 0.6, "maria": 0.3, "rays": 0, "lineae": 0.0, "blotch": 0.6},
]
const MOON_BLOTCH_SCALE := 2.5
const MOON_BLOTCH_DARK := 0.3
const MOON_LINEAE_SCALE := 3.0
const MOON_LINEAE_PX := 1.2
const MOON_LINEAE_DARK := 0.5
const MOON_LINEAE_BRIGHT := 0.35
const MOON_MARIA_SCALE := 1.6
const MOON_MARIA_COVERAGE := 0.35
const MOON_MARIA_DARKNESS := 0.35
const MOON_MARIA_SOFTNESS := 0.05
const MOON_MARIA_SUPPRESS := 0.85
const MOON_RAY_CRATER_SIZE := 0.08
const MOON_RAY_LENGTH := 0.5
const MOON_RAY_RAYS := 12
const MOON_RAY_WIDTH := 0.06
const MOON_RAY_BRIGHTNESS := 0.5
## Spin about a tilted screen-up axis: rad/s, per-moon speed spread (+- share),
## axis tilt toward the viewer (rad).
const MOON_SPIN_SPEED := 0.08
const MOON_SPIN_VARIATION := 0.5
const MOON_SPIN_TILT := 0.4
## Earthshine on the dark side: strength, falloff exponent, z of the planet
## direction (toward the viewer).
const MOON_EARTHSHINE_STRENGTH := 0.12
const MOON_EARTHSHINE_FALLOFF := 1.5
const MOON_EARTHSHINE_ELEVATION := 0.3
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
## Planet (`planet.gdshader`, `apply_planet`). Detail: albedo octaves from
## DETAIL_MAX down to DETAIL_MIN world units, size ratio between octaves,
## albedo variation per octave (+-), amplitude ratio coarse -> fine, 0 smooth
## .. 1 ridged, an octave fades in while its cell grows over FADE_PX px.
const PLANET_DETAIL_MAX := 20000.0
const PLANET_DETAIL_MIN := 200.0
const PLANET_DETAIL_LACUNARITY := 2.0
const PLANET_DETAIL_ALBEDO := 0.06
const PLANET_DETAIL_GAIN := 0.85
const PLANET_DETAIL_RIDGE := 0.5
const PLANET_DETAIL_FADE_PX := Vector2(2.0, 6.0)
## Night-side lava cracks: coarse and fine cell (world units), fine width and
## brightness share, core width and glow falloff (px), glow, intensity, share
## of the network that glows, night weight (1 - lit)^pow, pulse amount and
## speed (rad/s of game time), a crack scale fades out under FADE_PX cell px.
const PLANET_LAVA_SIZE := 2500.0
const PLANET_LAVA_SIZE_FINE := 400.0
const PLANET_LAVA_FINE := 0.6
const PLANET_LAVA_WIDTH_PX := 1.5
const PLANET_LAVA_GLOW_PX := 6.0
const PLANET_LAVA_GLOW := 0.35
const PLANET_LAVA_INTENSITY := 1.0
const PLANET_LAVA_DENSITY := 0.6
const PLANET_LAVA_NIGHT_POW := 2.0
const PLANET_LAVA_PULSE := 0.3
const PLANET_LAVA_PULSE_SPEED := 1.5
const PLANET_LAVA_FADE_PX := 12.0
## Limb haze: strength, width inside / outside the edge (world units),
## minimum width (px), exponent of the limb's cosine to the light, extension
## past the terminator.
const PLANET_HAZE_STRENGTH := 0.5
const PLANET_HAZE_IN := 600.0
const PLANET_HAZE_OUT := 300.0
const PLANET_HAZE_PX := 2.0
const PLANET_HAZE_LIT_POW := 1.5
const PLANET_HAZE_WRAP := 0.2


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


static func apply_planet(m: ShaderMaterial) -> void:
	m.set_shader_parameter("detail_albedo", PLANET_DETAIL_ALBEDO)
	m.set_shader_parameter("detail_gain", PLANET_DETAIL_GAIN)
	m.set_shader_parameter("detail_ridge", PLANET_DETAIL_RIDGE)
	m.set_shader_parameter("fade_px", PLANET_DETAIL_FADE_PX)
	m.set_shader_parameter("lava", PLANET_LAVA_INTENSITY)
	m.set_shader_parameter("lava_color", Palette.LAVA)
	m.set_shader_parameter("lava_width_px", PLANET_LAVA_WIDTH_PX)
	m.set_shader_parameter("lava_glow_px", PLANET_LAVA_GLOW_PX)
	m.set_shader_parameter("lava_glow", PLANET_LAVA_GLOW)
	m.set_shader_parameter("lava_density", PLANET_LAVA_DENSITY)
	m.set_shader_parameter("lava_night_pow", PLANET_LAVA_NIGHT_POW)
	m.set_shader_parameter("lava_pulse", PLANET_LAVA_PULSE)
	m.set_shader_parameter("lava_pulse_speed", PLANET_LAVA_PULSE_SPEED)
	m.set_shader_parameter("lava_fade_px", PLANET_LAVA_FADE_PX)
	m.set_shader_parameter("lava_fine", PLANET_LAVA_FINE)
	m.set_shader_parameter("haze", PLANET_HAZE_STRENGTH)
	m.set_shader_parameter("haze_color", Palette.HAZE)
	m.set_shader_parameter("haze_in", PLANET_HAZE_IN)
	m.set_shader_parameter("haze_out", PLANET_HAZE_OUT)
	m.set_shader_parameter("haze_px", PLANET_HAZE_PX)
	m.set_shader_parameter("haze_lit_pow", PLANET_HAZE_LIT_POW)
	m.set_shader_parameter("haze_wrap", PLANET_HAZE_WRAP)


static func apply_craters(m: ShaderMaterial) -> void:
	m.set_shader_parameter("crater_scales", MOON_CRATER_SCALES)
	m.set_shader_parameter("crater_density", MOON_CRATER_DENSITY)
	m.set_shader_parameter("crater_depth", MOON_CRATER_DEPTH)
	m.set_shader_parameter("crater_rim", MOON_CRATER_RIM)
	m.set_shader_parameter("crater_bump", MOON_CRATER_BUMP)


static func apply_moon(m: ShaderMaterial, archetype: int) -> void:
	var row: Dictionary = MOON_ARCHETYPES[archetype] if archetype >= 0 and archetype < MOON_ARCHETYPES.size() else MOON_ARCHETYPES[0]
	m.set_shader_parameter("lit_color", row["lit"])
	m.set_shader_parameter("dark_color", Palette.shade(row["lit"]))
	m.set_shader_parameter("crater_density", clampf(MOON_CRATER_DENSITY * row["craters"], 0.0, 1.0))
	m.set_shader_parameter("blotch", row["blotch"])
	m.set_shader_parameter("blotch_color", row["alt"])
	m.set_shader_parameter("blotch_scale", MOON_BLOTCH_SCALE)
	m.set_shader_parameter("blotch_dark", MOON_BLOTCH_DARK)
	m.set_shader_parameter("lineae", row["lineae"])
	m.set_shader_parameter("lineae_scale", MOON_LINEAE_SCALE)
	m.set_shader_parameter("lineae_px", MOON_LINEAE_PX)
	m.set_shader_parameter("lineae_dark", MOON_LINEAE_DARK)
	m.set_shader_parameter("lineae_bright", MOON_LINEAE_BRIGHT)
	m.set_shader_parameter("maria_coverage", MOON_MARIA_COVERAGE * row["maria"])
	m.set_shader_parameter("maria_scale", MOON_MARIA_SCALE)
	m.set_shader_parameter("maria_darkness", MOON_MARIA_DARKNESS)
	m.set_shader_parameter("maria_softness", MOON_MARIA_SOFTNESS)
	m.set_shader_parameter("maria_suppress", MOON_MARIA_SUPPRESS)
	m.set_shader_parameter("ray_craters", row["rays"])
	m.set_shader_parameter("ray_crater_size", MOON_RAY_CRATER_SIZE)
	m.set_shader_parameter("ray_length", MOON_RAY_LENGTH)
	m.set_shader_parameter("ray_rays", MOON_RAY_RAYS)
	m.set_shader_parameter("ray_width", MOON_RAY_WIDTH)
	m.set_shader_parameter("ray_brightness", MOON_RAY_BRIGHTNESS)


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
