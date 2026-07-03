#ifndef SSR_GLSL
#define SSR_GLSL

bool rayMarch(vec3 origin, vec3 direction, float maxDist, out vec3 hitPos, out vec3 hitNormal, out vec3 hitAlbedo, vec2 screenSize, sampler2D depthTex, sampler2D normalTex, sampler2D albedoTex) {
    vec3 pos = origin;
    float dist = 0.0;
    float stepSize = 0.5;

    for (int i = 0; i < 64; i++) {
        pos += direction * stepSize;
        dist += stepSize;

        if (dist > maxDist) return false;

        vec4 clipPos = gl_ProjectionMatrix * vec4(pos, 1.0);
        vec3 ndc = clipPos.xyz / clipPos.w;
        vec2 uv = ndc.xy * 0.5 + 0.5;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) continue;

        float sampleDepth = texture2D(depthTex, uv).r;
        float linearSample = linearizeDepth(sampleDepth, 0.1, 256.0);
        float linearPos = linearizeDepth(ndc.z * 0.5 + 0.5, 0.1, 256.0);

        if (linearPos > linearSample - 0.01 && linearPos < linearSample + 0.01) {
            for (int j = 0; j < 8; j++) {
                stepSize *= 0.5;
                pos -= direction * stepSize;
                dist -= stepSize;

                clipPos = gl_ProjectionMatrix * vec4(pos, 1.0);
                ndc = clipPos.xyz / clipPos.w;
                uv = ndc.xy * 0.5 + 0.5;

                if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;

                sampleDepth = texture2D(depthTex, uv).r;
                linearSample = linearizeDepth(sampleDepth, 0.1, 256.0);
                linearPos = linearizeDepth(ndc.z * 0.5 + 0.5, 0.1, 256.0);

                if (linearPos > linearSample) {
                    pos += direction * stepSize;
                    dist += stepSize;
                }
            }

            clipPos = gl_ProjectionMatrix * vec4(pos, 1.0);
            ndc = clipPos.xyz / clipPos.w;
            uv = ndc.xy * 0.5 + 0.5;

            if (uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0) {
                hitPos = pos;
                hitNormal = texture2D(normalTex, uv).xyz;
                hitAlbedo = texture2D(albedoTex, uv).xyz;
                return true;
            }
            return false;
        }

        stepSize *= 1.1;
    }
    return false;
}

vec3 getSSR(vec3 viewPos, vec3 normal, vec3 viewDir, float roughness, vec2 screenSize, sampler2D depthTex, sampler2D normalTex, sampler2D colortex0Tex, sampler2D colortex1Tex) {
    vec3 reflected = reflect(normalize(viewPos), normal);
    float maxDist = mix(64.0, 16.0, roughness);
    float coneSpread = mix(0.0, 0.05, roughness);

    vec3 hitPos;
    vec3 hitNormal;
    vec3 hitAlbedo;

    bool hit = rayMarch(viewPos, reflected, maxDist, hitPos, hitNormal, hitAlbedo, screenSize, depthTex, normalTex, colortex0Tex);
    if (!hit) return vec3(0.0);

    float NdotR = max(dot(normal, normalize(reflected)), 0.0);
    float fresnel = pow(1.0 - NdotR, 5.0);
    float visibility = 1.0 - smoothstep(0.0, 1.0, roughness);

    return hitAlbedo * fresnel * visibility * 0.5;
}

#endif
