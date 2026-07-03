#version 120

/* RENDERTARGETS: 3 */

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 cameraPosition;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float timeAngle;
uniform float sunPathRotation;
uniform float rainStrength;
uniform int isEyeInWater;

const float PI = 3.14159265359;

#define MAT_SKY 6.0

vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

vec3 getSunVec() {
    vec2 rot = vec2(cos(sunPathRotation * 0.01745329252), -sin(sunPathRotation * 0.01745329252));
    float ang = fract(timeAngle - 0.25);
    ang = (ang + (cos(ang * PI) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530718;
    return normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * rot) * 2000.0, 1.0)).xyz);
}

vec3 getUpVec() {
    return normalize(gbufferModelView[1].xyz);
}

vec3 decodeNormal(vec2 enc) {
    vec3 n;
    n.xy = enc * 2.0 - 1.0;
    n.z = 1.0 - abs(n.x) - abs(n.y);
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
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

float sampleShadow(vec3 shadowPos) {
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 || shadowPos.y < 0.0 || shadowPos.y > 1.0 || shadowPos.z < 0.0 || shadowPos.z > 1.0) return 1.0;
    float bias = 0.002;
    float vis = 0.0;
    vec2 texelSize = 1.0 / vec2(2048.0);
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 off = vec2(float(x), float(y)) * texelSize;
            float d = texture2D(shadowtex0, shadowPos.xy + off).r;
            vis += step(shadowPos.z - bias, d);
        }
    }
    return vis / 9.0;
}

vec3 getShadowPos(vec3 wpos) {
    vec4 sv = shadowModelView * vec4(wpos, 1.0);
    vec4 sc = shadowProjection * sv;
    vec3 sp = sc.xyz / sc.w;
    return sp * 0.5 + 0.5;
}

void main() {
    vec4 col0 = texture2D(colortex0, texcoord);
    float matFlag = col0.a;

    if (matFlag >= MAT_SKY - 0.5) {
        gl_FragData[0] = vec4(col0.rgb, 1.0);
        return;
    }

    vec3 albedo = col0.rgb;
    vec3 normal = decodeNormal(texture2D(colortex1, texcoord).rg);
    vec2 lm = texture2D(colortex1, texcoord).ba;
    vec4 mat = texture2D(colortex2, texcoord);
    float roughness = mat.r;
    float metallic = mat.g;
    float sss = mat.b;
    float emission = mat.a;

    float depth = texture2D(depthtex0, texcoord).r;
    vec3 viewPos = getViewPos(texcoord, depth);
    vec3 viewDir = normalize(-viewPos);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    vec3 sunVec = getSunVec();
    vec3 upVec = getUpVec();
    vec3 lightDir = normalize(sunVec);

    float sunVisibility = clamp((dot(sunVec, upVec) + 0.05) * 10.0, 0.0, 1.0);

    vec3 lightMorning = vec3(1.400, 0.582, 0.214);
    vec3 lightDay     = vec3(1.076, 1.208, 1.400);
    vec3 lightEvening = vec3(1.400, 0.582, 0.214);
    vec3 lightNight   = vec3(0.033, 0.053, 0.140);

    vec3 ambientMorning = vec3(0.349, 0.239, 0.282);
    vec3 ambientDay     = vec3(0.275, 0.290, 0.435);
    vec3 ambientEvening = vec3(0.349, 0.239, 0.282);
    vec3 ambientNight   = vec3(0.029, 0.037, 0.087);

    float mefade = 1.0 - clamp(abs(timeAngle - 0.5) * 8.0 - 1.5, 0.0, 1.0);
    float timeBrightness = max(sin(timeAngle * 6.28318530718), 0.0);
    float dfade = 1.0 - pow(1.0 - timeBrightness, 1.5);

    vec3 lightSun = mix(mix(lightMorning, lightEvening, mefade), lightDay, dfade);
    vec3 ambientSun = mix(mix(ambientMorning, ambientEvening, mefade), ambientDay, dfade);

    vec3 lightColSqrt = mix(lightNight, lightSun, sunVisibility);
    vec3 lightCol = lightColSqrt * lightColSqrt;
    vec3 ambientColSqrt = mix(ambientNight, ambientSun, sunVisibility);
    vec3 ambientCol = ambientColSqrt * ambientColSqrt;

    vec3 torchCol = vec3(1.0, 0.45, 0.08) * 4.0;

    float NdotL = max(dot(normal, lightDir), 0.0);

    vec3 shadowPos = getShadowPos(worldPos + cameraPosition);
    float shadow = 1.0;
    if (NdotL > 0.0) {
        shadow = sampleShadow(shadowPos);
    }

    float shadowMult = (1.0 - 0.95 * rainStrength);
    vec3 sceneLighting = mix(ambientCol * lm.y, lightCol, shadow * shadowMult);
    sceneLighting *= lm.y * lm.y;

    float newLightmap = pow(lm.x, 10.0) * 1.6 + lm.x * 0.6;
    vec3 blockLighting = torchCol * newLightmap * newLightmap;

    vec3 color = albedo * (sceneLighting + blockLighting + vec3(0.02));

    vec3 F0 = mix(vec3(0.04), albedo, metallic);
    vec3 H = normalize(viewDir + lightDir);
    float NdotV = max(dot(normal, viewDir), 0.001);
    float NdotH = max(dot(normal, H), 0.001);
    float VdotH = max(dot(viewDir, H), 0.001);

    vec3 specular = fresnelSchlick(VdotH, F0) * distributionGGX(NdotH, roughness) * geometrySmith(normal, viewDir, lightDir, roughness) / (4.0 * NdotV * NdotL + 0.0001);
    color += specular * lightCol * NdotL * shadow * 0.5;

    color += emission * albedo * 2.0;

    color = max(color, vec3(0.0));

    if (isEyeInWater == 1) {
        color *= vec3(0.2, 0.4, 0.6);
    }

    gl_FragData[0] = vec4(color, 1.0);
}
