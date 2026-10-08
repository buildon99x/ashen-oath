shader_type canvas_item;
void fragment() {
    vec4 tex = texture(TEXTURE, UV);
    if (tex.a < 0.10) discard;
    // COLOR already contains the sampled texture and vertex tint.
}
