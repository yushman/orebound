shader_type canvas_item;

uniform vec2 viewport_size = vec2(1280.0, 800.0);
uniform vec2 apex_px = vec2(640.0, 400.0);
uniform float radius_px = 100.0;
uniform float spacing_px = 24.0;
uniform float speed_px = 80.0;
uniform float strength_px = 4.0;
uniform float fade = 1.0;
uniform float edge_fade = 0.2;
uniform float aberration: hint_range(0.0, 1.0, 0.001) = 0.425;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	float u = UV.x;
	float l = u > 0.0 ? UV.y / u : 0.0;
	float d = u * radius_px;
	float mask = (1.0 - smoothstep(1.0 - edge_fade, 1.0, u)) * (1.0 - smoothstep(1.0 - edge_fade, 1.0, abs(l))) * fade;
	vec2 rel = SCREEN_UV * viewport_size - apex_px;
	vec2 dir = rel / max(length(rel), 0.0001);
	float wave = sin(TAU * (d + TIME * speed_px) / spacing_px);
	vec2 offset_uv = dir * strength_px * wave * mask / viewport_size;
	vec2 abber_uv = offset_uv * aberration;
	float r = texture(SCREEN_TEXTURE, SCREEN_UV - offset_uv + abber_uv).r;
	float g = texture(SCREEN_TEXTURE, SCREEN_UV - offset_uv).g;
	float b = texture(SCREEN_TEXTURE, SCREEN_UV - offset_uv - abber_uv).b;
	COLOR = vec4(r, g, b, 1.0);
}
