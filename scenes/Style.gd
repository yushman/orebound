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
