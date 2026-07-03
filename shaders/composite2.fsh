#version 120

/* RENDERTARGETS: 3 */

varying vec2 texcoord;

uniform sampler2D colortex3;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

void main() {
    vec3 color = texture2D(colortex3, texcoord).rgb;

    // Extract bright parts
    vec3 bloom = max(color - 0.8, vec3(0.0));

    // Simple Kawase-style blur: sample 4 corners of a box
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);
    float radius = 2.0;
    vec2 off1 = vec2(-radius, -radius) * texelSize;
    vec2 off2 = vec2( radius, -radius) * texelSize;
    vec2 off3 = vec2(-radius,  radius) * texelSize;
    vec2 off4 = vec2( radius,  radius) * texelSize;

    vec3 blur = vec3(0.0);
    blur += texture2D(colortex3, texcoord + off1).rgb;
    blur += texture2D(colortex3, texcoord + off2).rgb;
    blur += texture2D(colortex3, texcoord + off3).rgb;
    blur += texture2D(colortex3, texcoord + off4).rgb;
    blur /= 4.0;

    // Extract brights from blurred version too
    vec3 bloomBlur = max(blur - 0.8, vec3(0.0));

    // Combine
    vec3 bloomResult = bloom * 0.5 + bloomBlur * 0.3;
    float bloomStrength = 0.3;

    color += bloomResult * bloomStrength;

    gl_FragData[0] = vec4(color, 1.0);
}
