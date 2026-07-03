#ifndef POST_GLSL
#define POST_GLSL

vec3 bloomBlur(sampler2D tex, vec2 uv, vec2 pixelSize, float intensity, int radius) {
    vec3 color = texture2D(tex, uv).xyz * 0.227;
    int r = min(radius, 8);

    for (int i = 1; i <= r; i++) {
        float weight = 0.076 * exp(-float(i * i) * 0.1);
        vec2 offset = vec2(float(i) * pixelSize.x, 0.0);
        color += texture2D(tex, uv + offset).xyz * weight;
        color += texture2D(tex, uv - offset).xyz * weight;
    }
    for (int i = 1; i <= r; i++) {
        float weight = 0.076 * exp(-float(i * i) * 0.1);
        vec2 offset = vec2(0.0, float(i) * pixelSize.y);
        color += texture2D(tex, uv + offset).xyz * weight;
        color += texture2D(tex, uv - offset).xyz * weight;
    }

    return color * intensity;
}

float getLensFlare(vec2 uv, vec3 sunPosScreen) {
    vec2 sunUV = sunPosScreen.xy * 0.5 + 0.5;
    vec2 dir = sunUV - uv;
    float dist = length(dir);
    float flare = 0.0;

    flare += smoothstep(0.5, 0.0, dist) * 0.3;
    for (int i = 1; i <= 5; i++) {
        float t = float(i) * 0.12;
        vec2 ghost = uv + dir * t;
        if (ghost.x >= 0.0 && ghost.x <= 1.0 && ghost.y >= 0.0 && ghost.y <= 1.0) {
            float ghostDist = length(ghost - sunUV);
            flare += smoothstep(0.15, 0.0, ghostDist) * 0.08 / float(i);
        }
    }

    return min(flare, 1.0);
}

float dofGather(sampler2D colorTex, sampler2D depthTex, vec2 uv, vec2 pixelSize, float focusDistance, float aperture) {
    float depth = texture2D(depthTex, uv).r;
    float coc = abs(depth - focusDistance) * aperture;
    coc = clamp(coc, 0.0, 1.0);

    if (coc < 0.001) return texture2D(colorTex, uv).xyz;

    vec3 color = vec3(0.0);
    float totalWeight = 0.0;
    int samples = int(mix(8.0, 24.0, coc));

    for (int i = 0; i < samples; i++) {
        float angle = float(i) * 6.283 / float(samples);
        float radius = sqrt(float(i) / float(samples)) * coc;
        vec2 offset = vec2(cos(angle), sin(angle)) * radius * pixelSize * 20.0;
        vec2 sampleUV = uv + offset;

        if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
            float weight = exp(-radius * radius * 4.0);
            color += texture2D(colorTex, sampleUV).xyz * weight;
            totalWeight += weight;
        }
    }
    return totalWeight > 0.0 ? color / totalWeight : texture2D(colorTex, uv).xyz;
}

vec3 motionBlur(vec2 uv, vec2 velocity, sampler2D colorTex, int samples) {
    vec3 color = vec3(0.0);
    int s = min(samples, 16);
    vec2 step = velocity / float(s);

    for (int i = 0; i < s; i++) {
        vec2 sampleUV = uv - step * float(i);
        if (sampleUV.x >= 0.0 && sampleUV.x <= 1.0 && sampleUV.y >= 0.0 && sampleUV.y <= 1.0) {
            color += texture2D(colorTex, sampleUV).xyz;
        }
    }

    return color / float(s);
}

vec3 chromaticAberration(sampler2D tex, vec2 uv, float intensity) {
    float r = texture2D(tex, uv + vec2(intensity, 0.0)).r;
    float g = texture2D(tex, uv).g;
    float b = texture2D(tex, uv - vec2(intensity, 0.0)).b;
    return vec3(r, g, b);
}

float vignette(vec2 uv, float intensity) {
    vec2 center = uv - 0.5;
    float dist = length(center);
    return 1.0 - smoothstep(0.3, 0.8, dist) * intensity;
}

float filmGrain(vec2 uv, float time) {
    float grain = hash1(uv + vec2(time * 0.1, 0.0));
    return (grain - 0.5) * 0.05;
}

#endif
