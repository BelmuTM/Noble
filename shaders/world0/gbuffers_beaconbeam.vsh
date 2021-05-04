/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

varying vec2 TexCoords;
varying vec2 LightmapCoords;
varying vec3 Normal;
varying vec4 Color;

void main() {
    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.st;

    Normal = gl_NormalMatrix * gl_Normal;
    Color = gl_Color;

    LightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    LightmapCoords = (LightmapCoords * 33.05f / 32.0f) - (1.05f / 32.0f);
}
