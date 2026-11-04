shader_type canvas_item;

// Planet: lit sphere with multi-scale albedo detail, night-side lava cracks
// and limb haze. Drawn on a camera-centred square: `local` is the world
// offset from `cam` (camera relative to the planet centre), so the surface
// is shaded at full precision near the camera and the haze can draw outside
// the disc.
#include "res://shaders/style.gdshaderinc"

uniform vec4 lit_color : source_color = vec4(0.788, 0.635, 0.478, 1.0);
uniform vec4 dark_color : source_color = vec4(0.276, 0.222, 0.167, 1.0);
uniform vec3 light = vec3(-0.6, -0.8, 0.35);
uniform float seed = 0.0;
uniform float noise_amount = 0.08;
uniform bool outline = false;
uniform vec4 outline_color : source_color = vec4(0.722, 0.847, 0.753, 1.0);
uniform float outline_px = 1.5;

uniform vec2 cam;
uniform float planet_r = 100000.0;
uniform float time = 0.0;

// Scale table, see Body.scale_table: cell size in world units, floor(cam /
// size) and fract(cam / size) computed on the CPU in doubles, so a cell
// coordinate is base + (frac + offset / size) with a small offset. Detail
// octaves first (detail_count), then lava coarse, lava fine, lava mask.
uniform float sc_size[16];
uniform vec2 sc_base[16];
uniform vec2 sc_frac[16];

uniform int detail_count = 0;
uniform float detail_albedo = 0.0;
uniform float detail_gain = 0.85;
uniform float detail_ridge = 0.5;
uniform vec2 fade_px = vec2(2.0, 6.0);

uniform float lava = 0.0;
uniform vec4 lava_color : source_color = vec4(1.0, 0.35, 0.1, 1.0);
uniform float lava_width_px = 1.5;
uniform float lava_glow_px = 6.0;
uniform float lava_glow = 0.35;
uniform float lava_density = 0.6;
uniform float lava_night_pow = 2.0;
uniform float lava_pulse = 0.3;
uniform float lava_pulse_speed = 1.5;
uniform float lava_fade_px = 12.0;
uniform float lava_fine = 0.6;

uniform float haze = 0.0;
uniform vec4 haze_color : source_color = vec4(1.0, 0.86, 0.7, 1.0);
uniform float haze_in = 600.0;
uniform float haze_out = 300.0;
uniform float haze_px = 2.0;
uniform float haze_lit_pow = 1.5;
uniform float haze_wrap = 0.2;

varying vec2 local;

void vertex() {
	local = VERTEX - cam;
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

// Integer cell hash (pcg3d): exact for any cell index, unlike hash().
uint ihash(ivec3 c, uint salt) {
	uvec3 v = uvec3(c) * 1664525u + uvec3(1013904223u + salt);
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	v = v ^ (v >> uvec3(16u));
	v.x += v.y * v.z;
	v.y += v.z * v.x;
	v.z += v.x * v.y;
	return v.x ^ v.y ^ v.z;
}

float ihash1(ivec3 c, uint salt) {
	return float(ihash(c, salt) >> 8u) / 16777215.0;
}

vec3 ihash3(ivec3 c, uint salt) {
	uint h = ihash(c, salt);
	return vec3(float(h & 1023u), float((h >> 10u) & 1023u), float((h >> 20u) & 1023u)) / 1023.0;
}

uint salt_of(int i) {
	return uint(seed * 1000.0) * 7919u + uint(i) * 1013u;
}

// Position inside the cell of scale i; `base` gets the integer cell.
vec3 cellp(int i, vec3 dom, out ivec3 base) {
	float s = sc_size[i];
	vec3 q = vec3(sc_frac[i] + dom.xy / s, dom.z / s);
	vec3 f = floor(q);
	base = ivec3(ivec2(sc_base[i]), 0) + ivec3(f);
	return q - f;
}

// Value noise on integer cells, f the position inside cell c.
float vnoise(ivec3 c, vec3 f, uint salt) {
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(ihash1(c, salt), ihash1(c + ivec3(1, 0, 0), salt), u.x), mix(ihash1(c + ivec3(0, 1, 0), salt), ihash1(c + ivec3(1, 1, 0), salt), u.x), u.y),
		mix(mix(ihash1(c + ivec3(0, 0, 1), salt), ihash1(c + ivec3(1, 0, 1), salt), u.x), mix(ihash1(c + ivec3(0, 1, 1), salt), ihash1(c + ivec3(1, 1, 1), salt), u.x), u.y),
		u.z);
}

