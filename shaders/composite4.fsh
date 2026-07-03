#version 120

/* RENDERTARGETS: 3 */

varying vec2 texcoord;

uniform sampler2D colortex3;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;

float linearizeDepth(float d) {
    return (2.0 * near) / (far + near - d * (far - near));
}

void main() {
    float depth = texture2D(depthtex0, texcoord).r;
    float linDepth = linearizeDepth(depth);

    // Circle of confusion: focus at ~8 blocks, blur far/near
    float focusDist = 8.0 / far;
    float coc = abs(linDepth - focusDist) * 20.0;
    coc = clamp(coc, 0.0, 1.0);

    if (coc < 0.01) {
        gl_FragData[0] = texture2D(colortex3, texcoord);
        return;
    }

    vec3 color = vec3(0.0);
    float total = 0.0;
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);
    float radius = coc * 5.0;

    // Simple disc blur
    for (int i = 0; i < 12; i++) {
        float angle = float(i) * 6.28318530718 / 12.0 + 0.1;
        float r = (float(i) / 12.0) * radius;
        vec2 offset = vec2(cos(angle), sin(angle)) * r * texelSize;
        float weight = 1.0 - r / radius;
        color += texture2D(colortex3, texcoord + offset).rgb * weight;
        total += weight;
    }

    color /= total;
    gl_FragData[0] = vec4(color, 1.0);
}
