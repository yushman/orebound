shader_type canvas_item;

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

void fragment() {
	vec3 n = vec3(local, sqrt(max(1.0 - dot(local, local), 0.0)));
	vec3 l = normalize(light);
	float k = dot(n, l);
	float lit = smoothstep(-0.1, 0.2, k) * mix(0.8, 1.0, clamp(k, 0.0, 1.0));
	vec3 c = style_tone(dark_color.rgb, lit_color.rgb, lit, FRAGCOORD.xy, local);
	c *= 1.0 + noise_amount * (fbm(n * 3.0 + seed * 7.0) - 0.5) * 2.0;
	float r = length(local);
	if (outline && r > 1.0 - fwidth(r) * outline_px) {
		c = outline_color.rgb;
	}
	COLOR = vec4(c, 1.0);
}
