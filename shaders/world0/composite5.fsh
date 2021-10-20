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
#include "/lib/fragment/svgf.glsl"

void main() {
    vec3 globalIllumination = vec3(0.0);
    if(!isSky(texCoords)) {
        #if GI == 1
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos(texCoords);
                vec3 normal = normalize(decodeNormal(texture(colortex1, texCoords).xy));
                
                globalIllumination = SVGF(colortex9, viewPos, normal, texCoords, vec2(0.0, 1.0));
            #else
                globalIllumination = texture(colortex9, texCoords).rgb;
            #endif
        #endif
    }
    /*DRAWBUFFERS:9*/
    gl_FragData[0] = vec4(globalIllumination, 1.0);
}
