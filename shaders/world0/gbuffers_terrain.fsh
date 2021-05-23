/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 TexCoords;
varying vec2 LightmapCoords;
varying vec3 Normal;
varying vec4 Color;
varying float blockId;

uniform sampler2D colortex0;

void main() {
    vec4 Albedo = texture2D(colortex0, TexCoords) * Color;

    /*DRAWBUFFERS:0123*/
    gl_FragData[0] = Albedo;
    gl_FragData[1] = vec4(Normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(LightmapCoords, 0.0, 1.0);
    gl_FragData[3] = vec4((blockId - 1000.0) / 255.0);
}
