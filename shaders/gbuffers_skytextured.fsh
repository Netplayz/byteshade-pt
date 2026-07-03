#version 120

/* RENDERTARGETS: 0,1 */

varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D texture;

vec3 encodeNormal(vec3 n) {
    n.xy = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * (sign(n.xy) * -2.0 + 1.0);
    return n * 0.5 + 0.5;
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;

    gl_FragData[0] = albedo;
    gl_FragData[1] = vec4(encodeNormal(vec3(0.0, 0.0, 1.0)), 0.0);
}
