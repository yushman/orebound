// Shared stylization for the 2D body shader and the 3D solid shader.
// shading: 0 plain, 1 ordered dither (Bayer 4x4, screen pixels), 2 hatching
// fixed to the object: `local` is any object-local 2D coordinate, turned
// into screen-pixel units through its derivatives.
uniform int shading = 0;
uniform float dither_px = 2.0;
uniform float hatch_px = 5.0;
uniform float hatch_angle = 0.785398;

float bayer4(vec2 cell) {
	const float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 i = ivec2(mod(cell, 4.0));
	return (m[i.x + i.y * 4] + 0.5) / 16.0;
}

// k: light term, 0 on the dark side, 1 fully lit.
vec3 style_tone(vec3 dark, vec3 lit, float k, vec2 frag, vec2 local) {
	float upp = max(sqrt(abs(dFdx(local.x) * dFdy(local.y) - dFdx(local.y) * dFdy(local.x))), 1e-12);
	if (shading == 1) {
		return k > bayer4(floor(frag / dither_px)) ? lit : dark;
	}
	if (shading == 2) {
		float u = fract(dot(local / upp, vec2(cos(hatch_angle), sin(hatch_angle))) / hatch_px);
		return u < 1.0 - k ? dark : lit;
	}
	return mix(dark, lit, k);
}
