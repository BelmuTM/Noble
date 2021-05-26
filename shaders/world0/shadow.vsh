/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

#include "/lib/util/distort.glsl"

varying vec2 texCoords;
varying vec4 Color;

void main(){
    gl_Position = ftransform();
    gl_Position.xyz = distort(gl_Position.xyz);
    texCoords = gl_MultiTexCoord0.st;
    Color = gl_Color;
}
