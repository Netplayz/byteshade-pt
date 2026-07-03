#version 120

/* RENDERTARGETS: 0,1,2 */

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;

uniform sampler2D texture;
uniform sampler2D lightmap;

void main() {
    vec4 albedo = texture2D(texture, texcoord) * glcolor;
    if (albedo.a < 0.004) discard;
    albedo.rgb = pow(albedo.rgb, vec3(2.2));

    vec2 lm = clamp(lmcoord, vec2(0.0), vec2(1.0));
    vec3 norm = normalize(normal);

    gl_FragData[0] = vec4(albedo.rgb, 0.0);
    vec2 enc = norm.z >= 0.0 ? norm.xy : (1.0 - abs(norm.yx)) * (sign(norm.xy) * -2.0 + 1.0);
    gl_FragData[1] = vec4(enc * 0.5 + 0.5, lm.x, lm.y);
    gl_FragData[2] = vec4(0.8, 0.0, 0.0, 0.0);
}
