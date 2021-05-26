/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

#version 120

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec3 normal;
varying vec4 color;

uniform sampler2D colortex0;

void main() {
    vec4 Albedo = texture2D(colortex0, texCoords) * color;

    /*DRAWBUFFERS:012*/
    gl_FragData[0] = Albedo;
    gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
    gl_FragData[2] = vec4(lmCoords, 0.0, 1.0);
}
