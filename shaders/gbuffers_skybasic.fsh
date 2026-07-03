#version 150 compatibility

/* RENDERTARGETS: 0 */

in vec2 texcoord;
in vec4 glcolor;
in vec3 normal;

uniform sampler2D texture;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    gl_FragData[0] = albedo;
}
