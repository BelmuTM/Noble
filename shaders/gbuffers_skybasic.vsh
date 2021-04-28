/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

varying vec4 Color;

void main() {
	  gl_Position = ftransform();

	  Color = gl_Color;
	  gl_FogFragCoord = gl_Position.z;
}
