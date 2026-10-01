// Kinu Toss: a Kinu lying in a box draws nothing past the box's inner walls or under its floor.
// Ears, tails and wings reach well beyond a Kinu's hitbox, so without this they poke out through
// the walls; the walls themselves hide whatever is cut away. Anything above the rim still draws.
// Only the clipped copies of the Kinu materials set box_clip; TossPlay moves the box uniforms.
uniform bool box_clip = false;
global uniform mat4 toss_box_inverse;
// Inner half-width (x), inner half-depth (y), floor top (z) and rim height (w), in the box's frame.
global uniform vec4 toss_box_inside;

bool box_clipped(vec3 view_vertex, mat4 inv_view) {
	if (!box_clip) {
		return false;
	}
	vec3 at = (toss_box_inverse * (inv_view * vec4(view_vertex, 1.0))).xyz;
	return at.y < toss_box_inside.w && (abs(at.x) > toss_box_inside.x || abs(at.z) > toss_box_inside.y || at.y < toss_box_inside.z);
}
