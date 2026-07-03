#version 120

/* RENDERTARGETS: 0,1,2,3,4 */

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;
varying vec3 worldPos;
varying float vertexDistance;

uniform vec3 cameraPosition;
uniform float near;
uniform float far;
uniform sampler2D texture;
uniform sampler2D lightmap;

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

vec3 encodeNormal(vec3 n) {
    n.xy = n.z >= 0.0 ? n.xy : (1.0 - abs(n.yx)) * (sign(n.xy) * -2.0 + 1.0);
    return n * 0.5 + 0.5;
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.004) discard;

    vec3 norm = normalize(normal);
    vec3 enc = encodeNormal(norm);

    float roughness = 0.8;
    float metallic = 0.0;
    float specular = 0.1;
    float emission = 0.0;

    float depth = gl_FragCoord.z;
    float linDepth = linearizeDepth(depth, near, far);

    vec2 lm = texture2D(lightmap, lmcoord).rg;
    vec3 torchColor = vec3(1.0, 0.5, 0.08) * lm.r;
    vec3 skyColor = vec3(1.0, 0.9, 0.85) * lm.g;
    vec3 lightColor = torchColor + skyColor;

    gl_FragData[0] = vec4(albedo.rgb, roughness);
    gl_FragData[1] = vec4(enc, metallic);
    gl_FragData[2] = vec4(emission, specular, 0.0, 1.0);
    gl_FragData[3] = vec4(linDepth, lm.g, lightColor.rg);
    gl_FragData[4] = vec4(0.0);
}
