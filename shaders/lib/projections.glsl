#ifndef PROJECTIONS_GLSL
#define PROJECTIONS_GLSL

vec3 toClipSpace3(vec3 viewPos) {
    vec4 clip = gbufferProjection * vec4(viewPos, 1.0);
    return clip.xyz / clip.w;
}

vec3 toScreenSpace(vec3 clipPos) {
    return clipPos * 0.5 + 0.5;
}

vec3 toViewSpace(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

float linZ(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}

float invLinZ(float linearDepth) {
    return (far + near - 2.0 * near / linearDepth) / (far - near);
}

#endif
