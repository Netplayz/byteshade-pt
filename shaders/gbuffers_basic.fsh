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

float linearizeDepth(float depth, float n, float f) {
    return (2.0 * n) / (f + n - depth * (f - n));
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

    gl_FragData[0] = vec4(albedo.rgb, 0.8);
    gl_FragData[1] = vec4(enc, 0.0);
    gl_FragData[2] = vec4(0.0, 0.1, 0.0, 0.0);
    gl_FragData[3] = vec4(linDepth, lmcoord.x, lmcoord.y, 1.0);
    gl_FragData[4] = vec4(0.0);
}
