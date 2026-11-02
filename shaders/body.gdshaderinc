// Body of body.gdshader (planet) and moon.gdshader (CRATERS).
#include "res://shaders/style.gdshaderinc"

uniform vec4 lit_color : source_color = vec4(0.788, 0.635, 0.478, 1.0);
uniform vec4 dark_color : source_color = vec4(0.276, 0.222, 0.167, 1.0);
uniform vec3 light = vec3(-0.6, -0.8, 0.35);
uniform float radius = 12.0;
uniform float seed = 0.0;
uniform float noise_amount = 0.08;
uniform bool outline = false;
uniform vec4 outline_color : source_color = vec4(0.722, 0.847, 0.753, 1.0);
uniform float outline_px = 1.5;
#ifdef CRATERS
// Bump-mapped Voronoi craters on the unit sphere at three cell sizes
// (fractions of the radius), seeded by `seed`; a scale fades out while its
// narrowest rim (0.075 of the cell) is under 2 px.
uniform vec3 crater_scales = vec3(0.2, 0.08, 0.03);
uniform float crater_density = 0.6;
uniform float crater_depth = 0.25;
uniform float crater_rim = 0.08;
uniform float crater_bump = 1.0;
#endif

varying vec2 local;

void vertex() {
	local = VERTEX / radius;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419) + seed);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

#ifdef CRATERS
vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453);
}

// Gradient of the crater field of cell size s: bowl (x^2 - 1) * depth
// inside, raised rim around x = 1, heights scaled by the crater radius.
vec3 craters(vec3 p, float s) {
	vec3 q = p / s;
	vec3 cell = floor(q);
	vec3 g = vec3(0.0);
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			for (int k = -1; k <= 1; k++) {
				vec3 c = cell + vec3(float(i), float(j), float(k));
				vec3 r = hash3(c);
				if (r.x > crater_density) {
					continue;
				}
				vec3 d = q - c - hash3(c + 13.7);
				float x = length(d) / mix(0.25, 0.5, r.y);
				float bowl = x < 1.0 ? 2.0 * x * crater_depth : 0.0;
				float rim = crater_rim * exp(-pow((x - 1.0) / 0.3, 2.0)) * -2.0 * (x - 1.0) / 0.09;
				g += (bowl + rim) * d / max(length(d), 1e-6);
			}
		}
	}
	return g;
}
#endif

void fragment() {
	vec3 n = vec3(local, sqrt(max(1.0 - dot(local, local), 0.0)));
	vec3 l = normalize(light);
#ifdef CRATERS
	float upp = max(max(length(dFdx(n)), length(dFdy(n))), 1e-6);
	vec3 p = n + seed * vec3(101.3, 57.1, 33.7);
	vec3 g = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float w = smoothstep(1.0, 2.0, 0.075 * crater_scales[i] / upp);
		if (w > 0.0) {
			g += w * craters(p, crater_scales[i]);
		}
	}
	float k = dot(normalize(n - crater_bump * (g - n * dot(n, g))), l);
#else
	float k = dot(n, l);
#endif
	float lit = smoothstep(-0.1, 0.2, k) * mix(0.8, 1.0, clamp(k, 0.0, 1.0));
	vec3 c = style_tone(dark_color.rgb, lit_color.rgb, lit, FRAGCOORD.xy, local);
	c *= 1.0 + noise_amount * (fbm(n * 3.0 + seed * 7.0) - 0.5) * 2.0;
	float r = length(local);
	if (outline && r > 1.0 - fwidth(r) * outline_px) {
		c = outline_color.rgb;
	}
	COLOR = vec4(c, 1.0);
}
