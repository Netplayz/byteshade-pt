#version 120

/* RENDERTARGETS: 3,4 */

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D shadowtex0;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;
uniform mat4 shadowProjection;
uniform mat4 shadowModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float timeAngle;
uniform float sunPathRotation;
uniform float rainStrength;
uniform float frameTimeCounter;
uniform int isEyeInWater;

const float PI = 3.14159265359;
const float MAT_SKY = 6.0;

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

float interleavedGradientNoise(vec2 uv) {
    const vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv, magic.xy)));
}

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

        float rayLin = linZ(clipDepth * 0.5 + 0.5);
        float sampleLin = linZ(sampledDepth);

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

        float rayLin = linZ(clipDepth * 0.5 + 0.5);
        float sampleLin = linZ(sampledDepth);

        float depthDiff = rayLin - sampleLin;

        if (depthDiff > 0.0) {
            vec2 lowUv = prevUv;
            vec2 highUv = uv;
            float lowDepth = prevDepth;
            float highDepth = clipDepth;

            for (float j = 0.0; j < 6.0; j += 1.0) {
                vec2 midUv = (lowUv + highUv) * 0.5;
                float midDepth = (lowDepth + highDepth) * 0.5;

                float midLin = linZ(midDepth * 0.5 + 0.5);
                float samLin = linZ(texture2D(depthtex1, midUv).r);

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
            float finalLin = linZ(finalDepth);
            CURVE = 1.0;
            return vec3(finalUv, finalLin);
        }
    }

    CURVE = 0.0;
    return vec3(1.1, 1.1, 1.1);
}

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

vec3 getShadowPos(vec3 wpos) {
    vec4 sv = shadowModelView * vec4(wpos, 1.0);
    vec4 sc = shadowProjection * sv;
    vec3 sp = sc.xyz / sc.w;
    return sp * 0.5 + 0.5;
}

float sampleShadowPCSS(vec3 shadowPos) {
    if (shadowPos.x < 0.0 || shadowPos.x > 1.0 || shadowPos.y < 0.0 || shadowPos.y > 1.0 || shadowPos.z < 0.0 || shadowPos.z > 1.0) return 1.0;

    float bias = 0.002;
    vec2 texelSize = 1.0 / vec2(2048.0);

    float blockerSum = 0.0;
    float blockerCount = 0.0;

    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            vec2 off = vec2(float(x), float(y)) * texelSize * 2.0;
            float d = texture2D(shadowtex0, shadowPos.xy + off).r;
            if (d < shadowPos.z - bias) {
                blockerSum += d;
                blockerCount += 1.0;
            }
        }
    }

    if (blockerCount < 1.0) return 1.0;

    float avgBlocker = blockerSum / blockerCount;
    float penumbra = (shadowPos.z - avgBlocker) / avgBlocker;
    penumbra = clamp(penumbra * 32.0, 0.0, 1.0);

    float filterRadius = 1.0 + penumbra * 6.0;
    float vis = 0.0;
    float total = 0.0;

    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            vec2 off = vec2(float(x), float(y)) * texelSize * filterRadius / 2.0;
            float d = texture2D(shadowtex0, shadowPos.xy + off).r;
            vis += step(shadowPos.z - bias, d);
            total += 1.0;
        }
    }

    return vis / total;
}

float screenSpaceContactShadow(vec3 viewPos, vec3 viewLightDir, float dither) {
    float stepSize = 0.2;
    float maxDist = 3.0;
    float t = stepSize * 0.5 + dither * stepSize;

    for (float d = 0.0; d < maxDist; d += stepSize) {
        vec3 pos = viewPos + viewLightDir * t;
        vec3 clip = toClipSpace3(pos);
        vec2 uv = clip.xy * 0.5 + 0.5;

        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) break;

        float sampleLin = linZ(texture2D(depthtex1, uv).r);
        float rayLin = linZ(clip.z * 0.5 + 0.5);

        if (rayLin > sampleLin + 0.001) {
            return 1.0 - (1.0 - d / maxDist) * 0.6;
        }

        t += stepSize;
    }

    return 1.0;
}

