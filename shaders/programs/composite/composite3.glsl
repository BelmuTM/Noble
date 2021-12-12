/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/fragment/svgf.glsl"

void main() {
    vec4 color = texture(colortex0, texCoords);
    vec3 globalIllumination = vec3(0.0);

    #if GI == 1
        if(!isSky(texCoords)) {

            vec2 scaledUv = texCoords * GI_RESOLUTION; 
            #if GI_FILTER == 1
                vec3 scaledViewPos = getViewPos0(scaledUv);
                vec3 scaledNormal  = normalize(decodeNormal(texture(colortex1, scaledUv).xy));

                globalIllumination = SVGF(colortex5, scaledViewPos, scaledNormal, scaledUv);
            #else
                color.rgb = texture(colortex5, scaledUv).rgb;
            #endif
        }
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = color;
    gl_FragData[1] = vec4(globalIllumination, 1.0);
}
