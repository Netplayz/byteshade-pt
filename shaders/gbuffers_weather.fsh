#version 120

/* RENDERTARGETS: 0,1,2 */

varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D texture;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.004) discard;
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    gl_FragData[0] = vec4(albedo.rgb, 5.0);
    gl_FragData[1] = vec4(0.5, 0.5, 0.0, 1.0);
    gl_FragData[2] = vec4(0.9, 0.0, 0.0, 0.0);
}
