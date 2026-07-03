#version 120

/* RENDERTARGETS: 0,1 */

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;
varying vec3 worldPos;
varying float vertexDistance;

uniform float timeAngle;
uniform float sunPathRotation;
uniform float rainStrength;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform mat4 gbufferModelView;

const float PI = 3.14159265359;

vec3 encodeNormal(vec3 n) {
    n.xy = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * (sign(n.xy) * -2.0 + 1.0);
    return n * 0.5 + 0.5;
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.004) discard;
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    vec2 lm = clamp(lmcoord, vec2(0.0), vec2(1.0));

    vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329252), -sin(sunPathRotation * 0.01745329252));
    float ang = fract(timeAngle - 0.25);
    ang = (ang + (cos(ang * 3.14159265359) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530718;
    vec3 sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
    vec3 upVec = normalize(gbufferModelView[1].xyz);

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

    vec3 sceneLighting = mix(ambientCol * lm.y, lightCol, lm.y * 0.7);
    sceneLighting *= lm.y * lm.y;

    float newLightmap = pow(lm.x, 10.0) * 1.6 + lm.x * 0.6;
    vec3 blockLighting = torchCol * newLightmap * newLightmap;

    vec3 color = albedo.rgb * (sceneLighting + blockLighting);
    color = max(color, vec3(0.0));

    vec3 norm = normalize(normal);
    vec3 enc = encodeNormal(norm);

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(enc, 0.0);
}
