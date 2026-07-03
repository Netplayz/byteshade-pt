#version 150 compatibility

/* RENDERTARGETS: 0,1,2,3,4 */

in vec2 texcoord;
in vec2 lmcoord;
in vec4 glcolor;
in vec3 normal;
in vec3 tangent;
in vec3 worldPos;
in float vertexDistance;
in float blockID;

uniform vec3 cameraPosition;
uniform float near;
uniform float far;
uniform float frameTimeCounter;
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
    float ao = 1.0;
    float flags = 0.0;

    int id = int(blockID);
    if (id == 4 || id == 48) { roughness = 0.9; specular = 0.05; }
    else if (id == 1 || id == 3 || id == 5) { roughness = 0.7; metallic = 0.0; specular = 0.2; }
    else if (id == 41) { roughness = 0.2; metallic = 1.0; specular = 1.0; }
    else if (id == 42) { roughness = 0.3; metallic = 1.0; specular = 1.0; }
    else if (id == 57) { roughness = 0.1; metallic = 0.0; specular = 1.0; }
    else if (id == 20 || id == 95 || id == 160) { roughness = 0.0; specular = 0.5; }
    else if (id == 89 || id == 91 || id == 169) { emission = 1.0; flags = 1.0; }
    else if (id == 50 || id == 76) { emission = 0.9; flags = 1.0; }
    else if (id == 10 || id == 11) { emission = 1.0; flags = 1.0; roughness = 0.2; }
    else if (id == 5) { roughness = 0.8; specular = 0.05; }
    else if (id == 18 || id == 161) { roughness = 1.0; specular = 0.0; }

    float linDepth = linearizeDepth(gl_FragCoord.z, near, far);

    gl_FragData[0] = vec4(albedo.rgb, roughness);
    gl_FragData[1] = vec4(enc, metallic);
    gl_FragData[2] = vec4(emission, specular, flags, 0.0);
        vec3 lightColor = texture2D(lightmap, lmcoord).rgb * ao;
    gl_FragData[3] = vec4(linDepth, lightColor);
    gl_FragData[4] = vec4(0.0);
}
