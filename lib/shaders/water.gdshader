// Thanks to Pindra on godotshaders.com

shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_opaque;

// ===== Your existing params =====
uniform vec2  R = vec2(0.8, 0.6);
uniform float scale = 0.5;
uniform float speed = 1.0;
uniform vec3  direction = vec3(1.0, 1.0, 0.0);
uniform float distortion = 0.5;
uniform float layers = 2.0;
uniform float shades = 3.0;
uniform int   steps = 6;
uniform vec3  tint = vec3(0.459, 0.765, 1.0);

// ===== Waves (Gerstner) =====
uniform vec2  wave1_dir = vec2(1.0, 0.2);
uniform float wave1_amp = 0.25;
uniform float wave1_len = 8.0;
uniform float wave1_steep = 0.6;
uniform float wave1_speed = 1.0;

uniform vec2  wave2_dir = vec2(0.3, 1.0);
uniform float wave2_amp = 0.12;
uniform float wave2_len = 3.5;
uniform float wave2_steep = 0.7;
uniform float wave2_speed = 1.6;

uniform float time_scale = 1.0;

// ---- noise for color ----
float gyroid(vec3 seed) { return dot(sin(seed), cos(seed.yzx)); }

float fbm(vec3 seed) {
    float result = 0.0;
    float a = 0.5;
    for (int i = 0; i < steps; i++) {
        seed += direction * TIME * speed * 0.01 / a;
        seed.z += result * distortion;
        result += gyroid(seed / a) * a;
        a *= 0.5;
    }
    return result;
}

// Gerstner in object space
vec3 gerstner_obj(vec2 obj_xz, vec2 dir, float amp, float lambda, float steep, float spd, float t) {
    dir = normalize(dir);
    float k = 2.0 * PI / max(lambda, 0.001);
    float phase = dot(dir, obj_xz) * k - spd * t;
    float A = amp;
    float Q = clamp(steep, 0.0, 1.0);
    float c = cos(phase);
    float s = sin(phase);
    vec2 disp_xz = dir * (Q * A * c);
    float disp_y = A * s;
    return vec3(disp_xz.x, disp_y, disp_xz.y);
}

void vertex() {
    float t = TIME * time_scale;

    // Use local/object-space XZ for the wave phase (no world matrix needed)
    vec2 obj_xz = VERTEX.xz;

    vec3 d1 = gerstner_obj(obj_xz, wave1_dir, wave1_amp, wave1_len, wave1_steep, wave1_speed, t);
    vec3 d2 = gerstner_obj(obj_xz, wave2_dir, wave2_amp, wave2_len, wave2_steep, wave2_speed, t);
    vec3 disp = d1 + d2;

    VERTEX += disp;

    // Quick procedural normal (only matters if you later use lit shading)
    vec2 eps = vec2(0.05, 0.0);
    float h  = (gerstner_obj(obj_xz,                wave1_dir, wave1_amp, wave1_len, wave1_steep, wave1_speed, t).y
             +  gerstner_obj(obj_xz,                wave2_dir, wave2_amp, wave2_len, wave2_steep, wave2_speed, t).y);
    float hx = (gerstner_obj(obj_xz + vec2(eps.x,0), wave1_dir, wave1_amp, wave1_len, wave1_steep, wave1_speed, t).y
             +  gerstner_obj(obj_xz + vec2(eps.x,0), wave2_dir, wave2_amp, wave2_len, wave2_steep, wave2_speed, t).y);
    float hz = (gerstner_obj(obj_xz + vec2(0,eps.x), wave1_dir, wave1_amp, wave1_len, wave1_steep, wave1_speed, t).y
             +  gerstner_obj(obj_xz + vec2(0,eps.x), wave2_dir, wave2_amp, wave2_len, wave2_steep, wave2_speed, t).y);

    vec3 dx = vec3(eps.x, hx - h, 0.0);
    vec3 dz = vec3(0.0, hz - h, eps.x);
    NORMAL = normalize(cross(dz, dx));
}

void fragment() {
    // Keep your 2D-water look
    vec2 p = (2.0 * UV - R) / R.y;

    float shape    = fbm(vec3(p * scale, 0.0));
    float gradient = fract(shape * layers);
    float shade    = round(pow(gradient, 4.0) * shades) / shades;

    vec3 color = mix(tint * mix(0.6, 0.8, gradient), vec3(1.0), shade);

    ALBEDO   = color;
    EMISSION = color;
    ALPHA    = 1.0;
}
