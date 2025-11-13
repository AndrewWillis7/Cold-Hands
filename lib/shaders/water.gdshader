shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;

uniform vec3 shallow_color = vec3(0.2, 0.8, 1.0);
uniform vec3 deep_color = vec3(0.0, 0.3, 0.6);
uniform float wave_speed   = 1.5;
uniform float wave_scale   = 6.0;
uniform float wave_strength = 0.03;
uniform float shimmer_intensity = 0.25;

// Optional toon banding
uniform bool toon = false;
uniform int bands = 6; // 2-6 looks nice

void fragment() {
    // Seamless world-space basis (tiles across meshes)
    vec2 pos = NODE_POSITION_WORLD.xz * 0.1 * wave_scale;
    float t = TIME * wave_speed;

    // Soft, looping wave offset
    vec2 wave_offset = vec2(
        sin(pos.y + t) + cos(pos.x * 1.2 - t * 1.1),
        cos(pos.x + t * 0.7) + sin(pos.y * 1.3 - t)
    ) * wave_strength;

    // Distorted UV for shimmer patterning
    vec2 uv = UV + wave_offset;

    // y = 0 as the “water level” reference; lighter above, deeper below
    float depth_factor = clamp(NODE_POSITION_VIEW.y * 0.5 + 0.5, 0.0, 1.0);
    vec3 base_color = mix(deep_color, shallow_color, depth_factor);

    // Gentle pulse to make it feel alive
    float pulse = sin(TIME * 1.2) * 0.5 + 0.5;
    base_color *= mix(0.9, 1.1, pulse);

    // Sparkly shimmer
    float shimmer = sin(uv.x * 20.0 + t * 3.0) * cos(uv.y * 25.0 - t * 2.5);
    shimmer = pow(abs(shimmer), 10.0) * shimmer_intensity;

    vec3 col = base_color + shimmer;

    // Optional toon bands for that crispy cartoon snap
    if (toon) {
        float l = clamp(dot(col, vec3(0.3333)), 0.0, 1.0);
        float q = floor(l * float(max(bands,1))) / float(max(bands,1));
        col = normalize(col + 1e-5) * q; // keep hue-ish, band lightness
    }

    ALBEDO = col;
    ALPHA = 1.0; // set < 1.0 if you want transparent water later
}
