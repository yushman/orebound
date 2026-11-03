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

varying vec3 bary;
varying float inclusion;
varying vec3 world_normal;
varying vec2 local_xy;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
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
	if (edges) {
		vec3 a = clamp(bary / max(fwidth(bary) * edge_px, vec3(1e-5)), 0.0, 1.0);
		c = mix(edge_color.rgb, c, min(a.x, min(a.y, a.z)));
	}
	ALBEDO = c;
}
