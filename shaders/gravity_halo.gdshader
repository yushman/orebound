shader_type canvas_item;

const int MAX_BODIES = 16;

uniform int moon_count = 0;
uniform vec2 rel[16];
uniform float outer[16];
uniform float halo_alpha = 0.25;
uniform int ring_count = 4;
uniform float ring_period = 2.0;
uniform float ring_px = 1.5;
uniform float ring_alpha = 0.5;
uniform vec4 halo_color : source_color = vec4(0.7, 0.9, 0.75, 1.0);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float a = 0.0;
	for (int i = 0; i < MAX_BODIES; i++) {
		if (i >= moon_count) {
			break;
		}
		float u = length(local - rel[i]) / outer[i];
		if (u >= 1.0) {
			continue;
		}
		float halo = halo_alpha * (1.0 - u) * (1.0 - u);
		float x = float(ring_count) * pow(u, 1.5);
		float f = fract(x + TIME / ring_period);
		float d = min(f, 1.0 - f);
		float w = max(fwidth(x), 1e-6);
		float line = 1.0 - smoothstep(0.5 * ring_px - 0.5, 0.5 * ring_px + 0.5, d / w);
		a = max(a, max(halo, ring_alpha * (1.0 - u) * line));
	}
	COLOR = vec4(halo_color.rgb, a);
}
