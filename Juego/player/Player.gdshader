shader_type canvas_item;

uniform float flash_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_primary : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 color_secondary : source_color = vec4(0.925, 0.910, 0.910, 1.0);

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    
    // Detectar blanco primario (255, 255, 255)
    if (original.r > 0.99 && original.g > 0.99 && original.b > 0.99 && original.a > 0.0) {
        original = vec4(color_primary.rgb, original.a);
    }
    // Detectar blanco secundario (236, 232, 232)
    else if (original.r > 0.92 && original.g > 0.90 && original.b > 0.90 && original.a > 0.0
             && original.r < 0.95 && original.g < 0.93 && original.b < 0.93) {
        original = vec4(color_secondary.rgb, original.a);
    }
    
    // Flash encima de todo
    COLOR = mix(original, vec4(flash_color.rgb, original.a), flash_amount * original.a);
}