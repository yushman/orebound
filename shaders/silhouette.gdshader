shader_type canvas_item;

uniform bool outline = false;
uniform vec4 outline_color : source_color = vec4(0.722, 0.847, 0.753, 1.0);
uniform float outline_px = 1.5;

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
	COLOR = c * tint;
}
