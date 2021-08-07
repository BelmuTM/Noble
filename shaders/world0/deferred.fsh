/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;
#include "/lib/uniforms.glsl"

void main() {

     if(texture2D(depthtex0, texCoords).r == 1.0) {
          vec4 sky = vec4(skyColor, 1.0);
          
          /*DRAWBUFFERS:0*/
          gl_FragData[0] = sky;
          return;
     }

     /*DRAWBUFFERS:4*/
     gl_FragData[0] = texture2D(colortex0, texCoords);
}