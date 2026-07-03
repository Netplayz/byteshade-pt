#version 150 compatibility

/* RENDERTARGETS: 0 */

in vec2 texcoord;

uniform sampler2D colortex0;
uniform sampler2D depthtex0;

uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform float frameTimeCounter;
uniform float nightVision;

vec3 acesFilm(vec3 x) {
    float a = 2.51;
    float b = 0.03;
    float c = 2.43;
    float d = 0.59;
    float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

vec3 bloomPass(sampler2D tex, vec2 uv, vec2 ps) {
    vec3 col = vec3(0.0);
    float total = 0.0;
    for (int x = -4; x <= 4; x++) {
        for (int y = -4; y <= 4; y++) {
            vec2 off = vec2(float(x), float(y)) * ps * 2.0;
            float w = exp(-float(x * x + y * y) / 8.0);
            col += texture2D(tex, uv + off).rgb * w;
            total += w;
        }
    }
    col /= total;
    return max(col - 0.3, 0.0) * 0.5;
}

void main() {
    vec2 uv = texcoord;
    vec2 ps = 1.0 / vec2(viewWidth, viewHeight);

    // DEBUG OVERLAY: red checkers = shader is running
    vec2 c = floor(uv * 32.0);
    float p = mod(c.x + c.y, 2.0);
    if (p > 0.5) {
        gl_FragData[0] = vec4(1.0, 0.0, 0.0, 1.0);
        return;
    }

    vec3 hdr = texture2D(colortex0, uv).rgb;

    // Auto exposure
    float avgLum = 0.0;
    for (int x = 0; x < 8; x++) {
        for (int y = 0; y < 8; y++) {
            vec3 s = texture2D(colortex0, vec2(float(x), float(y)) / 8.0).rgb;
            avgLum += dot(s, vec3(0.2126, 0.7152, 0.0722));
        }
    }
    avgLum /= 64.0;
    float exposure = clamp(1.0 / (avgLum + 0.05), 0.3, 4.0);
    hdr *= exposure;

    // Bloom on HDR before tonemapping
    vec3 bloom = bloomPass(colortex0, uv, ps);
    hdr += bloom;

    // ACES filmic tonemapping
    vec3 color = acesFilm(hdr);

    // Night vision
    color *= 1.0 + nightVision * 0.6;

    // Chromatic aberration on tonemapped
    vec2 center = uv - 0.5;
    float r = texture2D(colortex0, uv + center * 0.002).r * exposure;
    float b = texture2D(colortex0, uv - center * 0.002).b * exposure;
    vec3 ca = vec3(acesFilm(vec3(r, 0.0, 0.0)).r, color.g, acesFilm(vec3(0.0, 0.0, b)).b);

    // Depth of field
    float depth = linearizeDepth(texture2D(depthtex0, uv).r, near, far);
    float coc = abs(depth - 0.4) * 0.4;
    if (coc > 0.002) {
        vec3 blur = vec3(0.0);
        float tw = 0.0;
        for (int x = -5; x <= 5; x++) {
            for (int y = -5; y <= 5; y++) {
                vec2 off = vec2(float(x), float(y)) * ps * coc * 40.0;
                float w = exp(-float(x * x + y * y) / (2.0 + coc * 30.0));
                vec3 s = texture2D(colortex0, uv + off).rgb * exposure;
                blur += acesFilm(s) * w;
                tw += w;
            }
        }
        color = mix(color, blur / tw, smoothstep(0.002, 0.04, coc));
    }

    // Vignette
    float vignette = 1.0 - dot(uv - 0.5, uv - 0.5) * 1.2;
    color *= vignette;

    // Film grain
    float grain = fract(sin(dot(uv + frameTimeCounter * 0.001, vec2(12.9898, 78.233))) * 43758.5453);
    color += (grain - 0.5) * 0.015;

    // Gamma correction (sRGB encode)
    color = pow(color, vec3(1.0 / 2.2));

    gl_FragData[0] = vec4(color, 1.0);
}
