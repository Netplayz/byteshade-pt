#version 120

/* RENDERTARGETS: 0,1,2 */

varying vec2 texcoord;
varying vec4 glcolor;

uniform sampler2D texture;
uniform sampler2D specular;
uniform sampler2D normals;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.004) discard;
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    vec4 spec = texture2D(specular, texcoord);

    float roughness = 1.0 - spec.r;
    float metallic = spec.g;
    float emission = spec.b;
    float sss = spec.a;
    if (spec.r > 0.99 && spec.g > 0.99 && spec.b > 0.99 && spec.a > 0.99) {
        roughness = 0.9;
        metallic = 0.0;
        emission = 0.0;
        sss = 0.0;
    }

    gl_FragData[0] = vec4(albedo.rgb, 5.0);
    gl_FragData[1] = vec4(0.5, 0.5, 0.0, 1.0);
    gl_FragData[2] = vec4(roughness, metallic, sss, emission);
}
