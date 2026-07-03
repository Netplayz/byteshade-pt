#version 120

/* RENDERTARGETS: 0,5 */

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;
uniform vec3 skyColor;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform float wetness;
uniform float sunAngle;
uniform float shadowAngle;
uniform int isEyeInWater;
uniform int moonPhase;

uniform float nightVision;
uniform float screenBrightness;

const float PI = 3.14159265359;
const float TAU = 6.28318530718;

vec3 decodeNormal(vec2 enc) {
    vec3 n;
    n.xy = enc * 2.0 - 1.0;
    n.z = 1.0 - abs(n.x) - abs(n.y);
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

vec3 getWorldPos(vec2 uv, float depth) {
    vec3 viewPos = getViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;
    return worldPos + cameraPosition;
}

vec3 getViewDir(vec2 uv) {
    return normalize(getViewPos(uv, 1.0));
}

float distributionGGX(float NdotH, float roughness) {
    float a = roughness * roughness;
    float a2 = a * a;
    float denom = NdotH * NdotH * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom);
}

float geometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = r * r / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float geometrySmith(vec3 N, vec3 V, vec3 L, float roughness) {
    float NdotV = max(dot(N, V), 0.0);
    float NdotL = max(dot(N, L), 0.0);
    return geometrySchlickGGX(NdotV, roughness) * geometrySchlickGGX(NdotL, roughness);
}

vec3 fresnelSchlick(float cosTheta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

float sampleShadow(sampler2D shadowMap, vec3 shadowPos) {
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 || shadowPos.y < 0.0 || shadowPos.y > 1.0 || shadowPos.z < 0.0 || shadowPos.z > 1.0) return 1.0;
    float bias = 0.002;
    float visibility = 0.0;
    vec2 texelSize = 1.0 / vec2(textureSize(shadowMap, 0));
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 offset = vec2(float(x), float(y)) * texelSize;
            float depth = texture(shadowMap, shadowPos.xy + offset).r;
            visibility += step(shadowPos.z - bias, depth);
        }
    }
    return visibility / 9.0;
}

vec3 getShadowMapPos(vec3 worldPos) {
    vec4 shadowView = shadowModelView * vec4(worldPos, 1.0);
    vec4 shadowClip = shadowProjection * shadowView;
    vec3 shadowPos = shadowClip.xyz / shadowClip.w;
    return shadowPos * 0.5 + 0.5;
}

float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

bool rayMarchScreen(vec3 origin, vec3 dir, float maxDist, out vec3 hitUVZ, vec2 screenSize, sampler2D depthTex) {
    vec3 viewPos = origin;
    float totalDist = 0.0;
    float stepSize = maxDist / 48.0;

    for (int i = 0; i < 64; i++) {
        viewPos += dir * stepSize;
        totalDist += stepSize;
        if (totalDist > maxDist) return false;

        vec4 clipPos = gbufferProjection * vec4(viewPos, 1.0);
        vec3 ndc = clipPos.xyz / clipPos.w;
        if (abs(ndc.x) > 1.0 || abs(ndc.y) > 1.0 || ndc.z > 1.0 || ndc.z < 0.0) {
            stepSize *= 1.3;
            continue;
        }

        vec2 uv = ndc.xy * 0.5 + 0.5;
        float sceneDepth = texture2D(depthTex, uv).r;
        float linScene = linearizeDepth(sceneDepth, near, far);
        float linView = abs(viewPos.z);

        if (linView < linScene + 0.05 && linView > linScene - 0.05) {
            for (int j = 0; j < 6; j++) {
                stepSize *= 0.5;
                viewPos -= dir * stepSize;
                clipPos = gbufferProjection * vec4(viewPos, 1.0);
                ndc = clipPos.xyz / clipPos.w;
                uv = ndc.xy * 0.5 + 0.5;
                sceneDepth = texture2D(depthTex, uv).r;
                linScene = linearizeDepth(sceneDepth, near, far);
                linView = abs(viewPos.z);
                if (linView < linScene) viewPos += dir * stepSize;
            }
            clipPos = gbufferProjection * vec4(viewPos, 1.0);
            ndc = clipPos.xyz / clipPos.w;
            hitUVZ = vec3(ndc.xy * 0.5 + 0.5, linView);
            return true;
        }
        if (linView > linScene) stepSize *= 0.8;
        else stepSize *= 1.2;
    }
    return false;
}

