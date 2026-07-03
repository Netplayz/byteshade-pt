#version 120

/* RENDERTARGETS: 0 */

varying vec2 texcoord;
varying vec4 glcolor;
varying vec3 normal;

uniform sampler2D texture;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    gl_FragData[0] = albedo;
}
