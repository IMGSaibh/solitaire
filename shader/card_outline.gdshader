shader_type canvas_item;

// With "instance uniform," each card can have a different outline thickness, even though they all use the same material.
instance uniform vec4 outline_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
instance uniform float outline_strength : hint_range(0.0, 1.0) = 0.0;
uniform float outline_width = 3.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;

	float surrounding_alpha = 0.0;

	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
	surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);

	float outline_alpha = max(surrounding_alpha - base.a, 0.0);

	vec4 outline = vec4(outline_color.rgb, outline_color.a * outline_alpha * outline_strength);

	COLOR = mix(outline, base, base.a);
}
