shader_type spatial;
render_mode unshaded, cull_back;

// Flat type colour (vertex COLOR) for the rim light pass.

void fragment() {
	ALBEDO = COLOR.rgb;
}
