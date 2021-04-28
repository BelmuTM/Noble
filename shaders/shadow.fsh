/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

varying vec2 TexCoords;
varying vec4 Color;

uniform sampler2D colortex0;

void main() {
    gl_FragData[0] = (texture2D(colortex0, TexCoords) * Color);
}
