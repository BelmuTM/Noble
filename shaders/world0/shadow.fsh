/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 texCoords;
varying vec4 Color;

uniform sampler2D colortex0;

void main() {
    gl_FragData[0] = texture2D(colortex0, texCoords) * Color;
}
