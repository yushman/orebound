class_name Layer3D
extends SubViewport
## Transparent 3D layer blitted into the 2D canvas by its owner, so it keeps
## the owner's draw order. The orthographic camera mirrors the 2D canvas
## transform; 3D space is camera-relative (origin = screen centre in world),
## world y-down maps to 3D y-up, +Z points at the viewer. Lighting is done by
## `shaders/solid.gdshader` (unshaded), the owner blits with `blit_material`.
## With the outline on, a full-screen quad (`depth_edges.gdshader`) adds
## lines at depth steps where objects of the layer overlap.

const CAMERA_Z := 1000.0
const SOLID := preload("res://shaders/solid.gdshader")
const SILHOUETTE := preload("res://shaders/silhouette.gdshader")
const DEPTH_EDGES := preload("res://shaders/depth_edges.gdshader")

var camera := Camera3D.new()
var origin := Vector2.ZERO
var solid := ShaderMaterial.new()
var blit_material := ShaderMaterial.new()
var _edges := MeshInstance3D.new()
var _edge_material := ShaderMaterial.new()


func _init() -> void:
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	own_world_3d = true
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 1.0
	camera.far = CAMERA_Z * 2.0
	camera.position = Vector3(0.0, 0.0, CAMERA_Z)
	add_child(camera)
	solid.shader = SOLID
	solid.set_shader_parameter("light", light_3d())
	solid.set_shader_parameter("shade_factor", Palette.SHADE_FACTOR)
	blit_material.shader = SILHOUETTE
	_edge_material.shader = DEPTH_EDGES
	_edge_material.set_shader_parameter("far_dist", camera.far)
	_edges.mesh = QuadMesh.new()
	_edges.material_override = _edge_material
	_edges.extra_cull_margin = 16384.0
	_edges.visible = false
	add_child(_edges)


## Direction toward the light in layer space (Palette.LIGHT_DIR is y-down).
static func light_3d() -> Vector3:
	return Vector3(Palette.LIGHT_DIR.x, -Palette.LIGHT_DIR.y, Palette.LIGHT_ELEVATION).normalized()


func to_3d(p: Vector2, z := 0.0) -> Vector3:
	return Vector3(p.x - origin.x, origin.y - p.y, z)


## Call from the owner's _draw before placing 3D nodes: matches the camera
## to the canvas the owner draws into and pushes the current style.
func sync(canvas: CanvasItem) -> void:
	var vp := canvas.get_viewport()
	var view := vp.get_visible_rect().size
	var xf := vp.get_canvas_transform()
	var win := vp.get_window()
	var px := float(win.size.y) / view.y if win != null and win.size.y > 0 else 1.0
	size = Vector2i((view * px).round()).max(Vector2i.ONE)
	origin = xf.affine_inverse() * (view * 0.5)
	camera.size = view.y / xf.get_scale().x
	camera.rotation = Vector3(0.0, 0.0, xf.get_rotation())
	Style.apply(solid)
	Style.apply(blit_material)
	Style.apply(_edge_material)
	_edges.visible = Tuning.view.style_outline


## Draws the layer texture over the whole screen from the owner's _draw; the
## owner's `material` must be `blit_material` for the silhouette outline.
func blit(canvas: CanvasItem) -> void:
	var vp := canvas.get_viewport()
	canvas.draw_set_transform_matrix(canvas.get_global_transform().affine_inverse() * vp.get_canvas_transform().affine_inverse())
	canvas.draw_texture_rect(get_texture(), Rect2(Vector2.ZERO, vp.get_visible_rect().size), false)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
