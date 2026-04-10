shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 power_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float power_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    float purple_a = smoothstep(0.10, 0.40, original.r - original.g);
    float purple_b = smoothstep(0.20, 0.55, original.b - original.g);
    float purple_mask = clamp(purple_a * purple_b, 0.0, 1.0);
    float tint_factor = power_strength * purple_mask * original.a;
    vec3 tinted = mix(original.rgb, power_tint.rgb, tint_factor);
    vec4 with_tint = vec4(tinted, original.a);
    COLOR = mix(with_tint, vec4(flash_color.rgb, with_tint.a), flash_amount * with_tint.a);
}
