/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

attribute vec3 mc_Entity;

varying vec2 TexCoords;
varying vec2 LightmapCoords;
varying vec3 Normal;
varying vec4 Color;
varying vec3 viewPos;
varying float blockId;

uniform float viewWidth, viewHeight;

void main() {
    gl_Position = ftransform();
    TexCoords = gl_MultiTexCoord0.st;
    viewPos = (gl_ModelViewMatrix * gl_Vertex).xyz;

    Normal = gl_NormalMatrix * gl_Normal;
    Color = gl_Color;
    
    blockId = mc_Entity.x;

    LightmapCoords = mat2(gl_TextureMatrix[1]) * gl_MultiTexCoord1.st;
    LightmapCoords = (LightmapCoords * 33.05f / 32.0f) - (1.05f / 32.0f);
}
