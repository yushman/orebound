shader_type canvas_item;

uniform vec2 cam;
uniform int seed;
uniform float cell0 = 512.0;
uniform int per_cell = 1;
uniform float star_px = 1.5;
uniform vec3 weights = vec3(1.0, 0.0, 0.0);
uniform vec4 star_color : source_color = vec4(0.608, 0.659, 0.769, 1.0);

varying vec2 local;

void vertex() {
	local = VERTEX - cam;
}

uint star_hash(ivec2 cell, uint base) {
	uint h = uint(cell.x) * 374761393u + uint(cell.y) * 668265263u + base;
	h = (h ^ (h >> 15u)) * 2246822519u;
	h = (h ^ (h >> 13u)) * 3266489917u;
	return h ^ (h >> 16u);
}

void fragment() {
	vec2 world = cam + local;
	float px = max(length(vec2(fwidth(world.x), fwidth(world.y))), 1e-6);
	float a = 0.0;
	float c = cell0;
	for (int i = 0; i < 3; i++) {
		float w = i == 0 ? weights.x : (i == 1 ? weights.y : weights.z);
		if (w > 0.001) {
			ivec2 cell = ivec2(floor(world / c));
			for (int k = 0; k < per_cell; k++) {
				uint base = uint(seed) + uint(i) * 2654435761u + uint(k) * 40503u;
				uint h = star_hash(cell, base);
				vec2 star = (vec2(cell) + vec2(float(h & 0xFFFFu), float((h >> 16u) & 0xFFFFu)) / 65536.0) * c;
				float d = length(world - star) / px;
				float disc = 1.0 - smoothstep(star_px * 0.5 - 0.5, star_px * 0.5 + 0.5, d);
				uint b = star_hash(cell, base + 1013904223u);
				float bright = 0.35 + 0.325 * float(b % 3u);
				a += w * bright * disc;
			}
		}
		c *= 8.0;
	}
	COLOR = vec4(star_color.rgb, clamp(a, 0.0, 1.0));
}
