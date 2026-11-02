shader_type canvas_item;

uniform vec4 color : source_color = vec4(0.5, 0.78, 0.97, 1.0);
uniform float radius_px = 100.0;
uniform float line_width_px = 1.5;
uniform float spacing_px = 24.0;
uniform float speed_px = 80.0;
uniform float alpha = 0.7;
uniform float fade = 1.0;
uniform float edge_fade = 0.2;

void fragment() {
	float u = UV.x;
	float l = u > 0.0 ? UV.y / u : 0.0;
	float d = u * radius_px;
	float p = mod(d + TIME * speed_px, spacing_px);
	float dist = min(p, spacing_px - p);
	float line = 1.0 - smoothstep(line_width_px * 0.5 - 0.5, line_width_px * 0.5 + 0.5, dist);
	float mask = (1.0 - smoothstep(1.0 - edge_fade, 1.0, u)) * (1.0 - smoothstep(1.0 - edge_fade, 1.0, abs(l))) * fade;
	COLOR = vec4(color.rgb, color.a * alpha * line * mask);
}
