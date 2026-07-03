#version 120

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;
varying vec3 worldPos;
varying float vertexDistance;

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

void main() {
    vec4 pos = gl_Vertex;

    float wave = sin(pos.x * 2.0 + pos.z * 1.5 + frameTimeCounter * 1.2) * 0.05
               + sin(pos.x * 3.5 - pos.z * 2.0 + frameTimeCounter * 0.8) * 0.03;
    pos.y += wave;

    gl_Position = gl_ProjectionMatrix * gl_ModelViewMatrix * pos;
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;

    vec3 norm = normalize(gl_NormalMatrix * gl_Normal);
    norm.x += sin(pos.x * 2.0 + pos.z * 1.5 + frameTimeCounter * 1.2) * 0.3;
    norm.z += cos(pos.x * 3.5 - pos.z * 2.0 + frameTimeCounter * 0.8) * 0.3;
    normal = normalize(norm);

    vec4 mPos = gl_ModelViewMatrix * pos;
    worldPos = (gbufferModelViewInverse * mPos).xyz;
    vertexDistance = length(mPos.xyz);
}
