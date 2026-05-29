[shader_type canvas_item]

uniform vec4 target_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float replace_threshold : hint_range(0.0, 1.0) = 0.15;
uniform float replace_strength : hint_range(0.0, 1.0) = 1.0;
uniform float force_tint : hint_range(0.0, 1.0) = 0.0;
uniform float brightness_boost : hint_range(0.0, 1.0) = 0.22;

// Replaces blue-ish pixels with a brighter target tint without flattening them too much.
void fragment() {
	vec4 src = texture(TEXTURE, UV);
	vec3 c = src.rgb;

	float blue_dominance = c.b - max(c.r, c.g);
	float blue_amount = c.b;
	float score = max(0.0, blue_dominance) * blue_amount;

	float t = smoothstep(replace_threshold * 0.5, replace_threshold * 2.0, score) * replace_strength;
	t = max(t, force_tint);

	vec3 tgt = clamp(target_color.rgb * (1.0 + brightness_boost), vec3(0.0), vec3(1.0));
	vec3 outc = mix(c, tgt, t);
	COLOR = vec4(outc, src.a * target_color.a);
}
