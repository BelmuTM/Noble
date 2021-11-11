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
#include "/lib/util/blur.glsl"
#include "/lib/fragment/svgf.glsl"

void main() {
    vec3 globalIllumination = vec3(0.0);
    float ambientOcclusion = 1.0;

    if(!isSky(texCoords)) {
        #if GI == 1
            vec2 scaledUv = texCoords * GI_RESOLUTION; 
            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos(scaledUv);
                vec3 scaledNormal = normalize(decodeNormal(texture(colortex1, scaledUv).xy));

                globalIllumination = SVGF(colortex5, scaledViewPos, scaledNormal, scaledUv);
            #else
                globalIllumination = texture(colortex5, scaledUv).rgb;
            #endif
        #else 
            #if AO == 1
                #if AO_FILTER == 1
                    bool isMetal = texture(colortex2, texCoords).g * 255.0 > 229.5;
                    ambientOcclusion = isMetal ? 1.0 : gaussianBlur(texCoords, colortex5, vec2(1.0, 0.0), 1.0).a;
                #endif
            #endif
        #endif
    }

    /*DRAWBUFFERS:5*/
    gl_FragData[0] = vec4(globalIllumination, ambientOcclusion);
}
