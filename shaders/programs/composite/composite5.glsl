/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/svgf.glsl"

void main() {
    vec4 color = texture(colortex0, texCoords);

    if(!isSky(texCoords)) {
        vec3 viewPos = getViewPos0(texCoords);
        vec3 normal  = normalize(decodeNormal(texture(colortex1, texCoords).xy));

        #if GI == 1
            #if GI_FILTER == 1                
                color.rgb = SVGF(colortex5, viewPos, normal, texCoords);
            #endif
        #else
            #if REFLECTIONS == 1
                float resolution   = REFLECTIONS_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
                float NdotV        = maxEps(dot(normal, -normalize(viewPos)));
                float roughness    = texture(colortex2, texCoords).r;
                vec3 specularColor = texture(colortex9, texCoords * resolution).rgb;
            
                vec3 reflections = texture(colortex5, texCoords * resolution).rgb;

                if(roughness > 0.05) {
                    vec3 DFG  = envBRDFApprox(specularColor, roughness, NdotV);
                    color.rgb = mix(color.rgb, reflections, DFG);
                } else {
                    color.rgb += reflections;
                }
            #endif
        #endif
    }

    #if VL == 1
        color.rgb += VL_FILTER == 1 ? boxBlur(texCoords, colortex8, 2).rgb : texture(colortex8, texCoords).rgb;
    #endif

    vec3 brightSpots = vec3(0.0);
    #if BLOOM == 1
        brightSpots = luminance(color.rgb) / bits16 > BLOOM_LUMA_THRESHOLD ? color.rgb : vec3(0.0);
    #endif

    /*DRAWBUFFERS:05*/
    gl_FragData[0] = sqrt(max0(color));
    gl_FragData[1] = vec4(brightSpots, 1.0);
}
