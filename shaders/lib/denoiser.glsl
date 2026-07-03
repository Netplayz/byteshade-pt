#ifndef DENOISER_GLSL
#define DENOISER_GLSL

float calculateLuminanceWeight(vec3 c1, vec3 c2, float sigma) {
    float lum1 = getLuminance(c1);
    float lum2 = getLuminance(c2);
    float diff = abs(lum1 - lum2);
    return exp(-(diff * diff) / (2.0 * sigma * sigma));
}

vec4 temporalAccumulate(vec3 color, vec2 motionVector, float depth, vec3 normal, sampler2D historyTex, float blendFactor) {
    vec2 historyUV = gl_FragCoord.xy + motionVector;
    vec4 history = texture2D(historyTex, historyUV);
    float historyLum = getLuminance(history.xyz);
    float currentLum = getLuminance(color);
    float blend = clamp(blendFactor, 0.0, 0.95);

    float variance = abs(historyLum - currentLum);
    float varianceWeight = exp(-variance * 10.0);
    blend *= mix(0.1, 1.0, varianceWeight);

    vec3 accumulated = mix(history.xyz, color, blend);
    float alpha = mix(history.a, 1.0, blend);

    return vec4(accumulated, alpha);
}

vec3 svgfFilter(sampler2D colorTex, sampler2D depthTex, sampler2D normalTex, vec2 uv, vec2 pixelSize, float depthThreshold, float normalThreshold) {
    vec3 centerColor = texture2D(colorTex, uv).xyz;
    float centerDepth = texture2D(depthTex, uv).r;
    vec3 centerNormal = texture2D(normalTex, uv).xyz;

    vec3 result = centerColor;
    float totalWeight = 1.0;
    int radius = 2;

    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            if (x == 0 && y == 0) continue;

            vec2 sampleUV = uv + vec2(float(x), float(y)) * pixelSize;
            if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) continue;

            vec3 sampleColor = texture2D(colorTex, sampleUV).xyz;
            float sampleDepth = texture2D(depthTex, sampleUV).r;
            vec3 sampleNormal = texture2D(normalTex, sampleUV).xyz;

            float spatialWeight = exp(-float(x * x + y * y) * 0.5);
            float depthWeight = exp(-abs(sampleDepth - centerDepth) / depthThreshold);
            float normalWeight = exp(-(1.0 - dot(sampleNormal, centerNormal)) / normalThreshold);
            float luminanceWeight = calculateLuminanceWeight(sampleColor, centerColor, 0.1);

            float weight = spatialWeight * depthWeight * normalWeight * luminanceWeight;
            result += sampleColor * weight;
            totalWeight += weight;
        }
    }

    return result / totalWeight;
}

vec3 bilateralFilter(sampler2D tex, sampler2D depthTex, sampler2D normalTex, vec2 uv, vec2 pixelSize, float sigmaDepth, float sigmaNormal) {
    vec3 centerColor = texture2D(tex, uv).xyz;
    float centerDepth = texture2D(depthTex, uv).r;
    vec3 centerNormal = texture2D(normalTex, uv).xyz;

    vec3 result = centerColor;
    float totalWeight = 1.0;
    int radius = 2;

    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            if (x == 0 && y == 0) continue;

            vec2 sampleUV = uv + vec2(float(x), float(y)) * pixelSize;
            if (sampleUV.x < 0.0 || sampleUV.x > 1.0 || sampleUV.y < 0.0 || sampleUV.y > 1.0) continue;

            vec3 sampleColor = texture2D(tex, sampleUV).xyz;
            float sampleDepth = texture2D(depthTex, sampleUV).r;
            vec3 sampleNormal = texture2D(normalTex, sampleUV).xyz;

            float spatialWeight = exp(-float(x * x + y * y) * 0.5);
            float depthWeight = exp(-abs(sampleDepth - centerDepth) * 0.5 / sigmaDepth);
            float normalWeight = exp(-(1.0 - dot(sampleNormal, centerNormal)) / sigmaNormal);

            float weight = spatialWeight * depthWeight * normalWeight;
            result += sampleColor * weight;
            totalWeight += weight;
        }
    }

    return result / totalWeight;
}

#endif
