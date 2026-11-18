// Grays and darkens what is drawn under it, inside its own shape: a permanent whose cast
// from the top of the library is Spent this turn (game ADR 0055).
shader_type canvas_item;

uniform sampler2D screen: hint_screen_texture, filter_nearest;

void fragment() {
	vec3 under = texture(screen, SCREEN_UV).rgb;
	float gray = dot(under, vec3(0.3, 0.59, 0.11));
	COLOR = vec4(mix(under, vec3(gray), 0.75) * 0.62, COLOR.a);
}
