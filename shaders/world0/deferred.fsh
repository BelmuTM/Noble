#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"

/*
const int colortex4Format = RGBA16F;
*/

void main() {
     /*DRAWBUFFERS:4*/
     if(isSky(texCoords)) {
          vec3 viewPos = getViewPos(texCoords);
          vec3 eyeDir = normalize(mat3(gbufferModelViewInverse) * viewPos);

          float angle = quintic(0.9998, 0.99995, dot(sunDir, normalize(viewPos)));
          vec3 sky = mix(getDayTimeSkyGradient(eyeDir, viewPos), vec3(2.0), angle); 
          
          gl_FragData[0] = vec4(sky, 1.0);
     } else {
          gl_FragData[0] = texture(colortex0, texCoords);
     }
}