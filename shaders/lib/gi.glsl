#ifndef GI_GLSL
#define GI_GLSL

vec3 cosineHemisphereSample(vec2 Xi) {
    float theta = 2.0 * PI * Xi.x;
    float r = sqrt(Xi.y);
    return vec3(cos(theta) * r, sin(theta) * r, sqrt(1.0 - Xi.y));
}

vec3 TangentToWorld(vec3 N, vec3 H) {
    vec3 up = abs(N.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
    vec3 tangent = normalize(cross(up, N));
    vec3 bitangent = cross(N, tangent);
    return normalize(tangent * H.x + bitangent * H.y + N * H.z);
}

vec3 rayTrace_GI(vec3 dir, vec3 position, float dither, float quality) {
    float maxDist = 32.0;
    float t = min(maxDist, -position.z * 0.99 / max(dir.z, 0.001));
    vec3 endPos = position + dir * t;

    vec4 startClip = gbufferProjection * vec4(position, 1.0);
    vec4 endClip = gbufferProjection * vec4(endPos, 1.0);
    vec3 clipStart = startClip.xyz / startClip.w;
    vec3 clipEnd = endClip.xyz / endClip.w;

    vec2 screenStart = clipStart.xy * 0.5 + 0.5;
    vec2 screenEnd = clipEnd.xy * 0.5 + 0.5;

    vec2 deltaScreen = screenEnd - screenStart;
    float depthStart = clipStart.z;
    float depthEnd = clipEnd.z;
    float deltaDepth = depthEnd - depthStart;

    float steps = max(abs(deltaScreen.x) * viewWidth, abs(deltaScreen.y) * viewHeight);
    steps = clamp(steps, 1.0, quality * 4.0);

    vec2 stepScreen = deltaScreen / steps;
    float stepDepth = deltaDepth / steps;

    vec2 uv = screenStart + stepScreen * dither;
    float clipDepth = depthStart + stepDepth * dither;

    for (float i = 0.0; i < steps; i += 1.0) {
        uv += stepScreen;
        clipDepth += stepDepth;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            return vec3(1.1, 1.1, 1.1);
        }

        float sampledDepth = texture2D(depthtex1, uv).r;

        float rayLin = (2.0 * near) / (far + near - (clipDepth * 0.5 + 0.5) * (far - near));
        float sampleLin = (2.0 * near) / (far + near - sampledDepth * (far - near));

        float depthDiff = rayLin - sampleLin;

        if (depthDiff > 0.001 && depthDiff < t * 0.5) {
            return vec3(uv, sampleLin);
        }
    }

    return vec3(1.1, 1.1, 1.1);
}

