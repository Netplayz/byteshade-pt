#version 120

/* RENDERTARGETS: 3,5 */

varying vec2 texcoord;

uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D depthtex0;

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

vec2 getPrevUv(vec2 uv, float depth) {
    vec3 viewPos = getViewPos(uv, depth);
    vec3 worldPos = (gbufferModelViewInverse * vec4(viewPos, 1.0)).xyz + cameraPosition;
    vec3 prevWorldPos = worldPos - cameraPosition + previousCameraPosition;
    vec4 prevClip = gbufferPreviousProjection * gbufferPreviousModelView * vec4(prevWorldPos, 1.0);
    return prevClip.xy / prevClip.w * 0.5 + 0.5;
}

vec3 catmullRomSample(sampler2D tex, vec2 uv, vec2 texSize) {
    vec2 pix = uv * texSize;
    vec2 f = fract(pix);
    vec2 center = floor(pix);

    vec4 wy;
    float fy = f.y;
    wy.x = 0.5 * (-fy*fy*fy + 2.0*fy*fy - fy);
    wy.y = 0.5 * (3.0*fy*fy*fy - 5.0*fy*fy + 2.0);
    wy.z = 0.5 * (-3.0*fy*fy*fy + 4.0*fy*fy + fy);
    wy.w = 0.5 * (fy*fy*fy - fy*fy);

    vec4 wx;
    float fx = f.x;
    wx.x = 0.5 * (-fx*fx*fx + 2.0*fx*fx - fx);
    wx.y = 0.5 * (3.0*fx*fx*fx - 5.0*fx*fx + 2.0);
    wx.z = 0.5 * (-3.0*fx*fx*fx + 4.0*fx*fx + fx);
    wx.w = 0.5 * (fx*fx*fx - fx*fx);

    vec3 result = vec3(0.0);

    float py0 = (center.y - 0.5) / texSize.y;
    float py1 = (center.y + 0.5) / texSize.y;
    float py2 = (center.y + 1.5) / texSize.y;
    float py3 = (center.y + 2.5) / texSize.y;

    float px0 = (center.x - 0.5) / texSize.x;
    float px1 = (center.x + 0.5) / texSize.x;
    float px2 = (center.x + 1.5) / texSize.x;
    float px3 = (center.x + 2.5) / texSize.x;

    result += texture2D(tex, vec2(px0, py0)).rgb * wx.x * wy.x;
    result += texture2D(tex, vec2(px1, py0)).rgb * wx.y * wy.x;
    result += texture2D(tex, vec2(px2, py0)).rgb * wx.z * wy.x;
    result += texture2D(tex, vec2(px3, py0)).rgb * wx.w * wy.x;

    result += texture2D(tex, vec2(px0, py1)).rgb * wx.x * wy.y;
    result += texture2D(tex, vec2(px1, py1)).rgb * wx.y * wy.y;
    result += texture2D(tex, vec2(px2, py1)).rgb * wx.z * wy.y;
    result += texture2D(tex, vec2(px3, py1)).rgb * wx.w * wy.y;

    result += texture2D(tex, vec2(px0, py2)).rgb * wx.x * wy.z;
    result += texture2D(tex, vec2(px1, py2)).rgb * wx.y * wy.z;
    result += texture2D(tex, vec2(px2, py2)).rgb * wx.z * wy.z;
    result += texture2D(tex, vec2(px3, py2)).rgb * wx.w * wy.z;

    result += texture2D(tex, vec2(px0, py3)).rgb * wx.x * wy.w;
    result += texture2D(tex, vec2(px1, py3)).rgb * wx.y * wy.w;
    result += texture2D(tex, vec2(px2, py3)).rgb * wx.z * wy.w;
    result += texture2D(tex, vec2(px3, py3)).rgb * wx.w * wy.w;

    return result;
}

bool inBounds(vec2 uv) {
    return uv.x >= 0.0 && uv.x <= 1.0 && uv.y >= 0.0 && uv.y <= 1.0;
}

