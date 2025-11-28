shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

uniform vec4 inner_color : source_color = vec4(0.6, 0.6, 0.6, 0.6);
uniform vec4 outer_color : source_color = vec4(0.6, 0.6, 0.6, 0.0);

uniform vec4 outline_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

// How many "steps" from center to edge.
// LOWER = chunkier, HIGHER = smoother.
uniform float radial_steps = 6.0;

// 0–1 range near the outer edge where outline appears.
uniform float outline_width = 0.15;

void fragment() {
    // UV.x is radial: 0 at center, 1 at outer edge (from your mesh UV setup)
    float u = UV.x;

    // Pixelation: quantize radial value into a few big steps
    float u_pix = floor(u * radial_steps) / radial_steps;

    // Base gradient color with pixelized radial bands
    vec4 col = mix(inner_color, outer_color, u_pix);

    // Outline near the outer rim: when u_pix is close to 1.0
    float edge = smoothstep(1.0 - outline_width, 1.0, u_pix);
    col = mix(col, outline_color, edge);

    ALBEDO = col.rgb;
    ALPHA = col.a;
}
