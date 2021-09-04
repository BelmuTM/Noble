/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 330 compatibility

attribute vec3 mc_Entity;
attribute vec2 mc_midTexCoord;  
attribute vec3 at_midBlock;

#include "/settings.glsl"
#include "/lib/util/distort.glsl"

varying vec2 texCoords;
varying vec4 color;

uniform mat4 shadowModelViewInverse;

vec2 pack_voxelmap(in vec3 block) {
    #define res2D 512.0 // Shadow  map resolution
    #define res3D 64.0 // pow(res2D,2./3.)
    #define resRoot 8.0 // sqrt(res3D) or pow(res2D,1./3.)

    // Center
    block += res3D * 0.5;
    // Test if block is inside range
    bool test = all(equal(block, clamp(block, 0.0, res3D - 1.0)));

    //Get xz plane coordinates
    vec2 pixel = mod(block.xz, res3D);
    //Offset by y-cell position
    pixel += mod(floor(block.y / vec2(1.0, resRoot)), resRoot) * res3D + 0.5;
    return test ? pixel / res2D : vec2(-1.0);
}

void main(){
    gl_Position = ftransform();
    gl_Position.xy = distort3(gl_Position.xy);
    texCoords = gl_MultiTexCoord0.st;
    color = gl_Color;
}
