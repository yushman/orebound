shader_type canvas_item;

uniform vec2 cam;
uniform float surface;
uniform float edge;
uniform float shape;
uniform vec4 GLOW_COLOR : source_color = vec4(1.0, 0.55, 0.15, 1.0);
uniform float ATMO_ALPHA = 0.45;

varying vec2 local;

void vertex() {
	local = VERTEX - cam;
}

float density(float r) {
	float depth = (edge - r) / (edge - surface);
	return pow(clamp(depth, 0.0, 1.0), shape);
}

void fragment() {
	float r = length(cam + local);
	COLOR = vec4(GLOW_COLOR.rgb, ATMO_ALPHA * density(r));
}