vec3 RT_alternate(vec3 dir, vec3 position, float dither, float quality, out float CURVE) {
    float maxDist = 32.0;
    float t = min(maxDist, -position.z * 0.99 / max(dir.z, 0.001));
    vec3 endPos = position + dir * t;

    vec4 startClip = gbufferProjection * vec4(position, 1.0);
    vec4 endClip = gbufferProjection * vec4(endPos, 1.0);
    vec3 clipStart = startClip.xyz / startClip.w;
    vec3 clipEnd = endClip.xyz / endClip.w;

    vec2 screenStart = clipStart.xy * 0.5 + 0.5;
    vec2 screenEnd = clipEnd.xy * 0.5 + 0.5;

    vec2 deltaScreen = screenEnd - screenStart;
    float depthStart = clipStart.z;
    float depthEnd = clipEnd.z;
    float deltaDepth = depthEnd - depthStart;

    float coarseSteps = max(abs(deltaScreen.x) * viewWidth, abs(deltaScreen.y) * viewHeight) * 0.25;
    coarseSteps = clamp(coarseSteps, 1.0, quality * 2.0);

    vec2 stepScreen = deltaScreen / coarseSteps;
    float stepDepth = deltaDepth / coarseSteps;

    vec2 uv = screenStart + stepScreen * dither;
    float clipDepth = depthStart + stepDepth * dither;

    vec2 prevUv = screenStart;
    float prevDepth = depthStart;

    for (float i = 0.0; i < coarseSteps; i += 1.0) {
        prevUv = uv;
        prevDepth = clipDepth;

        uv += stepScreen;
        clipDepth += stepDepth;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            CURVE = 0.0;
            return vec3(1.1, 1.1, 1.1);
        }

        float sampledDepth = texture2D(depthtex1, uv).r;

        float rayLin = (2.0 * near) / (far + near - (clipDepth * 0.5 + 0.5) * (far - near));
        float sampleLin = (2.0 * near) / (far + near - sampledDepth * (far - near));

        float depthDiff = rayLin - sampleLin;

        if (depthDiff > 0.0) {
            vec2 lowUv = prevUv;
            vec2 highUv = uv;
            float lowDepth = prevDepth;
            float highDepth = clipDepth;

            for (float j = 0.0; j < 6.0; j += 1.0) {
                vec2 midUv = (lowUv + highUv) * 0.5;
                float midDepth = (lowDepth + highDepth) * 0.5;

                float midLin = (2.0 * near) / (far + near - (midDepth * 0.5 + 0.5) * (far - near));
                float samLin = (2.0 * near) / (far + near - texture2D(depthtex1, midUv).r * (far - near));

                if (midLin > samLin) {
                    highUv = midUv;
                    highDepth = midDepth;
                } else {
                    lowUv = midUv;
                    lowDepth = midDepth;
                }
            }

            vec2 finalUv = (lowUv + highUv) * 0.5;
            float finalDepth = texture2D(depthtex1, finalUv).r;
            float finalLin = (2.0 * near) / (far + near - finalDepth * (far - near));
            CURVE = 1.0;
            return vec3(finalUv, finalLin);
        }
    }

    CURVE = 0.0;
    return vec3(1.1, 1.1, 1.1);
}

vec3 getSkyColor(vec3 dir, float sunVisibility, vec3 sunVec) {
    float NdotL = max(dot(dir, sunVec), 0.0);
    vec3 sky = mix(vec3(0.02, 0.03, 0.06), vec3(0.1, 0.2, 0.4), sunVisibility);
    vec3 sunColor = vec3(1.0, 0.7, 0.3) * pow(NdotL, 20.0) * 5.0 * sunVisibility;
    vec3 horizon = mix(vec3(0.3, 0.4, 0.6), vec3(0.05, 0.05, 0.1), abs(dir.y));
    return sky * horizon + sunColor;
}

vec3 computeSSRTGI(vec3 viewPos, vec3 normal, vec3 noise, vec2 texcoord,
    float sunVisibility, vec3 sunVec, vec3 ambientCol, vec3 lightCol,
    int rayCount, float rayIterations) {

    vec3 radiance = vec3(0.0);

    for (int i = 0; i < 16; i++) {
        if (i >= rayCount) break;

        float fi = float(i);

        vec2 Xi = vec2(
            fract(noise.x + fi * 0.618033988749895),
            fract(noise.y + fi * 0.381966011250105)
        );

        vec3 localDir = cosineHemisphereSample(Xi);
        vec3 dir = TangentToWorld(normal, localDir);

        vec3 hit = rayTrace_GI(dir, viewPos, noise.z + fi * 0.1, rayIterations);

        if (hit.x > 1.0) {
            radiance += getSkyColor(dir, sunVisibility, sunVec);
        } else {
            vec2 hitUV = hit.xy;
            vec3 hitAlbedo = texture2D(colortex0, hitUV).rgb;
            float hitMat = texture2D(colortex0, hitUV).a;

            if (hitMat >= 5.5) {
                radiance += getSkyColor(dir, sunVisibility, sunVec);
            } else {
                radiance += hitAlbedo * (ambientCol + lightCol * 0.5);
            }
        }
    }

    radiance /= float(rayCount);
    radiance *= 2.0;
    return radiance;
}

#endif