bool depthConsistent(vec2 uv1, vec2 uv2, float threshold) {
    float d1 = texture2D(depthtex0, uv1).r;
    float d2 = texture2D(depthtex0, uv2).r;
    return abs(linearizeDepth(d1, near, far) - linearizeDepth(d2, near, far)) < threshold;
}

void main() {
    vec2 uv = texcoord;
    float depth = texture2D(depthtex0, uv).r;
    vec3 currentColor = texture2D(colortex3, uv).rgb;

    vec2 texSize = vec2(viewWidth, viewHeight);
    vec2 texelSize = 1.0 / texSize;

    vec2 prevUv = getPrevUv(uv, depth);
    bool ownValid = inBounds(prevUv) && depthConsistent(uv, prevUv, 0.1);

    vec2 bestVel = ownValid ? uv - prevUv : vec2(0.0);
    float bestVelLen = ownValid ? length(bestVel) : -1.0;
    vec2 bestPrevUv = ownValid ? prevUv : uv;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 nuv = uv + vec2(float(x), float(y)) * texelSize;
            if (!inBounds(nuv)) continue;
            float nd = texture2D(depthtex0, nuv).r;
            vec2 nprev = getPrevUv(nuv, nd);
            if (!inBounds(nprev)) continue;
            if (!depthConsistent(nuv, nprev, 0.1)) continue;
            vec2 nvel = nuv - nprev;
            float nlen = length(nvel);
            if (nlen > bestVelLen) {
                bestVelLen = nlen;
                bestVel = nvel;
                bestPrevUv = nprev;
            }
        }
    }

    vec2 histUv = uv - bestVel;
    bool histValid = inBounds(histUv);

    if (!histValid) {
        gl_FragData[0] = vec4(currentColor, 1.0);
        gl_FragData[1] = vec4(currentColor, 1.0);
        return;
    }

    vec3 historyColor = catmullRomSample(colortex5, histUv, texSize);

    vec3 minColor = currentColor;
    vec3 maxColor = currentColor;

    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 sampleUv = uv + vec2(float(x), float(y)) * texelSize;
            vec3 sampleColor = texture2D(colortex3, sampleUv).rgb;
            minColor = min(minColor, sampleColor);
            maxColor = max(maxColor, sampleColor);
        }
    }

    historyColor = clamp(historyColor, minColor, maxColor);

    float lumSum = 0.0;
    float lumSum2 = 0.0;
    for (int x = -1; x <= 1; x++) {
        for (int y = -1; y <= 1; y++) {
            vec2 sampleUv = uv + vec2(float(x), float(y)) * texelSize;
            vec3 c = texture2D(colortex3, sampleUv).rgb;
            float l = dot(c, vec3(0.2126, 0.7152, 0.0722));
            lumSum += l;
            lumSum2 += l * l;
        }
    }
    float lumMean = lumSum / 9.0;
    float lumVar = max(lumSum2 / 9.0 - lumMean * lumMean, 0.0001);
    float lumStd = sqrt(lumVar);

    float histoLum = dot(historyColor, vec3(0.2126, 0.7152, 0.0722));
    float currLum = dot(currentColor, vec3(0.2126, 0.7152, 0.0722));

    float varMinLum = max(lumMean - 2.0 * lumStd, 0.0);
    float varMaxLum = min(lumMean + 2.0 * lumStd, 1.0);
    float scale = (histoLum - varMinLum) / max(varMaxLum - varMinLum, 0.001);
    scale = clamp(scale, 0.0, 1.0);
    historyColor *= scale;

    float blend = 0.08;
    if (bestVelLen > 0.01) blend = 0.04;
    if (ownValid && !depthConsistent(uv, histUv, 0.02)) blend = 0.5;

    float ghostDiff = abs(histoLum - currLum) / max(currLum, 0.01);
    float ghostFactor = clamp(ghostDiff * 2.0, 0.0, 1.0);
    blend = max(blend, ghostFactor * 0.3);

    vec3 result = mix(historyColor, currentColor, blend);

    gl_FragData[0] = vec4(result, 1.0);
    gl_FragData[1] = vec4(result, 1.0);
}
