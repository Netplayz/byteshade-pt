#version 120

/* RENDERTARGETS: 0 */

varying vec2 texcoord;

uniform sampler2D colortex3;
uniform float frameTimeCounter;

vec3 acesFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

void main() {
    vec3 color = texture2D(colortex3, texcoord).rgb;
    color = acesFilm(color);
    float grain = fract(sin(dot(texcoord + frameTimeCounter * 0.001, vec2(12.9898, 78.233))) * 43758.5453);
    color += (grain - 0.5) * 0.008;
    color = pow(color, vec3(1.0 / 2.2));
    gl_FragData[0] = vec4(color, 1.0);
}
