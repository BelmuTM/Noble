/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/fragment/svgf.glsl"

void main() {
    vec3 outColor = texture(colortex5, texCoords).rgb;
    
    #if GI == 1
        if(!isSky(texCoords)) {
            #if GI_FILTER == 1
                vec3 viewPos = getViewPos0(texCoords);
                vec3 normal  = normalize(decodeNormal(texture(colortex1, texCoords).xy));

                outColor = SVGF(colortex5, viewPos, normal, texCoords);
            #endif
        }
    #endif
    /*DRAWBUFFERS:5*/
    gl_FragData[0] = vec4(outColor, 1.0);
}
