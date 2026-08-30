shader_type canvas_item;
render_mode blend_premul_alpha;

// Shine effect
group_uniforms Shine;
uniform bool shine_enabled = true;
uniform float shine_line_smoothness : hint_range(0.0, 0.1) = 0.045;
uniform float shine_line_width : hint_range(0.0, 0.2) = 0.09;
uniform float shine_brightness = 3.0;
uniform float shine_rotation_degrees : hint_range(-90.0, 90.0) = 30.0;
uniform float shine_distortion : hint_range(1.0, 2.0) = 1.8;
uniform float shine_speed : hint_range(0.1, 2.0, 0.05) = 0.7;
uniform float shine_interval : hint_range(1.0, 20.0, 0.5) = 6.0;
uniform float shine_position : hint_range(0.0, 1.0) = 0.0;
uniform float shine_position_min = 0.25;
uniform float shine_position_max = 0.5;
uniform float shine_alpha : hint_range(0.0, 1.0) = 1.0;

// Outline effect
group_uniforms Outline;
uniform vec4 outline_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform bool outline_enabled = false;
uniform float outline_width : hint_range(0.0, 6.0) = 1.0;
group_uniforms;


vec2 rotate_uv(vec2 uv, vec2 center, float rotation_degrees) {
	float angle = radians(rotation_degrees);
	mat2 rotation = mat2(
		vec2(cos(angle), -sin(angle)),
		vec2(sin(angle), cos(angle))
	);
	return rotation * (uv - center) + center;
}


float get_shine_amount(vec2 uv) {
	vec2 centered_uv = uv - vec2(0.5);
	float gradient_to_edge = max(abs(centered_uv.x), abs(centered_uv.y));
	gradient_to_edge = 1.0 - gradient_to_edge * shine_distortion;

	vec2 rotated_uv = rotate_uv(uv, vec2(0.5), shine_rotation_degrees);
	float remapped_position = mix(shine_position_min, shine_position_max, shine_position);
	float sweep_duration = 1.0 / shine_speed;
	float cycle_duration = max(shine_interval, sweep_duration);
	float cycle_time = mod(TIME + remapped_position * cycle_duration, cycle_duration);
	if (cycle_time > sweep_duration) {
		return 0.0;
	}
	float remapped_time = mix(-2.0, 2.0, cycle_time / sweep_duration);

	float line = abs(rotated_uv.x + remapped_time);
	line = sqrt(max(gradient_to_edge * line, 0.0));

	float line_smoothness = clamp(shine_line_smoothness, 0.001, 1.0);
	float offset_plus = shine_line_width + line_smoothness;
	float offset_minus = shine_line_width - line_smoothness;
	float remapped_line = (line - offset_plus) / (offset_minus - offset_plus);

	return clamp(remapped_line * shine_brightness, 0.0, shine_alpha);
}


vec4 apply_shine(vec4 color, vec2 uv) {
	if (!shine_enabled || color.a <= 0.0) {
		return color;
	}

	float shine = get_shine_amount(uv);
	color.rgb = mix(color.rgb, vec3(1.0), shine);
	return color;
}


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
	color = apply_shine(color, UV);
	color = apply_outline(color, surrounding_alpha);

	// blend_premul_alpha expects RGB to already be multiplied by alpha.
	COLOR = vec4(color.rgb * color.a, color.a);
}
