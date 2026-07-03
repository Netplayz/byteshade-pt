#ifndef SKY_GLSL
#define SKY_GLSL

vec3 calcSunSky(vec3 viewDir, vec3 sunDir, out vec3 sunColor) {
    float cosTheta = dot(viewDir, sunDir);
    float cosThetaSun = max(cosTheta, 0.0);

    float sunAngle = max(dot(sunDir, vec3(0.0, 1.0, 0.0)), 0.0);
    float dayFactor = smoothstep(0.0, 0.3, sunAngle);

    vec3 rayleighCoeff = vec3(5.8, 13.5, 33.1);
    vec3 mieCoeff = vec3(3.0, 3.0, 3.0);

    float zenith = max(viewDir.y, 0.001);
    float opticalDepth = exp(-(1.0 - zenith) * 0.5) / zenith;

    vec3 rayleigh = exp(-rayleighCoeff * opticalDepth);
    vec3 mie = exp(-mieCoeff * opticalDepth * 0.1);

    float phaseRayleigh = 0.75 * (1.0 + cosTheta * cosTheta);
    float g = 0.76;
    float phaseMie = (1.0 - g * g) / (4.0 * PI * pow(1.0 + g * g - 2.0 * g * cosTheta, 1.5));

    vec3 skyDay = vec3(0.4, 0.6, 1.0) * 0.3;
    vec3 skySunset = vec3(1.0, 0.4, 0.1) * 0.25;
    vec3 skyNight = vec3(0.01, 0.005, 0.02) * 0.1;

    vec3 skyColor = mix(skyNight, skyDay, dayFactor);
    skyColor = mix(skyColor, skySunset, (1.0 - dayFactor) * smoothstep(-0.1, 0.3, sunAngle));

    vec3 scatteredLight = rayleigh * phaseRayleigh * 0.8 + mie * phaseMie * 0.2;
    skyColor += scatteredLight * dayFactor * 0.3;

    sunColor = vec3(1.0, 0.9, 0.7) * dayFactor;
    sunColor = mix(sunColor, vec3(1.0, 0.3, 0.05), (1.0 - dayFactor) * 0.7);

    float sunDisk = smoothstep(0.999, 0.9998, cosTheta);
    sunColor = max(sunColor, vec3(0.0)) * sunDisk * 50.0;

    return max(skyColor, 0.0);
}

vec3 getStarColor(vec3 viewDir) {
    vec3 p = viewDir * 1000.0;
    vec3 i = floor(p);
    vec3 f = fract(p);
    float star = 0.0;
    vec3 starPos = i + hash3(i);
    vec3 dir = normalize(starPos - p);
    float brightness = smoothstep(0.9995, 0.9999, dot(viewDir, normalize(starPos)));
    float twinkle = sin(hash1(i) * 1000.0 + 0.5) * 0.5 + 0.5;
    star = brightness * twinkle * 0.8;

    float starCol = hash1(i + 1.0);
    vec3 color = mix(vec3(1.0, 0.95, 0.8), vec3(0.7, 0.8, 1.0), starCol);
    return color * star;
}

float getCloudDensity(vec3 pos, float time) {
    vec3 p = pos * 0.002;
    float cloudNoise = fbm(p + vec3(time * 0.001, 0.0, time * 0.0008));
    float cloudNoise2 = fbm(p * 2.0 + vec3(time * 0.002, 0.0, time * 0.001));
    float density = cloudNoise * 0.7 + cloudNoise2 * 0.3;
    return smoothstep(0.45, 0.75, density);
}

vec3 renderClouds(vec3 viewDir, vec3 sunDir, float time) {
    float height = 120.0;
    float t = height / max(viewDir.y, 0.001);
    vec3 cloudPos = viewDir * t;

    float density = getCloudDensity(cloudPos, time);
    if (density < 0.01) return vec3(0.0);

    float sunDot = max(dot(normalize(viewDir), normalize(sunDir)), 0.0);
    float sunLight = pow(sunDot, 4.0) * 2.0 + 0.3;

    vec3 cloudColor = vec3(0.95) * density * sunLight;
    cloudColor += vec3(0.1, 0.12, 0.15) * density * 0.3;

    return cloudColor * 0.6;
}

vec3 getAurora(vec3 viewDir, float time) {
    float lat = abs(viewDir.y);
    if (lat < 0.1) return vec3(0.0);

    vec3 p = viewDir * 0.5;
    float auroraNoise = noise(p * 2.0 + vec3(time * 0.005, 0.0, time * 0.003));
    float auroraMask = smoothstep(0.35, 0.6, auroraNoise);

    float heightFade = smoothstep(0.1, 0.4, lat) * (1.0 - smoothstep(0.5, 0.9, lat));
    auroraMask *= heightFade;

    vec3 color1 = vec3(0.0, 0.8, 0.2);
    vec3 color2 = vec3(0.0, 0.3, 0.9);
    vec3 color3 = vec3(0.6, 0.0, 0.8);
    float mixVal = fbm(p * 3.0 + vec3(time * 0.01, 0.0, 0.0));
    vec3 auroraColor = mix(mix(color1, color2, mixVal), color3, mixVal * 0.5);

    return auroraColor * auroraMask * 0.15;
}

#endif