vec3 getSkyColor(vec3 dir, float sunVisibility, vec3 sunVec) {
    float cosTheta = dot(dir, sunVec);
    float cosThetaSq = cosTheta * cosTheta;
    float height = max(dir.y, 0.001);

    float rayleigh = 0.75 * (1.0 + cosThetaSq);
    float g = 0.76;
    float mie = (1.0 - g * g) / (4.0 * PI * pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5));

    vec3 rayleighCol = vec3(0.65, 0.55, 0.45) * rayleigh * 0.8;
    vec3 mieCol = vec3(0.80, 0.68, 0.52) * mie * 3.0;

    float horizon = 1.0 - height;
    float horizonBright = 1.0 - horizon * horizon * 0.7;
    vec3 sky = (rayleighCol + mieCol) * horizonBright * sunVisibility;

    vec3 nightSky = mix(vec3(0.002, 0.003, 0.008), vec3(0.01, 0.015, 0.03), height);
    sky = mix(nightSky, sky, sunVisibility);

    float sunDisk = pow(max(cosTheta, 0.0), 80.0) * 40.0 * sunVisibility;
    sky += vec3(1.0, 0.6, 0.15) * sunDisk;

    float glow = exp(-3.0 * acos(max(cosTheta, 0.0))) * 0.5 * sunVisibility;
    sky += vec3(1.0, 0.5, 0.1) * glow;

    return sky;
}

vec3 getStars(vec3 dir, float sunVisibility) {
    if (sunVisibility > 0.3) return vec3(0.0);

    vec3 sd = dir * 500.0;
    vec3 p = floor(sd);
    vec3 f = fract(sd) - 0.5;

    float star = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            for (int z = -1; z <= 1; z++) {
                vec3 n = p + vec3(float(x), float(y), float(z));
                vec3 r = vec3(
                    fract(sin(dot(n, vec3(127.1, 311.7, 74.7))) * 43758.5453),
                    fract(sin(dot(n, vec3(269.5, 183.3, 346.6))) * 43758.5453),
                    fract(sin(dot(n, vec3(413.3, 231.9, 157.3))) * 43758.5453)
                );
                vec3 pos = n + r - 0.5;
                float d = length(pos - sd);
                float s = max(0.0, 1.0 - d * 50.0);
                s = s * s * s;
                s *= step(0.999, r.x + r.y * 0.01);
                star += s;
            }
        }
    }

    star = clamp(star * 0.5, 0.0, 1.0);
    float twinkle = 0.5 + 0.5 * sin(frameTimeCounter * 0.5 + dot(dir, vec3(12.3, 45.6, 78.9)));
    return vec3(star * twinkle * (1.0 - sunVisibility * 3.0));
}

vec3 volumetricFog(vec3 cameraDir, float viewDist, vec3 lightDir, vec3 lightCol, float sunVisibility, float dither) {
    vec3 fogColor = vec3(0.0);
    float transmittance = 1.0;
    float t = near + dither * 0.5;
    float stepSize = viewDist / 12.0;

    for (int i = 0; i < 12; i++) {
        if (t > viewDist) break;
        vec3 pos = cameraDir * t;
        float heightFog = exp(-pos.y * 0.04);
        float density = heightFog * 0.008 * (1.0 + rainStrength * 2.0);

        float phase = 0.75 * (1.0 + dot(cameraDir, lightDir) * dot(cameraDir, lightDir));
        vec3 inscatter = lightCol * phase * density * transmittance * stepSize * sunVisibility;

        vec3 ambientFog = vec3(0.02, 0.03, 0.05) * density * transmittance * stepSize;
        fogColor += inscatter + ambientFog;
        transmittance *= exp(-density * stepSize);

        t += stepSize;
    }

    return fogColor;
}

