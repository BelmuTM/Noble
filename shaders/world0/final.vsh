/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 texCoords;

void main() {
    gl_Position = ftransform();
    texCoords = gl_MultiTexCoord0.st;
}