vec3 getSkyRadiance(vec3 viewDir, vec3 sunDir) {
    float cosTheta = dot(viewDir, sunDir);
    float cosThetaSun = max(cosTheta, 0.0);

    float rayleigh = 1.0 + cosThetaSun * cosThetaSun;
    float mie = (1.0 - 0.85 * 0.85) / (4.0 * PI * pow(1.0 + 0.85 * 0.85 - 2.0 * 0.85 * cosTheta, 1.5));

    vec3 rayleighColor = vec3(0.3, 0.6, 1.0) * rayleigh * 0.15;
    vec3 mieColor = vec3(1.0, 0.85, 0.6) * mie * 0.4;

    float height = max(viewDir.y * 0.5 + 0.5, 0.0);
    vec3 nightColor = vec3(0.01, 0.01, 0.03) * (1.0 - height);

    float sunHeight = sunDir.y;
    float dayFactor = smoothstep(-0.1, 0.2, sunHeight);

    vec3 result = rayleighColor + mieColor + nightColor;
    result *= dayFactor + 0.05;

    float sunDisk = smoothstep(0.9995, 1.0, cosThetaSun);
    result += vec3(1.0, 0.8, 0.4) * sunDisk * 10.0 * dayFactor;

    return max(result, vec3(0.0));
}

vec3 getIndirectLight(vec3 viewPos, vec3 normal, vec3 albedo, float roughness, vec2 screenSize, sampler2D depthTex) {
    vec3 indirect = vec3(0.0);
    int samples = 3;
    float maxDist = 8.0;

    for (int i = 0; i < samples; i++) {
        float r1 = rand(texcoord + vec2(float(i) * 1.7, frameTimeCounter * 0.01));
        float r2 = rand(texcoord + vec2(float(i) * 3.1, frameTimeCounter * 0.02));

        float phi = TAU * r1;
        float cosTheta = sqrt(1.0 - r2);
        float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

        vec3 sampleDir;
        sampleDir.x = cos(phi) * sinTheta;
        sampleDir.y = cosTheta;
        sampleDir.z = sin(phi) * sinTheta;

        vec3 up = abs(normal.y) < 0.999 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
        vec3 T = normalize(cross(up, normal));
        vec3 B = cross(normal, T);
        vec3 dir = normalize(T * sampleDir.x + normal * sampleDir.y + B * sampleDir.z);

        vec3 hitUVZ;
        if (rayMarchScreen(viewPos, dir, maxDist, hitUVZ, screenSize, depthTex)) {
            vec2 hitUV = hitUVZ.xy;
            vec3 hitAlbedo = texture2D(colortex0, hitUV).rgb;
            vec3 hitNormalEnc = texture2D(colortex1, hitUV).rgb;
            vec3 hitNormalDec = decodeNormal(hitNormalEnc.rg);
            float NdotL = max(dot(hitNormalDec, -dir), 0.0);
            if (NdotL > 0.0) {
                indirect += hitAlbedo * NdotL * (1.0 / PI);
            }
        } else {
            vec3 worldDir = normalize((gbufferModelViewInverse * vec4(dir, 0.0)).xyz);
            vec3 sunDir = normalize(sunPosition);
            indirect += getSkyRadiance(worldDir, sunDir) * 0.5;
        }
    }
    return indirect / float(samples) * albedo * 0.5;
}

