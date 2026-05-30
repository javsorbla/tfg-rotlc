shader_type canvas_item;

uniform float ring_radius : hint_range(0.0, 2.0) = 0.0;
uniform float ring_width : hint_range(0.0, 0.5) = 0.05;
uniform vec4 pulse_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
    vec2 d = UV - vec2(0.5);
    float dist = length(d);
    float half_w = max(ring_width * 0.5, 0.0001);
    float inner = ring_radius - half_w;
    float outer = ring_radius + half_w;

    float fade_front = 1.0 - smoothstep(ring_radius, outer, dist);
    float fade_back = step(inner, dist);
    float ring_alpha = fade_front * fade_back;

    float final_alpha = pulse_color.a * ring_alpha;
    if (final_alpha <= 0.005) discard;

    COLOR = vec4(pulse_color.rgb, final_alpha);
}