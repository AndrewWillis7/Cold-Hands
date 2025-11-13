shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;

uniform float time;
uniform float density = 2.0;
uniform vec3 wind = vec3(0.2, -1.0, 0.1);
uniform float flake_size = 0.005;
uniform float fall_speed = 1.0;
uniform float ground_height = 0.0; // stop below this

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

void fragment() {
	vec3 local_pos = VERTEX * density;
	vec3 grid = floor(local_pos);
	vec3 frac_pos = fract(local_pos);

	// Animate fall
	frac_pos.y = fract(frac_pos.y + time * fall_speed);

	float rnd = hash(grid);
	float flake = step(0.97, rnd);
	float shape = step(length(frac_pos.xy - vec2(0.5)), flake_size);

	float alpha = flake * shape;

	// Convert to world Y (relative to cube)
	float world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
	if (world_y < ground_height) {
		alpha = 0.0; // hide flakes below ground
	}

	ALBEDO = vec3(1.0);
	ALPHA = alpha;
}