vec3 sampleEmissiveLight(vec2 uv, vec3 normal, vec2 texelSize) {
    vec3 lightAccum = vec3(0.0);
    float weightSum = 0.0;

    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            vec2 suv = uv + vec2(float(x), float(y)) * texelSize * 2.0;
            if (suv.x < 0.0 || suv.x > 1.0 || suv.y < 0.0 || suv.y > 1.0) continue;

            vec4 smat = texture2D(colortex2, suv);
            float em = smat.a;
            if (em < 0.01) continue;

            float dist = length(vec2(float(x), float(y)));
            float w = exp(-dist * 0.4) * em;

            vec3 salb = texture2D(colortex0, suv).rgb;
            lightAccum += salb * w * 2.0;
            weightSum += w;
        }
    }

    if (weightSum < 0.01) return vec3(0.0);
    return lightAccum / weightSum;
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

            if (hitMat >= MAT_SKY - 0.5) {
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

void main() {
    vec4 col0 = texture2D(colortex0, texcoord);
    float matFlag = col0.a;

    if (matFlag >= MAT_SKY - 0.5) {
        vec3 viewPos = getViewPos(texcoord, 1.0);
        vec3 viewDir = normalize(viewPos);
        vec3 dir = normalize((gbufferModelViewInverse * vec4(viewDir, 0.0)).xyz);
        vec3 sunVec = getSunVec();
        float sunVis = clamp((dot(sunVec, getUpVec()) + 0.05) * 10.0, 0.0, 1.0);
        vec3 skyCol = getSkyColor(dir, sunVis, sunVec) + getStars(dir, sunVis);
        gl_FragData[0] = vec4(skyCol, 1.0);
        gl_FragData[1] = vec4(0.0);
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
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);

    float depth = texture2D(depthtex0, texcoord).r;
    vec3 viewPos = getViewPos(texcoord, depth);
    vec3 viewDir = normalize(-viewPos);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz;

    vec3 sunVec = getSunVec();
    vec3 upVec = getUpVec();
    vec3 lightDir = sunVec;

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

    vec3 torchCol = mix(vec3(1.0, 0.45, 0.08), vec3(0.4, 0.6, 1.0), smoothstep(0.5, 1.0, lm.x)) * 4.0;

    float NdotL = max(dot(normal, lightDir), 0.0);

    vec3 shadowPos = getShadowPos(worldPos + cameraPosition);
    float shadow = 1.0;
    if (NdotL > 0.0) {
        shadow = sampleShadowPCSS(shadowPos);
    }

    float contactShadow = 1.0;
    if (NdotL > 0.0 && shadow > 0.5) {
        vec3 viewLightDir = normalize((gbufferModelView * vec4(lightDir, 0.0)).xyz);
        vec2 csNoiseUV = texcoord * vec2(viewWidth, viewHeight);
        float csDither = interleavedGradientNoise(csNoiseUV + fract(frameTimeCounter * 53.0));
        contactShadow = screenSpaceContactShadow(viewPos, viewLightDir, csDither);
    }
    shadow = min(shadow, contactShadow);

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

    vec3 giResult = vec3(0.0);

    vec3 prevWorldPos = worldPos + cameraPosition - previousCameraPosition;
    vec4 prevClip = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevWorldPos, 1.0);
    vec2 prevUv = prevClip.xy / prevClip.w * 0.5 + 0.5;

    vec3 prevGI = texture2D(colortex4, prevUv).rgb;
    float blend = 0.05;
    if (any(lessThan(prevUv, vec2(0.0))) || any(greaterThan(prevUv, vec2(1.0)))) blend = 1.0;

    vec2 noiseUV = texcoord * vec2(viewWidth, viewHeight) + fract(frameTimeCounter * 137.0);
    vec3 noise = vec3(
        interleavedGradientNoise(noiseUV),
        interleavedGradientNoise(noiseUV + vec2(1.0, 0.0)),
        interleavedGradientNoise(noiseUV + vec2(0.0, 1.0))
    );

    float ssrtgiRayCount = mix(2.0, 6.0, 1.0 - linZ(depth));
    ssrtgiRayCount = clamp(ssrtgiRayCount, 2.0, 6.0);

    vec3 rawGI = computeSSRTGI(viewPos, normal, noise, texcoord,
        sunVisibility, sunVec, ambientCol, lightCol,
        int(ssrtgiRayCount), 12.0);

    giResult = mix(prevGI, rawGI, blend);

    color += giResult * albedo * 0.3;

    vec3 camDir = normalize(viewPos);
    float viewDist = length(viewPos);
    vec3 fog = volumetricFog(camDir, viewDist, lightDir, lightCol, sunVisibility, noise.z);
    color = mix(color, fog, 0.3);

    if (emission < 0.01) {
        vec3 emissiveLight = sampleEmissiveLight(texcoord, normal, texelSize);
        color += emissiveLight * albedo * 0.15;
    }

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(giResult, 1.0);
}
