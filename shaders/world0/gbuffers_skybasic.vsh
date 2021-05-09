/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

varying vec2 TexCoords;
varying vec4 Color;

void main() {
	  gl_Position = ftransform();
		TexCoords = gl_MultiTexCoord0.st;

	  Color = gl_Color;
	  gl_FogFragCoord = gl_Position.z;
}
