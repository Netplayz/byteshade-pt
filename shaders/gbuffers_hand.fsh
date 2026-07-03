#version 330 compatibility

/* RENDERTARGETS: 0,1,2,3,4 */

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 worldPos;
in float vertexDistance;

uniform float near;
uniform float far;
uniform int heldBlockLightValue;
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
    float linDepth = linearizeDepth(gl_FragCoord.z, near, far);
    float flags = 4.0;

    float blockLight = float(heldBlockLightValue) / 15.0;

    gl_FragData[0] = vec4(albedo.rgb, 0.5);
    gl_FragData[1] = vec4(enc, 0.0);
    gl_FragData[2] = vec4(0.0, 0.3, flags, 0.0);
        vec2 lightUV = vec2(lmcoord.x, max(lmcoord.y, blockLight));
    vec3 lightColor = texture2D(lightmap, lightUV).rgb;
    gl_FragData[3] = vec4(linDepth, lightColor);
    gl_FragData[4] = vec4(0.0);
}
