shader_type canvas_item;

uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform vec4 base_color : source_color = vec4(1.0, 0.82, 0.27, 1.0);
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 0.85, 1.0);
uniform float shimmer_width : hint_range(0.0, 1.0) = 0.15;
uniform int sparkle_count : hint_range(0, 20) = 8;
uniform float sparkle_size : hint_range(0.0, 0.05) = 0.015;
uniform float sparkle_speed : hint_range(0.0, 5.0) = 1.5;

float random(vec2 st) {
    return fract(sin(dot(st, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.01) discard;

    // Shimmer usando SCREEN_UV para que sea coherente en todo el label
    float shimmer_pos = mod(TIME * speed, 1.0 + shimmer_width) - shimmer_width;
    float dist = abs(SCREEN_UV.x - shimmer_pos);
    float shimmer = smoothstep(shimmer_width, 0.0, dist);
    vec4 final_color = mix(base_color, shimmer_color, shimmer);

    // Destellos usando SCREEN_UV
    float sparkle_alpha = 0.0;
    for (int i = 0; i < sparkle_count; i++) {
        float fi = float(i);
        vec2 sparkle_pos = vec2(
            random(vec2(fi, 0.1)),
            random(vec2(fi, 0.9))
        );
        float blink = sin(TIME * sparkle_speed + fi * 1.7) * 0.5 + 0.5;
        blink = pow(blink, 3.0);
        float d = length(SCREEN_UV - sparkle_pos);
        sparkle_alpha += blink * smoothstep(sparkle_size, 0.0, d);
    }
    sparkle_alpha = clamp(sparkle_alpha, 0.0, 1.0);

    vec4 sparkle_col = vec4(1.0, 0.95, 0.7, sparkle_alpha);
    final_color = mix(final_color, sparkle_col, sparkle_alpha);

    COLOR = vec4(final_color.rgb, tex.a * COLOR.a);
}