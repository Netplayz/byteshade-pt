#version 120

/* RENDERTARGETS: 3,5 */

varying vec2 texcoord;

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;
uniform sampler2D colortex1;

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

vec3 getViewPos(vec2 uv, float depth) {
    vec4 clip = vec4(uv * 2.0 - 1.0, depth * 2.0 - 1.0, 1.0);
    vec4 view = gbufferProjectionInverse * clip;
    return view.xyz / view.w;
}

void main() {
    vec2 uv = texcoord;
    float depth = texture2D(depthtex0, uv).r;

    vec3 currentColor = texture2D(colortex3, uv).rgb;

    vec3 viewPos = getViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
    vec3 prevWorldPos = worldPos - cameraPosition + previousCameraPosition;
    vec4 prevClip = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevWorldPos, 1.0);
    vec2 prevUv = prevClip.xy / prevClip.w * 0.5 + 0.5;

    if (prevUv.x < 0.0 || prevUv.x > 1.0 || prevUv.y < 0.0 || prevUv.y > 1.0) {
        gl_FragData[0] = vec4(currentColor, 1.0);
        gl_FragData[1] = vec4(currentColor, 1.0);
        return;
    }

    float prevDepth = texture2D(depthtex0, prevUv).r;
    float depthDiff = abs(linearizeDepth(prevDepth, near, far) - linearizeDepth(depth, near, far));
    if (depthDiff > 0.1) {
        gl_FragData[0] = vec4(currentColor, 1.0);
        gl_FragData[1] = vec4(currentColor, 1.0);
        return;
    }

    vec3 historyColor = texture2D(colortex5, prevUv).rgb;

    vec3 minColor = currentColor;
    vec3 maxColor = currentColor;
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 sampleUv = uv + vec2(float(x), float(y)) * texelSize;
            vec3 sampleColor = texture2D(colortex3, sampleUv).rgb;
            minColor = min(minColor, sampleColor);
            maxColor = max(maxColor, sampleColor);
        }
    }

    historyColor = clamp(historyColor, minColor, maxColor);

    vec2 velocity = uv - prevUv;
    float blend = 0.08;
    if (length(velocity) > 0.01) blend = 0.04;
    if (depthDiff > 0.02) blend = 0.5;

    vec3 result = mix(historyColor, currentColor, blend);

    gl_FragData[0] = vec4(result, 1.0);
    gl_FragData[1] = vec4(result, 1.0);
}
