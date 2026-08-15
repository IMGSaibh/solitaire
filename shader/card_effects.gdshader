shader_type canvas_item;

// Outline effect
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool outline_enabled = false;
uniform float outline_width : hint_range(0.0, 6.0) = 1.0;


vec4 apply_outline(vec4 color, float surrounding_alpha) {
	if (!outline_enabled) {
		return color;
	}

	float outline_alpha = max(surrounding_alpha - color.a, 0.0);
	return mix(color, outline_color, outline_alpha);
}


void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Built-in TEXTURE sampling must happen inside fragment(). Use screen pixels
	// so the outline width stays consistent across source texture resolutions.
	vec2 outline_offset = fwidth(UV) * outline_width;
	float surrounding_alpha = 0.0;
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(outline_offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(outline_offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, outline_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, outline_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(outline_offset.x, outline_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(outline_offset.x, -outline_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-outline_offset.x, outline_offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(outline_offset.x, outline_offset.y)).a);

	// Card effects are applied here in their visual order.
	color = apply_outline(color, surrounding_alpha);

	COLOR = color;
}
