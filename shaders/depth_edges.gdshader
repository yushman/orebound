shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

// Full-screen pass inside a Layer3D: a line on the farther side of every
// depth step between objects (overlaps); the outer silhouette is drawn by
// silhouette.gdshader. Compatibility NDC z is -1..1.
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform vec4 outline_color : source_color = vec4(0.722, 0.847, 0.753, 1.0);
uniform float outline_px = 1.5;
uniform float depth_edge_min = 2.0;
uniform float depth_edge_slope = 4.0;
uniform float far_dist = 2000.0;

void vertex() {
	POSITION = vec4(VERTEX.xy * 2.0, 0.0, 1.0);
}

float dist(vec2 uv, mat4 inv) {
	vec4 v = inv * vec4(vec3(uv, texture(depth_tex, uv).r) * 2.0 - 1.0, 1.0);
	return -v.z / v.w;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = 0.0;
	float here = dist(SCREEN_UV, INV_PROJECTION_MATRIX);
	if (here < far_dist * 0.99) {
		// slopes of one surface stay under the threshold: it grows with
		// the world size of the sample step
		float upp = 2.0 / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
		float thr = max(depth_edge_min, depth_edge_slope * upp * outline_px);
		vec2 step_uv = outline_px / VIEWPORT_SIZE;
		float step_max = 0.0;
		bool by_background = false;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			float n = dist(SCREEN_UV + vec2(cos(ang), sin(ang)) * step_uv, INV_PROJECTION_MATRIX);
			step_max = max(step_max, here - n);
			// next to the background is the outer silhouette (drawn by the
			// blit); MSAA-resolved depth there mixes in the far plane
			by_background = by_background || n >= far_dist * 0.99;
		}
		if (step_max > thr && !by_background) {
			ALPHA = 1.0;
		}
	}
}
