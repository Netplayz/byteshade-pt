#ifndef GBUFFER_GLSL
#define GBUFFER_GLSL

// Material flags for colortex0.a
#define MAT_TERRAIN    0.0
#define MAT_ENTITY     1.0
#define MAT_WATER      2.0
#define MAT_TRANSLUCENT 3.0
#define MAT_HAND       4.0
#define MAT_WEATHER    5.0
#define MAT_SKY        6.0
#define MAT_EMISSIVE   7.0

// Encode octahedral normal to vec2 in [0,1] range
vec2 encodeNormalForStorage(vec3 n) {
    n /= abs(n.x) + abs(n.y) + abs(n.z);
    vec2 enc = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * (sign(n.xy) * -2.0 + 1.0);
    return enc * 0.5 + 0.5;
}

// Decode octahedral normal from vec2 in [0,1] range
vec3 decodeNormalFromStorage(vec2 enc) {
    vec2 fenc = enc * 2.0 - 1.0;
    vec3 n;
    n.xy = fenc;
    n.z = 1.0 - abs(n.x) - abs(n.y);
    float t = max(-n.z, 0.0);
    n.x += n.x >= 0.0 ? -t : t;
    n.y += n.y >= 0.0 ? -t : t;
    return normalize(n);
}

// Pack albedo and material flag into colortex0
vec4 packAlbedo(vec3 albedo, float matFlag) {
    return vec4(albedo, matFlag);
}

// Pack normal, block lightmap, and sky lightmap into colortex1
vec4 packNormalLightmap(vec3 normal, float blockLM, float skyLM) {
    vec2 enc = encodeNormalForStorage(normal);
    return vec4(enc, blockLM, skyLM);
}

// Pack material properties into colortex2
vec4 packMaterial(float roughness, float metallic, float sss, float emission) {
    return vec4(roughness, metallic, sss, emission);
}

// Unpack albedo from colortex0
vec3 unpackAlbedo(vec4 col0) {
    return col0.rgb;
}

// Unpack material flag from colortex0
float unpackMatFlag(vec4 col0) {
    return col0.a;
}

// Unpack normal from colortex1
vec3 unpackNormal(vec4 col1) {
    return decodeNormalFromStorage(col1.rg);
}

// Unpack block lightmap from colortex1
float unpackBlockLM(vec4 col1) {
    return col1.b;
}

// Unpack sky lightmap from colortex1
float unpackSkyLM(vec4 col1) {
    return col1.a;
}

// Unpack roughness from colortex2
float unpackRoughness(vec4 col2) {
    return col2.r;
}

// Unpack metallic from colortex2
float unpackMetallic(vec4 col2) {
    return col2.g;
}

// Unpack SSS from colortex2
float unpackSSS(vec4 col2) {
    return col2.b;
}

// Unpack emission from colortex2
float unpackEmission(vec4 col2) {
    return col2.a;
}

#endif
