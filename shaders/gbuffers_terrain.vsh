#version 120

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;
varying vec3 tangent;
varying vec3 worldPos;
varying float vertexDistance;
varying float blockID;

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

attribute vec4 mc_Entity;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    tangent = normalize(gl_NormalMatrix * gl_MultiTexCoord3.xyz);
    vec4 pos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (gbufferModelViewInverse * pos).xyz;
    vertexDistance = length(pos.xyz);
    blockID = mc_Entity.x;
}
