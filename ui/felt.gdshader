shader_type canvas_item;
// Razzia table felt: dark green cloth with fine fibre noise, a soft lamp vignette and a state tint.
// Original shader (no third-party art). `tint` is tweened by the game screen (police / negotiation / game over).
uniform vec4 base_color : source_color = vec4(0.085, 0.27, 0.17, 1.0);
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float tint_amount : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale = 1.0;
uniform float animated = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 px = FRAGCOORD.xy;
	float fibre = vnoise(px * 0.9) * 0.6 + vnoise(px * 0.23) * 0.4;
	float t = TIME * time_scale * animated;
	// slow drifting "smoke / lamp light" patches
	float cloud = vnoise(uv * 3.0 + vec2(t * 0.02, t * 0.013)) * 0.6 + vnoise(uv * 7.0 - vec2(t * 0.015, 0.0)) * 0.4;
	vec3 col = base_color.rgb * (0.78 + 0.34 * fibre) * (0.85 + 0.3 * cloud);
	// vignette: lit in the middle of the table, dark at the corners
	vec2 d = uv - vec2(0.5, 0.46);
	float v = smoothstep(0.95, 0.15, length(d * vec2(1.15, 1.0)));
	col *= mix(0.55, 1.2, v);
	col = mix(col, tint.rgb * (0.5 + 0.5 * fibre) * (0.4 + 0.8 * v), tint_amount);
	COLOR = vec4(col, 1.0);
}