// Distance (cell units) to the nearest Voronoi cell border of scale i.
float border(int i, vec3 dom) {
	ivec3 cb;
	vec3 f = cellp(i, dom, cb);
	uint salt = salt_of(i);
	vec3 mr = vec3(0.0);
	ivec3 mc = ivec3(0);
	float md = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				ivec3 o = ivec3(x, y, z);
				vec3 r = vec3(o) + ihash3(cb + o, salt) - f;
				float d = dot(r, r);
				if (d < md) {
					md = d;
					mr = r;
					mc = o;
				}
			}
		}
	}
	md = 8.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				ivec3 o = mc + ivec3(x, y, z);
				vec3 r = vec3(o) + ihash3(cb + o, salt) - f;
				if (dot(mr - r, mr - r) > 1e-5) {
					md = min(md, dot(0.5 * (mr + r), normalize(r - mr)));
				}
			}
		}
	}
	return md;
}

void fragment() {
	vec2 p = cam + local;
	float r = length(p);
	float rr = planet_r;
	float z = sqrt(max((rr - r) * (rr + r), 0.0));
	vec3 n = vec3(p / rr, z / rr);
	vec3 l = normalize(light);
	vec3 dom = vec3(local, z);
	float upp = max(max(length(dFdx(dom)), length(dFdy(dom))), 1e-6);
	float wpp = max(length(dFdx(local)), 1e-6);

	float d_edge = r - rr;
	bool surf = d_edge <= 0.0;

	// detail octaves, coarse to fine
	float alb = 0.0;
	if (surf && detail_albedo != 0.0) {
		float amp = 1.0;
		for (int i = 0; i < 16; i++) {
			if (i >= detail_count) {
				break;
			}
			float w = smoothstep(fade_px.x, fade_px.y, sc_size[i] / upp);
			if (w <= 0.0) {
				break;
			}
			ivec3 cb;
			vec3 f = cellp(i, dom, cb);
			float v = vnoise(cb, f, salt_of(i));
			float h = mix(v, 1.0 - abs(2.0 * v - 1.0), detail_ridge);
			alb += w * amp * (h - 0.5) * 2.0;
			amp *= detail_gain;
		}
	}

	float k = dot(n, l);
	float lit = smoothstep(-0.1, 0.2, k) * mix(0.8, 1.0, clamp(k, 0.0, 1.0));
	vec3 c = style_tone(dark_color.rgb, lit_color.rgb, lit, FRAGCOORD.xy, local);
	c *= max(1.0 + detail_albedo * alb, 0.0);
	if (surf) {
		c *= 1.0 + noise_amount * (fbm(n * 3.0 + seed * 7.0) - 0.5) * 2.0;
	}

	// lava on the night side
	if (lava > 0.0 && surf) {
		float night = pow(1.0 - lit, lava_night_pow);
		// max of pulse * e is (1 + lava_pulse) * (1 + lava_glow): below half an 8-bit step
		if (lava * night * (1.0 + lava_pulse) * (1.0 + lava_glow) > 0.5 / 255.0) {
			int lava_i = detail_count;
			int mask_i = detail_count + 2;
			ivec3 cb;
			vec3 f = cellp(mask_i, dom, cb);
			float m = vnoise(cb, f, salt_of(mask_i));
			float mask = smoothstep(1.0 - lava_density - 0.15, 1.0 - lava_density + 0.15, m);
			if (mask > 0.0) {
				float pulse = 1.0 + lava_pulse * sin(time * lava_pulse_speed + m * 18.85);
				float e = 0.0;
				for (int i = lava_i; i < lava_i + 2; i++) {
					float px = sc_size[i] / upp;
					float w = smoothstep(lava_fade_px * 0.5, lava_fade_px, px);
					if (w > 0.0) {
						float share = i == lava_i ? 1.0 : lava_fine;
						float wd = lava_width_px * share;
						float d = border(i, dom) * px;
						float line = 1.0 - smoothstep(0.5 * wd, 0.5 * wd + 1.0, d);
						float glow = lava_glow * exp(-d / max(lava_glow_px, 1e-3));
						e = max(e, w * share * (line + glow));
					}
				}
				c += lava_color.rgb * lava * night * mask * pulse * e;
			}
		}
	}

	if (outline && d_edge > -wpp * outline_px) {
		c = outline_color.rgb;
	}

	// limb haze, inside and outside the edge, on the lit limb
	float a = d_edge <= 0.0 ? 1.0 : 0.0;
	if (haze > 0.0) {
		float h = d_edge <= 0.0
			? exp(d_edge / max(haze_in, haze_px * wpp))
			: exp(-d_edge / max(haze_out, haze_px * wpp));
		float side = pow(clamp((dot(p / max(r, 1e-3), normalize(light.xy)) + haze_wrap) / (1.0 + haze_wrap), 0.0, 1.0), haze_lit_pow);
		float hz = clamp(haze * h * side, 0.0, 1.0);
		if (d_edge <= 0.0) {
			c = mix(c, haze_color.rgb, hz);
		} else {
			c = haze_color.rgb;
			a = hz;
		}
	}
	COLOR = vec4(c, a);
}