void main() {
    vec2 uv = texcoord;
    float depth = texture2D(depthtex0, uv).r;
    float linDepth = linearizeDepth(depth, near, far);
    float farLin = linearizeDepth(1.0, near, far);
    bool isSky = linDepth > farLin * 0.98;

    vec3 sunDir = normalize(sunPosition);
    vec3 worldViewDir = normalize((gbufferModelViewInverse * vec4(normalize(getViewPos(uv, 1.0)), 0.0)).xyz);
    vec3 skyRad = getSkyRadiance(worldViewDir, sunDir);

    if (isSky) {
        gl_FragData[0] = vec4(skyRad, 1.0);
        gl_FragData[1] = vec4(skyRad, 1.0);
        return;
    }

    vec4 c0 = texture2D(colortex0, uv);
    vec4 c1 = texture2D(colortex1, uv);
    vec4 c2 = texture2D(colortex2, uv);
    vec4 c3 = texture2D(colortex3, uv);

    vec3 albedo = c0.rgb;
    float roughness = max(c0.a, 0.001);
    float metallic = c1.a;
    float emission = c2.r;
    float specular = c2.g;
    float flags = c2.b;
    vec3 lightColor = max(c3.gba, vec3(0.001));

    vec3 normal = decodeNormal(c1.rg);
    vec3 viewPos = getViewPos(uv, depth);
    vec3 worldPos = getWorldPos(uv, depth);
    vec3 viewDir = normalize(-viewPos);

    vec3 lightDir = sunDir;
    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    float NdotV = max(dot(normal, viewDir), 0.001);

    float NdotL = max(dot(normal, lightDir), 0.0);
    vec3 H = normalize(viewDir + lightDir);
    float NdotH = max(dot(normal, H), 0.001);
    float VdotH = max(dot(viewDir, H), 0.001);

    vec3 shadowPos = getShadowMapPos(worldPos);
    float shadow = sampleShadow(shadowtex0, shadowPos);

    vec3 kD = vec3(1.0) - fresnelSchlick(NdotV, F0);
    kD *= 1.0 - metallic;

    vec3 directDiffuse = kD * albedo / PI;
    vec3 directSpecular = fresnelSchlick(VdotH, F0) * distributionGGX(NdotH, roughness) * geometrySmith(normal, viewDir, lightDir, roughness) / (4.0 * NdotV * NdotL + 0.0001);
    vec3 directLight = (directDiffuse + directSpecular) * NdotL * shadow;

    vec3 ambientLight = lightColor;

    // Screen-space reflections
    vec3 ssr = vec3(0.0);
    float fresnel = pow(1.0 - NdotV, 5.0);
    float reflectivity = mix(fresnel, 1.0, metallic) * specular;
    vec2 screenSize = vec2(viewWidth, viewHeight);
    if (reflectivity > 0.01) {
        vec3 reflectDir = reflect(viewDir, normal);
        vec3 hitUVZ;
        float maxReflDist = mix(2.0, 16.0, 1.0 - roughness);
        if (rayMarchScreen(viewPos, reflectDir, maxReflDist, hitUVZ, screenSize, depthtex0)) {
            ssr = texture2D(colortex0, hitUVZ.xy).rgb;
            float distFade = smoothstep(maxReflDist, 0.0, hitUVZ.z);
            ssr *= distFade * reflectivity;
        } else {
            vec3 reflWorldDir = normalize((gbufferModelViewInverse * vec4(reflectDir, 0.0)).xyz);
            ssr = getSkyRadiance(reflWorldDir, sunDir) * reflectivity;
        }
    }

    vec3 indirect = getIndirectLight(viewPos, normal, albedo, roughness, screenSize, depthtex0);

    vec3 color = directLight + ambientLight * albedo + indirect;
    color = mix(color, ssr, reflectivity * 0.5);
    color += emission * albedo * 5.0;

    float fogDist = length(viewPos);
    float fogFactor = 1.0 - exp(-fogDist * 0.006);
    color = mix(color, skyRad, fogFactor);

    if (isEyeInWater == 1) {
        float waterDepth = linDepth * far;
        color = mix(color, vec3(0.1, 0.3, 0.4), 1.0 - exp(-waterDepth * 2.0));
    } else if (flags > 1.5 && flags < 2.5) {
        color = mix(color, vec3(0.2, 0.5, 0.6), 0.3);
    }

    color = max(color, vec3(0.0));

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(color, 1.0);
}
