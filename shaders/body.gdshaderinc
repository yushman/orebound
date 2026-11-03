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
// Moon look (Style.apply_moon, Body): albedo blotches, ice lineae, maria,
// ray craters, surface spin (identity = none) and earthshine.
uniform float blotch = 0.0;
uniform vec4 blotch_color : source_color = vec4(1.0);
uniform float blotch_scale = 2.5;
uniform float blotch_dark = 0.3;
uniform float lineae = 0.0;
uniform float lineae_scale = 3.0;
uniform float lineae_px = 1.2;
uniform float lineae_dark = 0.5;
uniform float lineae_bright = 0.35;
uniform float maria_coverage = 0.0;
uniform float maria_scale = 1.6;
uniform float maria_darkness = 0.35;
uniform float maria_softness = 0.05;
uniform float maria_suppress = 0.85;
uniform int ray_craters = 0;
uniform float ray_crater_size = 0.08;
uniform float ray_length = 0.5;
uniform int ray_rays = 12;
uniform float ray_width = 0.06;
uniform float ray_brightness = 0.5;
uniform mat3 spin = mat3(1.0);
uniform float earth_strength = 0.0;
uniform vec4 earth_color : source_color = vec4(0.788, 0.635, 0.478, 1.0);
uniform float earth_falloff = 1.5;
uniform vec3 planet_dir = vec3(1.0, 0.0, 0.3);
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

// Brightness 0..1 of the seeded ray craters at surface point s.
float rays(vec3 s) {
	float v = 0.0;
	for (int i = 0; i < 8; i++) {
		if (i >= ray_craters) {
			break;
		}
		vec3 h = hash3(vec3(float(i) * 7.31, seed * 41.7, 3.9));
		vec3 c = normalize(hash3(vec3(seed * 17.3, float(i) * 3.17, 11.1)) * 2.0 - 1.0);
		float a = ray_crater_size * (0.6 + 0.8 * h.x);
		float d = acos(clamp(dot(s, c), -1.0, 1.0));
		vec3 t1 = normalize(cross(c, abs(c.y) < 0.9 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
		vec3 t2 = cross(c, t1);
		float phi = atan(dot(s, t2), dot(s, t1));
		float halo = smoothstep(2.0 * a, 0.8 * a, d);
		float r = 0.0;
		if (d > a) {
			for (int j = 0; j < 32; j++) {
				if (j >= ray_rays) {
					break;
				}
				vec3 q = hash3(vec3(float(i) * 5.7 + seed * 13.1, float(j) * 1.93, 7.7));
				float dp = abs(mod(phi - q.x * TAU + PI, TAU) - PI);
				float w = ray_width * (0.5 + q.y);
				float len = ray_length * (0.4 + 0.9 * q.z);
				r = max(r, exp(-pow(dp / w, 2.0)) * exp(-(d - a) / len));
			}
		}
		v = max(v, max(halo, r));
	}
	return v;
}

// Thin line where fbm crosses 0.5, `px` screen pixels wide.
float contour(vec3 p, float px) {
	float v = fbm(p) - 0.5;
	return 1.0 - smoothstep(0.0, px * max(fwidth(v), 1e-6), abs(v));
}
#endif

void fragment() {
	vec3 n = vec3(local, sqrt(max(1.0 - dot(local, local), 0.0)));
	vec3 l = normalize(light);
#ifdef CRATERS
	vec3 sp = spin * n;
	float maria = 0.0;
	if (maria_coverage > 0.0) {
		float t = 0.7 - 0.45 * clamp(maria_coverage, 0.0, 1.0);
		maria = smoothstep(t - maria_softness, t + maria_softness, fbm(sp * maria_scale + 17.0));
	}
	float upp = max(max(length(dFdx(n)), length(dFdy(n))), 1e-6);
	vec3 p = sp + seed * vec3(101.3, 57.1, 33.7);
	vec3 g = vec3(0.0);
	for (int i = 0; i < 3; i++) {
		float w = smoothstep(1.0, 2.0, 0.075 * crater_scales[i] / upp);
		if (w > 0.0) {
			g += w * craters(p, crater_scales[i]);
		}
	}
	if (maria_coverage > 0.0) {
		g *= 1.0 - maria_suppress * maria;
	}
	g = transpose(spin) * g;
	float k = dot(normalize(n - crater_bump * (g - n * dot(n, g))), l);
#else
	float k = dot(n, l);
#endif
	float lit = smoothstep(-0.1, 0.2, k) * mix(0.8, 1.0, clamp(k, 0.0, 1.0));
	vec3 c = style_tone(dark_color.rgb, lit_color.rgb, lit, FRAGCOORD.xy, local);
#ifdef CRATERS
	vec3 alb = vec3(1.0);
	if (blotch > 0.0) {
		float b = smoothstep(0.35, 0.65, fbm(sp * blotch_scale + 53.0));
		alb *= mix(vec3(1.0), blotch_color.rgb / max(lit_color.rgb, vec3(1e-3)), blotch * b);
		alb *= 1.0 - blotch * blotch_dark * smoothstep(0.55, 0.75, fbm(sp * blotch_scale * 2.0 + 91.0));
	}
	if (lineae > 0.0) {
		alb *= 1.0 - lineae * lineae_dark * contour(sp * lineae_scale + 5.0, lineae_px);
		alb *= 1.0 + lineae * lineae_bright * contour(sp * lineae_scale * 1.7 + 29.0, lineae_px);
	}
	if (maria_coverage > 0.0) {
		alb *= 1.0 - maria_darkness * maria;
	}
	if (ray_craters > 0) {
		alb *= 1.0 + ray_brightness * rays(sp);
	}
	c *= alb;
	if (earth_strength > 0.0) {
		float e = pow(max(dot(n, normalize(planet_dir)), 0.0), earth_falloff);
		c += earth_color.rgb * earth_strength * e * (1.0 - lit);
	}
	c *= 1.0 + noise_amount * (fbm(sp * 3.0 + seed * 7.0) - 0.5) * 2.0;
#else
	c *= 1.0 + noise_amount * (fbm(n * 3.0 + seed * 7.0) - 0.5) * 2.0;
#endif
	float r = length(local);
	if (outline && r > 1.0 - fwidth(r) * outline_px) {
		c = outline_color.rgb;
	}
	COLOR = vec4(c, 1.0);
}
