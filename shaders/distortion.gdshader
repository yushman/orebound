shader_type canvas_item;

uniform vec2 viewport_size = vec2(1280.0, 800.0);
uniform vec2 center_px = vec2(640.0, 400.0);
uniform float radius_px = 40.0;
uniform float width_px = 8.0;
uniform float feather_px = 6.0;
uniform float strength_px = 10.0;
uniform vec2 fan_dir = vec2(1.0, 0.0);
uniform float fan_cos = -2.0;
uniform float fan_soft = 0.15;
uniform float aberration: hint_range(0.0, 1.0, 0.001) = 0.425;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 frag_px = SCREEN_UV * viewport_size;
	vec2 d = frag_px - center_px;
	float dist = length(d);
	float mask = (1.0 - smoothstep(radius_px - feather_px, radius_px, dist)) * smoothstep(radius_px - width_px - feather_px, radius_px - width_px, dist);
	vec2 dir = d / max(dist, 0.0001);
	mask *= smoothstep(fan_cos - fan_soft, fan_cos + fan_soft, dot(dir, fan_dir));
	vec2 offset_uv = dir * strength_px * mask / viewport_size;
	vec2 final_uv = SCREEN_UV - offset_uv;
	vec2 abber_uv = offset_uv * aberration;
	float r = texture(SCREEN_TEXTURE, final_uv + abber_uv).r;
	float g = texture(SCREEN_TEXTURE, final_uv).g;
	float b = texture(SCREEN_TEXTURE, final_uv - abber_uv).b;
	COLOR = vec4(r, g, b, clamp(mask * 50.0, 0.0, 1.0));
}
