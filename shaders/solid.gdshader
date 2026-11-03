shader_type spatial;
render_mode unshaded, cull_back;

#include "res://shaders/style.gdshaderinc"

uniform vec3 light = vec3(-0.6, 0.8, 0.35);
uniform float shade_factor = 0.35;
uniform bool edges = false;
uniform vec4 edge_color : source_color = vec4(0.722, 0.847, 0.753, 1.0);
uniform float edge_px = 1.0;
// false keeps the vertex colour as is (rocks, pieces, containers), true converts sRGB (ship)
uniform bool srgb_albedo = false;
// ore look (asteroids, large pieces): CUSTOM0.w flags inclusion facets
uniform bool incl_on = false;
uniform vec3 incl_grey = vec3(0.5);
uniform float incl_grey_mix = 1.0;
uniform float incl_boost = 1.4;
uniform float incl_unshadow = 0.5;
uniform float piece_boost = 1.0;
uniform float dark_strength = 0.0;
uniform vec3 dark_color = vec3(0.0);
uniform float dark_px = 2.0;
uniform bool dark_lit_only = false;
// cracks (beam target only): object-anchored Voronoi borders, kept per
// cell pair by crack_branches, revealed within crack_ratio * crack_reach *
// crack_radius of crack_origin (object xy); constant width in screen px.
uniform float crack_ratio = 0.0;
uniform vec2 crack_origin = vec2(0.0);
uniform float crack_radius = 100.0;
uniform float crack_seed = 0.0;
uniform float crack_reach = 0.9;
uniform float crack_cells = 5.0;
uniform float crack_branches = 0.45;
uniform float crack_jag = 0.35;
uniform float crack_px = 1.5;
uniform float crack_glow = 3.0;
uniform float crack_glow_alpha = 0.5;
uniform float crack_boost = 1.6;

varying vec3 bary;
varying float inclusion;
varying vec3 world_normal;
varying vec2 local_xy;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

vec2 crack_hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float crack_hash1(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float crack_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(crack_hash1(i), crack_hash1(i + vec2(1.0, 0.0)), f.x), mix(crack_hash1(i + vec2(0.0, 1.0)), crack_hash1(i + vec2(1.0, 1.0)), f.x), f.y);
}

// x: distance to the nearest cell border (cell units), y: hash of the two
// cells sharing that border, z: hash of the nearest cell.
vec3 crack_voronoi(vec2 x) {
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + crack_hash2(n + g) - f;
			float d = dot(r, r);
			if (d < md) {
				md = d;
				mr = r;
				mg = g;
			}
		}
	}
	md = 8.0;
	vec2 pg = mg;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + crack_hash2(n + g) - f;
			if (dot(mr - r, mr - r) > 1e-5) {
				float d = dot(0.5 * (mr + r), normalize(r - mr));
				if (d < md) {
					md = d;
					pg = g;
				}
			}
		}
	}
	vec2 a = n + mg;
	vec2 b = n + pg;
	float h = fract(sin(dot(a + b, vec2(12.9898, 78.233)) + dot(abs(a - b), vec2(39.346, 11.135))) * 43758.5453);
	return vec3(md, h, crack_hash1(a));
}

// Crack line alpha at object point `p` (world units), `upp` world units per px.
float crack_alpha(vec2 p, float upp) {
	float cell = crack_radius / crack_cells;
	vec2 x = p / cell + vec2(crack_seed, crack_seed * 0.618);
	x += crack_jag * (vec2(crack_noise(x * 3.0), crack_noise(x * 3.0 + 17.0)) - 0.5);
	vec3 v = crack_voronoi(x);
	if (v.y > crack_branches) return 0.0;
	float front = crack_ratio * crack_reach * crack_radius * (0.7 + 0.3 * v.z);
	float d = distance(p, crack_origin);
	if (d >= front) return 0.0;
	float t = d / front;
	float px = v.x * cell / upp;
	float w = 0.5 * crack_px * mix(1.0, 0.4, t);
	float core = 1.0 - smoothstep(w - 0.5, w + 0.5, px);
	float glow = crack_glow > 0.0 ? crack_glow_alpha * exp(-max(px - w, 0.0) / crack_glow) : 0.0;
	return max(core, glow) * (1.0 - smoothstep(0.85, 1.0, t));
}

void vertex() {
	bary = vec3(UV, UV2.x);
	inclusion = CUSTOM0.w;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
	local_xy = VERTEX.xy;
}

void fragment() {
	vec3 lit = srgb_albedo ? to_linear(COLOR.rgb) : COLOR.rgb;
	bool incl = incl_on && inclusion > 0.5;
	if (incl_on && !incl) lit = mix(lit, incl_grey, incl_grey_mix);
	float k0 = max(dot(normalize(world_normal), normalize(light)), 0.0);
	float k = k0;
	if (incl) {
		lit *= incl_boost;
		k = mix(k, 1.0, incl_unshadow);
	}
	lit *= piece_boost;
	vec3 c = style_tone(lit * shade_factor, lit, k, FRAGCOORD.xy, local_xy);
	if (dark_strength > 0.0) {
		vec3 a = clamp(bary / max(fwidth(bary) * dark_px, vec3(1e-5)), 0.0, 1.0);
		float side = dark_lit_only ? k0 : 1.0;
		c = mix(c, dark_color, dark_strength * side * (1.0 - min(a.x, min(a.y, a.z))));
	}
	if (crack_ratio > 0.0) {
		float upp = max(sqrt(abs(dFdx(local_xy.x) * dFdy(local_xy.y) - dFdx(local_xy.y) * dFdy(local_xy.x))), 1e-6);
		c = mix(c, COLOR.rgb * crack_boost, crack_alpha(local_xy, upp));
	}
	if (edges) {
		vec3 a = clamp(bary / max(fwidth(bary) * edge_px, vec3(1e-5)), 0.0, 1.0);
		c = mix(edge_color.rgb, c, min(a.x, min(a.y, a.z)));
	}
	ALBEDO = c;
}
