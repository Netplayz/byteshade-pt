#version 120

/* RENDERTARGETS: 0,1,2,3,4 */

varying vec2 texcoord;
varying vec4 glcolor;
varying float vertexDistance;

uniform float near;
uniform float far;
uniform sampler2D texture;

float linearizeDepth(float d, float n, float f) {
    return (2.0 * n) / (f + n - d * (f - n));
}

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.004) discard;

    float linDepth = linearizeDepth(gl_FragCoord.z, near, far);

    gl_FragData[0] = vec4(albedo.rgb, 1.0);
    gl_FragData[1] = vec4(0.5, 0.5, 1.0, 0.0);
    gl_FragData[2] = vec4(0.0, 0.0, 0.0, 0.0);
    gl_FragData[3] = vec4(linDepth, 1.0, 0.0, 1.0);
    gl_FragData[4] = vec4(0.0);
}
