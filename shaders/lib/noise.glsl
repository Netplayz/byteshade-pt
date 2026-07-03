#ifndef NOISE_GLSL
#define NOISE_GLSL

float hash1(float n) {
    return fract(sin(n) * 43758.5453123);
}

float hash1(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float hash1(vec3 p) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453123);
}

vec2 hash2(vec2 p) {
    return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453123);
}

vec3 hash3(vec3 p) {
    return fract(sin(vec3(dot(p, vec3(127.1, 311.7, 74.7)),
                          dot(p, vec3(269.5, 183.3, 246.1)),
                          dot(p, vec3(113.5, 271.9, 124.6)))) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1(i);
    float b = hash1(i + vec2(1.0, 0.0));
    float c = hash1(i + vec2(0.0, 1.0));
    float d = hash1(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash1(i);
    float b = hash1(i + vec3(1.0, 0.0, 0.0));
    float c = hash1(i + vec3(0.0, 1.0, 0.0));
    float d = hash1(i + vec3(1.0, 1.0, 0.0));
    float e = hash1(i + vec3(0.0, 0.0, 1.0));
    float f_ = hash1(i + vec3(1.0, 0.0, 1.0));
    float g = hash1(i + vec3(0.0, 1.0, 1.0));
    float h = hash1(i + vec3(1.0, 1.0, 1.0));
    float xy1 = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
    float xy2 = mix(mix(e, f_, f.x), mix(g, h, f.x), f.y);
    return mix(xy1, xy2, f.z);
}

float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

float fbm(vec3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = 1.0;
    for (int i = 0; i < 5; i++) {
        value += amplitude * noise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

uint wang_hash(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16u);
    seed *= 9u;
    seed = seed ^ (seed >> 4u);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15u);
    return seed;
}

float rand(inout uint seed) {
    seed = wang_hash(seed);
    return float(seed) / 4294967296.0;
}

vec3 randomDir(inout uint seed) {
    float theta = TAU * rand(seed);
    float phi = acos(2.0 * rand(seed) - 1.0);
    return vec3(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi));
}

vec2 r2_samples(uint frame) {
    const float alpha = 0.7548776662466927;
    float x = fract(0.5 + alpha * float(frame));
    float y = fract(0.5 + alpha * alpha * float(frame));
    return vec2(x, y);
}

float blueNoise(vec2 uv, float frame) {
    vec3 magic = vec3(0.06711056, 0.00583715, 52.9829189);
    return fract(magic.z * fract(dot(uv + frame * 0.001, magic.xy)));
}

#endif
