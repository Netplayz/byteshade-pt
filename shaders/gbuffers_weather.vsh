#version 150 compatibility

out vec2 texcoord;
out vec4 glcolor;
out float vertexDistance;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    glcolor = gl_Color;
    vec4 pos = gl_ModelViewMatrix * gl_Vertex;
    vertexDistance = length(pos.xyz);
}
