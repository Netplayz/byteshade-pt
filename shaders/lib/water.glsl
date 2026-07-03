#ifndef WATER_GLSL
#define WATER_GLSL

float gerstnerWave(vec2 pos, vec2 direction, float steepness, float wavelength, float time) {
    float k = TAU / wavelength;
    float c = sqrt(9.81 / k);
    float phase = k * dot(direction, pos) + time * c;
    float height = steepness * sin(phase) / k;
    return height;
}

float getWaveHeight(vec2 pos, float time) {
    vec2 windDir = normalize(vec2(1.0, 0.5));
    float h = 0.0;
    h += gerstnerWave(pos, windDir, 0.3, 20.0, time);
    h += gerstnerWave(pos, windDir * vec2(0.7, 1.0), 0.2, 12.0, time * 1.2);
    h += gerstnerWave(pos, vec2(-0.3, 0.8), 0.15, 8.0, time * 1.5);
    h += gerstnerWave(pos, normalize(vec2(0.5, -0.3)), 0.1, 5.0, time * 1.8);
    return h;
}

vec3 getWaterNormal(vec2 pos, float time) {
    float eps = 0.01;
    vec2 windDir = normalize(vec2(1.0, 0.5));

    float h0 = getWaveHeight(pos, time);
    float hx = getWaveHeight(pos + vec2(eps, 0.0), time);
    float hz = getWaveHeight(pos + vec2(0.0, eps), time);

    vec3 tangent = normalize(vec3(eps, 0.0, hx - h0));
    vec3 bitangent = normalize(vec3(0.0, eps, hz - h0));
    return normalize(cross(bitangent, tangent));
}

vec2 waterRefractionOffset(vec3 viewDir, vec3 normal, float depth) {
    float eta = 1.0 / 1.333;
    vec3 refracted = refract(viewDir, normal, eta);
    if (length(refracted) < 0.001) {
        refracted = reflect(viewDir, normal);
    }
    vec2 offset = refracted.xy * depth * 0.05;
    return offset;
}

float getCaustics(vec3 pos, float time) {
    vec3 p = pos * 0.3 + vec3(time * 0.5, time * 0.3, 0.0);
    float c = 0.0;
    for (int i = 0; i < 4; i++) {
        float scale = float(i + 1) * 1.5;
        vec3 p2 = p * scale;
        float n = noise(vec2(p2.x + p2.z, p2.y));
        c += abs(n - 0.5) * 2.0 / float(i + 1);
    }
    return clamp(c * 0.5, 0.0, 1.0);
}

#endif
