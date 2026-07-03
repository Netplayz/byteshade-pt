#version 120

/* RENDERTARGETS: 3 */

varying vec2 texcoord;

uniform sampler2D colortex3;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

void main() {
    vec2 uv = texcoord;

    // Chromatic aberration
    vec2 center = vec2(0.5);
    vec2 offset = uv - center;
    float dist = length(offset);
    float strength = 0.003;

    float r = texture2D(colortex3, uv + offset * dist * strength * 1.0).r;
    float g = texture2D(colortex3, uv + offset * dist * strength * 0.0).g;
    float b = texture2D(colortex3, uv + offset * dist * strength * (-1.0)).b;

    vec3 color = vec3(r, g, b);

    // Vignette
    float vignette = 1.0 - dist * dist * 0.4;
    color *= vignette;

    gl_FragData[0] = vec4(color, 1.0);
}
