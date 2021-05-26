/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 texCoords;
varying vec4 color;

void main() {
	gl_Position = ftransform();
	texCoords = gl_MultiTexCoord0.st;

	color = gl_Color;
	gl_FogFragCoord = gl_Position.z;
}
