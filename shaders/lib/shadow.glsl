#ifndef SHADOW_GLSL
#define SHADOW_GLSL

vec2 getShadowMapCoords(vec3 worldPos) {
    return worldPos.xz / 2048.0 + 0.5;
}

float sampleShadowMap(sampler2D shadowMap, vec3 shadowPos, float bias) {
    float shadowDepth = texture2D(shadowMap, shadowPos.xy).r;
    return step(shadowPos.z - bias, shadowDepth);
}

float sampleShadowMapPCSS(sampler2D shadowMap, vec3 shadowPos, float softness) {
    float blockerSum = 0.0;
    float blockerCount = 0.0;
    float searchRadius = softness * 0.005;
    int samples = 8;

    for (int i = 0; i < samples; i++) {
        vec2 offset = vec2(cos(float(i) * 0.785), sin(float(i) * 0.785)) * searchRadius;
        float depth = texture2D(shadowMap, shadowPos.xy + offset).r;
        if (depth < shadowPos.z) {
            blockerSum += depth;
            blockerCount += 1.0;
        }
    }

    float blockerDepth = blockerCount > 0.0 ? blockerSum / blockerCount : 1.0;
    float penumbra = (shadowPos.z - blockerDepth) / blockerDepth * softness;
    penumbra = clamp(penumbra, 0.0, 0.01);

    float shadow = 0.0;
    int pcfSamples = 16;
    for (int i = 0; i < pcfSamples; i++) {
        float angle = float(i) * 6.283 / float(pcfSamples) + hash1(float(i));
        float radius = hash1(float(i * 2)) * penumbra;
        vec2 offset = vec2(cos(angle), sin(angle)) * radius;
        float depth = texture2D(shadowMap, shadowPos.xy + offset).r;
        shadow += step(shadowPos.z - 0.001, depth);
    }
    return shadow / float(pcfSamples);
}

float getShadow(sampler2D shadowMap, vec3 worldPos, vec3 lightDir, float depth) {
    vec2 shadowUV = getShadowMapCoords(worldPos);
    if (shadowUV.x < 0.0 || shadowUV.x > 1.0 || shadowUV.y < 0.0 || shadowUV.y > 1.0) {
        return 1.0;
    }
    vec3 shadowPos = vec3(shadowUV, depth);
    float bias = max(0.0005 * (1.0 - dot(normalize(lightDir), vec3(0.0, 1.0, 0.0))), 0.0001);
    return sampleShadowMapPCSS(shadowMap, shadowPos, 0.5);
}

#endif
