#version 120

varying vec2 texcoord;
varying vec2 lmcoord;
varying vec4 glcolor;
varying vec3 normal;
varying vec3 worldPos;
varying float vertexDistance;
varying vec3 sunVec;
varying vec3 upVec;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform float timeAngle;
uniform float sunPathRotation;

void main() {
    gl_Position = ftransform();
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    glcolor = gl_Color;
    normal = normalize(gl_NormalMatrix * gl_Normal);
    vec4 pos = gl_ModelViewMatrix * gl_Vertex;
    worldPos = (gbufferModelViewInverse * pos).xyz;
    vertexDistance = length(pos.xyz);

    vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329252), -sin(sunPathRotation * 0.01745329252));
    float ang = fract(timeAngle - 0.25);
    ang = (ang + (cos(ang * 3.14159265359) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530718;
    sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);
    upVec = normalize(gbufferModelView[1].xyz);
}
