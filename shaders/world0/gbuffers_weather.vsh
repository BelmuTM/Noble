/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec3 normal;
varying vec4 color;

void main() {
    gl_Position = ftransform();
    texCoords = gl_MultiTexCoord0.st;

    normal = gl_NormalMatrix * gl_Normal;
    color = gl_Color;

    lmCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    lmCoords = (lmCoords * 33.05 / 32.0) - (1.05 / 32.0);
}
