#version 120

/* RENDERTARGETS: 0,5 */

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform float near;
uniform float far;

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

void main() {
    vec3 color = texture2D(colortex0, texcoord).rgb;
    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(color, 1.0);
}
