shader_type canvas_item;

uniform bool outline = false;
uniform vec4 outline_color : source_color = vec4(0.722, 0.847, 0.753, 1.0);
uniform float outline_px = 1.5;
// rim light in the type colour (type_tex, Layer3D type pass) inside the
// silhouette on the side away from the light; rim_dir points toward the
// light in texture UV (y-down)
uniform bool rim_on = false;
uniform vec2 rim_dir = vec2(-0.6, -0.8);
uniform sampler2D type_tex;
uniform float rim_px = 11.5;
uniform float rim_strength = 1.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (outline && c.a < 0.5) {
		float a = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.785398;
			a = max(a, texture(TEXTURE, UV + vec2(cos(ang), sin(ang)) * outline_px * TEXTURE_PIXEL_SIZE).a);
		}
		if (a >= 0.5) {
			c = vec4(outline_color.rgb, 1.0);
		}
	}
	if (rim_on && c.a >= 0.5) {
		vec4 t = texture(type_tex, UV);
		float d = 1.0;
		for (int i = 1; i <= 16; i++) {
			float f = float(i) / 16.0;
			if (d == 1.0 && texture(TEXTURE, UV - rim_dir * rim_px * f * TEXTURE_PIXEL_SIZE).a < 0.5) d = f;
		}
		if (t.a >= 0.5 && d < 1.0) c.rgb = mix(c.rgb, t.rgb, rim_strength * (1.0 - d));
	}
	COLOR = c * tint;
}
