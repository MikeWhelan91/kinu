shader_type spatial;
// See-through toon surface that never writes depth, for small clear parts that overlap each other
// (capsule domes). Writing depth made nearer domes hide farther ones depending on draw order.
render_mode blend_mix, depth_draw_opaque, cull_back;

#define TOON_GLASS
#include "res://resources/shaders/toon_core.gdshaderinc"
