[shader_type canvas_item]

uniform vec4 target_color : hint_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float replace_threshold : hint_range(0.0, 1.0) = 0.15;
uniform float replace_strength : hint_range(0.0, 1.0) = 1.0;
uniform float force_tint : hint_range(0.0, 1.0) = 0.0;

// Replace pixels that are dominantly blue-ish with the target color,
// preserving luminance for a more natural blend.
void fragment() {
    vec4 src = texture(TEXTURE, UV);
    vec3 c = src.rgb;

    float blue_dominance = c.b - max(c.r, c.g);
    float blue_amount = c.b;
    float score = max(0.0, blue_dominance) * blue_amount;

    float t = smoothstep(replace_threshold * 0.5, replace_threshold * 2.0, score) * replace_strength;
    // allow forcing a global tint regardless of blue detection
    t = max(t, force_tint);

    float lum = dot(c, vec3(0.2126, 0.7152, 0.0722));
    vec3 tgt = target_color.rgb;
    float tgt_lum = dot(tgt, vec3(0.2126, 0.7152, 0.0722));
    if (tgt_lum > 0.0) {
        tgt = tgt * (lum / tgt_lum);
    }

    vec3 outc = mix(c, tgt, t);
    COLOR = vec4(outc, src.a * target_color.a);
}
