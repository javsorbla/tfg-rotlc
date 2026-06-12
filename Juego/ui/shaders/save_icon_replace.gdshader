shader_type canvas_item;

uniform vec4 target_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float replace_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float replace_strength : hint_range(0.0, 1.0) = 1.0;
uniform float force_tint : hint_range(0.0, 1.0) = 0.0;
uniform float brightness_boost : hint_range(0.0, 1.0) = 0.22;

void fragment() {
    vec4 src = texture(TEXTURE, UV);
    vec3 c = src.rgb;

    // Detectar azul
    float blue_dominance = c.b - max(c.r, c.g);
    float score = max(0.0, blue_dominance) * c.b;
    float warm_protection = step(0.4, c.r) * step(0.4, c.g);
    score *= (1.0 - warm_protection);

    float t = smoothstep(replace_threshold * 0.5, replace_threshold * 2.0, score) * replace_strength;
    t = max(t, force_tint);

    // Preservar luminosidad original del píxel
    float lum = dot(c, vec3(0.299, 0.587, 0.114));
    vec3 tgt = target_color.rgb * lum * (1.0 + brightness_boost);
    tgt = clamp(tgt, 0.0, 1.0);

    vec3 outc = mix(c, tgt, t);
    COLOR = vec4(outc, src.a * target_color.a);
}