#version 120

/* RENDERTARGETS: 0,5 */

varying vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

uniform vec3 sunPosition;

uniform float near;
uniform float far;

const float PI = 3.14159265359;

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
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

    vec3 color = texture2D(colortex0, uv).rgb;
    color = max(color, vec3(0.0));

    gl_FragData[0] = vec4(color, 1.0);
    gl_FragData[1] = vec4(color, 1.0);
}
