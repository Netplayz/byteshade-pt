#version 120

/* RENDERTARGETS: 0,1,2 */

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;
varying vec3 worldPos;
varying float vertexDistance;

uniform int isEyeInWater;
uniform sampler2D texture;
uniform sampler2D lightmap;
uniform sampler2D specular;
uniform sampler2D normals;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    float alpha = isEyeInWater == 1 ? 0.3 : 0.6;

    vec2 lm = clamp(lmcoord, vec2(0.0), vec2(1.0));
    vec3 norm = normalize(normal);

    vec4 spec = texture2D(specular, texcoord);
    vec4 nm = texture2D(normals, texcoord);

    vec3 normalMap = nm.xyz * 2.0 - 1.0;
    if (length(normalMap) > 0.01) {
        mat3 tbn = cotangentFrame(norm, worldPos, texcoord);
        norm = normalize(tbn * normalMap);
    }

    float roughness = 1.0 - spec.r;
    float metallic = spec.g;
    float emission = spec.b;
    float sss = spec.a;
    if (spec.r > 0.99 && spec.g > 0.99 && spec.b > 0.99 && spec.a > 0.99) {
        roughness = 0.0;
        metallic = 0.0;
        emission = 0.0;
        sss = 0.0;
    }

    gl_FragData[0] = vec4(albedo.rgb, 2.0);
    vec2 enc = norm.z >= 0.0 ? norm.xy : (1.0 - abs(norm.yx)) * (sign(norm.xy) * -2.0 + 1.0);
    gl_FragData[1] = vec4(enc * 0.5 + 0.5, lm.x, lm.y);
    gl_FragData[2] = vec4(roughness, metallic, sss, emission);
}
