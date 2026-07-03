#version 120

/* RENDERTARGETS: 0,5 */

varying vec2 texcoord;

uniform sampler2D colortex0;
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

void main() {
    vec2 uv = texcoord;
    float depth = texture2D(depthtex0, uv).r;
    float linDepth = linearizeDepth(depth, near, far);
    float farLin = linearizeDepth(1.0, near, far);
    if (linDepth > farLin * 0.98) {
        vec3 skyColor = texture2D(colortex0, uv).rgb;
        gl_FragData[0] = vec4(skyColor, 1.0);
        gl_FragData[1] = vec4(skyColor, 1.0);
        return;
    }

    vec3 currentColor = texture2D(colortex0, uv).rgb;
    vec3 normalEnc = texture2D(colortex1, uv).rgb;
    vec3 normal = decodeNormal(normalEnc.rg);

    // Compute motion vector
    vec3 viewPos = getViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
    vec3 prevWorldPos = worldPos - cameraPosition + previousCameraPosition;
    vec4 prevClip = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevWorldPos, 1.0);
    vec2 prevUv = prevClip.xy / prevClip.w * 0.5 + 0.5;
    vec2 velocity = uv - prevUv;

    // Neighborhood clamping
    vec3 historyColor = texture2D(colortex5, prevUv).rgb;

    if (prevUv.x < 0.0 || prevUv.x > 1.0 || prevUv.y < 0.0 || prevUv.y > 1.0) {
        gl_FragData[0] = vec4(currentColor, 1.0);
        gl_FragData[1] = vec4(currentColor, 1.0);
        return;
    }

    float depthDiff = abs(linearizeDepth(texture2D(depthtex0, prevUv).r, near, far) - linDepth);
    if (depthDiff > 0.1) {
        gl_FragData[0] = vec4(currentColor, 1.0);
        gl_FragData[1] = vec4(currentColor, 1.0);
        return;
    }

    vec3 minColor = currentColor;
    vec3 maxColor = currentColor;
    vec2 texelSize = 1.0 / vec2(viewWidth, viewHeight);

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 sampleUv = uv + vec2(float(x), float(y)) * texelSize;
            vec3 sampleColor = texture2D(colortex0, sampleUv).rgb;
            minColor = min(minColor, sampleColor);
            maxColor = max(maxColor, sampleColor);
        }
    }

    historyColor = clamp(historyColor, minColor, maxColor);

    float blend = 0.08;
    if (length(velocity) > 0.01) blend = 0.04;
    if (depthDiff > 0.02) blend = 0.5;

    vec3 result = mix(historyColor, currentColor, blend);

    gl_FragData[0] = vec4(result, 1.0);
    gl_FragData[1] = vec4(result, 1.0);
}
