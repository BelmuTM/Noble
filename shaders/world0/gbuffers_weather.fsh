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

uniform sampler2D colortex0;

void main() {
    vec4 Albedo = texture2D(colortex0, TexCoords) * Color;
    Albedo.rgb /= 2.0;

    /*DRAWBUFFERS:012*/
    gl_FragData[0] = Albedo;
    gl_FragData[1] = vec4(Normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(LightmapCoords, 0.0, 1.0);
}
