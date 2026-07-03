#version 150 compatibility

out vec2 texcoord;
out vec2 lmcoord;
out vec4 glcolor;
out vec3 normal;
out vec3 tangent;
out vec3 worldPos;
out float vertexDistance;
out float blockID;

uniform mat4 gbufferModelViewInverse;
uniform float frameTimeCounter;

in vec4 mc_Entity;

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
