shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_primary : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_secondary : source_color = vec4(0.925, 0.910, 0.910, 1.0);
uniform float glow_speed : hint_range(0.5, 10.0) = 6.0;
uniform float glow_intensity : hint_range(0.0, 1.0) = 0.4;
uniform bool low_power = false;   // parpadeo cuando queda poco tiempo
uniform bool low_health = false;  // colores apagados con 1 corazon

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    vec4 result = original;

    float pulse = 0.0;
    if (low_power) {
        pulse = (sin(TIME * glow_speed) * 0.5 + 0.5) * glow_intensity;
    }

    if (original.a > 0.1) {
        if (original.r > 0.9 && original.g > 0.9 && original.b > 0.9) {
            vec3 glow_color = min(color_primary.rgb + pulse, vec3(1.0));
            result = vec4(glow_color, original.a);
        }
        else if (original.r > 0.8 && original.g > 0.8 && original.b > 0.8) {
            vec3 glow_color = min(color_secondary.rgb + pulse, vec3(1.0));
            result = vec4(glow_color, original.a);
        }
        // Apagar colores si queda 1 corazon: dessaturar y oscurecer
        if (low_health) {
            float grey = dot(result.rgb, vec3(0.299, 0.587, 0.114));
            result.rgb = mix(result.rgb, vec3(grey), 0.6) * 0.75;
        }
    }

    COLOR = mix(result, vec4(flash_color.rgb, result.a), flash_amount * result.a);
}