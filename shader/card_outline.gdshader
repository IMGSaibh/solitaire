shader_type canvas_item;

uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool outline_enabled = false;
uniform float outline_width : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 base = texture(TEXTURE, UV);

	if (outline_enabled) {
		vec2 offset = TEXTURE_PIXEL_SIZE * outline_width;
		float surrounding_alpha = 0.0;

		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(offset.x, 0.0)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(offset.x, 0.0)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(0.0, offset.y)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(0.0, offset.y)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(offset.x, offset.y)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(offset.x, -offset.y)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV + vec2(-offset.x, offset.y)).a);
		surrounding_alpha = max(surrounding_alpha, texture(TEXTURE, UV - vec2(offset.x, offset.y)).a);

		float outline_alpha = max(surrounding_alpha - base.a, 0.0);
		COLOR = mix(base, outline_color, outline_alpha);
	} else {
		COLOR = base;
	}
}
