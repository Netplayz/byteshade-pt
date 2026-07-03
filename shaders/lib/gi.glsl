#ifndef GI_GLSL
#define GI_GLSL

vec3 traceGIRay(vec3 origin, vec3 direction, float maxDist, sampler2D depthTex, sampler2D normalTex, sampler2D colortex0Tex, sampler2D colortex1Tex, vec2 screenSize) {
    vec3 pos = origin;
    float stepSize = 0.3;

    for (int i = 0; i < 48; i++) {
        pos += direction * stepSize;
        float dist = length(pos - origin);
        if (dist > maxDist) return vec3(0.0);

        vec4 clipPos = gl_ProjectionMatrix * vec4(pos, 1.0);
        vec3 ndc = clipPos.xyz / clipPos.w;
        vec2 uv = ndc.xy * 0.5 + 0.5;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) continue;

        float sampleDepth = texture2D(depthTex, uv).r;
        float linearSample = linearizeDepth(sampleDepth, 0.1, 256.0);
        float linearPos = linearizeDepth(ndc.z * 0.5 + 0.5, 0.1, 256.0);
        float depthDiff = linearPos - linearSample;

        if (depthDiff > 0.0 && depthDiff < 0.5) {
            vec3 hitAlbedo = texture2D(colortex0Tex, uv).xyz;
            vec3 hitNormal = texture2D(normalTex, uv).xyz;
            float NdotL = max(dot(normalize(direction), normalize(hitNormal)), 0.0);
            return hitAlbedo * NdotL * (1.0 / PI);
        }

        stepSize *= 1.05;
    }
    return vec3(0.0);
}

vec3 getIndirectLighting(vec3 viewPos, vec3 normal, vec3 albedo, float roughness, vec2 screenSize, sampler2D depthTex, sampler2D normalTex, sampler2D colortex0Tex, sampler2D colortex1Tex) {
    vec3 indirect = vec3(0.0);
    int numRays = int(mix(8.0, 3.0, roughness));

    for (int i = 0; i < numRays; i++) {
        uint seed = uint(i * 123457u + 78901u);
        vec3 randomDir = vec3(
            cos(TAU * float(i) / float(numRays)),
            sin(TAU * float(i) / float(numRays)),
            0.0
        ) * sqrt(max(0.0, 1.0 - hash1(vec2(float(i), roughness))));

        vec3 tangent = normalize(cross(normal, abs(normal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
        vec3 bitangent = cross(normal, tangent);
        vec3 sampleDir = normalize(tangent * randomDir.x + bitangent * randomDir.y + normal * randomDir.z);

        float maxDist = mix(8.0, 4.0, roughness);
        vec3 radiance = traceGIRay(viewPos, sampleDir, maxDist, depthTex, normalTex, colortex0Tex, colortex1Tex, screenSize);
        indirect += radiance;
    }

    indirect /= float(numRays);
    indirect *= albedo * (1.0 - roughness * 0.5);
    return max(indirect, vec3(0.0));
}

float getAmbientOcclusion(vec3 viewPos, vec3 normal, sampler2D depthTex, vec2 screenSize) {
    float ao = 0.0;
    int numSamples = 8;

    for (int i = 0; i < numSamples; i++) {
        float angle = float(i) * TAU / float(numSamples);
        vec3 sampleDir = vec3(cos(angle) * 0.5, sin(angle) * 0.5, 0.5);
        vec3 tangent = normalize(cross(normal, abs(normal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
        vec3 bitangent = cross(normal, tangent);
        vec3 dir = normalize(tangent * sampleDir.x + bitangent * sampleDir.y + normal * sampleDir.z);

        vec3 samplePos = viewPos + dir * 1.0;
        vec4 clipPos = gl_ProjectionMatrix * vec4(samplePos, 1.0);
        vec3 ndc = clipPos.xyz / clipPos.w;
        vec2 uv = ndc.xy * 0.5 + 0.5;

        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            float sampleDepth = texture2D(depthTex, uv).r;
            float linearSample = linearizeDepth(sampleDepth, 0.1, 256.0);
            float linearPos = linearizeDepth(ndc.z * 0.5 + 0.5, 0.1, 256.0);
            if (linearSample > linearPos + 0.01) {
                ao += 1.0;
            }
        }
    }

    return 1.0 - (ao / float(numSamples)) * 0.5;
}

vec3 getEmissiveLighting(vec3 viewPos, vec3 normal, sampler2D colortex0Tex, sampler2D depthTex, vec2 screenSize) {
    vec3 emissionAccum = vec3(0.0);
    int numSamples = 6;

    for (int i = 0; i < numSamples; i++) {
        float angle = float(i) * TAU / float(numSamples) + 0.1;
        vec3 dir = vec3(cos(angle), 0.5 + sin(angle) * 0.3, sin(angle));
        vec3 tangent = normalize(cross(normal, abs(normal.y) < 0.99 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0)));
        vec3 bitangent = cross(normal, tangent);
        vec3 sampleDir = normalize(tangent * dir.x + bitangent * dir.y + normal * dir.z);

        vec3 samplePos = viewPos + sampleDir * 3.0;
        vec4 clipPos = gl_ProjectionMatrix * vec4(samplePos, 1.0);
        vec3 ndc = clipPos.xyz / clipPos.w;
        vec2 uv = ndc.xy * 0.5 + 0.5;

        if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
            float linearSample = linearizeDepth(texture2D(depthTex, uv).r, 0.1, 256.0);
            float linearPos = linearizeDepth(ndc.z * 0.5 + 0.5, 0.1, 256.0);
            if (abs(linearSample - linearPos) < 0.1) {
                vec3 sampleColor = texture2D(colortex0Tex, uv).xyz;
                float lum = getLuminance(sampleColor);
                emissionAccum += sampleColor * step(0.5, lum);
            }
        }
    }

    return emissionAccum / float(numSamples) * 0.3;
}

#endif
