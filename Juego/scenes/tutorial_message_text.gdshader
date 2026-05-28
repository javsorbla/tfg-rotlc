shader_type canvas_item;

uniform float speed : hint_range(0.0, 5.0) = 1.0;
uniform vec4 base_color : source_color = vec4(1.0, 0.82, 0.27, 1.0);
uniform vec4 shimmer_color : source_color = vec4(1.0, 1.0, 0.85, 1.0);
uniform float shimmer_width : hint_range(0.0, 1.0) = 0.15;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.01) discard;

    float shimmer_pos = mod(TIME * speed, 1.0 + shimmer_width) - shimmer_width;
    float dist = abs(UV.x - shimmer_pos);
    float shimmer = smoothstep(shimmer_width, 0.0, dist);

    vec4 final_color = mix(base_color, shimmer_color, shimmer);
    COLOR = vec4(final_color.rgb, tex.a * COLOR.a);
}