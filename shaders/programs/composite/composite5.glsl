/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:04 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 bloomBuffer;

#include "/include/atmospherics/celestial.glsl"
#include "/include/utility/blur.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/filter.glsl"

void main() {
    color = texture(colortex0, texCoords);

    if(!isSky(texCoords)) {
        vec3 viewPos = getViewPos0(texCoords);
        material mat = getMaterial(texCoords);

        #if GI == 1
            #if GI_FILTER == 1                
                color.rgb = SVGF(texCoords, colortex0, viewPos, mat.normal, 1.5, 3);
            #endif
        #endif

        /*
        vec4 tmp    = texture(colortex4, texCoords);
        float alpha = texture(depthtex0, texCoords).r == texture(depthtex1,texCoords).r ? 0.0 : tmp.a;
        color.rgb   = mix(color.rgb * mix(vec3(1.0), tmp.rgb, tmp.a), tmp.rgb, tmp.a);
        */

        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            #if REFLECTIONS == 1
                float resolution   = REFLECTIONS_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
                float NdotV        = maxEps(dot(mat.normal, -normalize(viewPos)));
                vec3 specularColor = texture(colortex3, texCoords * resolution).rgb;
            
                vec3 reflections = texture(colortex4, texCoords * resolution).rgb;

                if(mat.rough > 0.05) {
                    vec3 DFG  = envBRDFApprox(specularColor, mat.rough, NdotV);
                    color.rgb = mix(color.rgb, reflections, DFG);
                } else {
                    color.rgb += reflections;
                }
            #endif
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFRACTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if REFRACTIONS == 1
            if(mat.blockId > 0 && mat.blockId <= 4) {
                color.rgb = simpleRefractions(viewPos, mat);
            }
        #endif

        //////////////////////////////////////////////////////////
        /*--------------------- WATER FOG ----------------------*/
        //////////////////////////////////////////////////////////

        bool isWater    = mat.blockId == 1;
        bool inWater    = isEyeInWater > 0.5;
        float depthDist = 0.0;

        if(isWater || inWater) {
            depthDist = inWater ? length(transMAD3(gbufferModelViewInverse, viewPos)) :
            distance(
	            transMAD3(gbufferModelViewInverse, viewPos),
		        transMAD3(gbufferModelViewInverse, getViewPos1(texCoords))
	        );

            vec3 transmittance = exp(-WATER_ABSORPTION_COEFFICIENTS * WATER_DENSITY * depthDist);
            color.rgb         *= transmittance;
        }
    }

    #if VL == 1
        color.rgb += VL_FILTER == 1 ? boxBlur(texCoords, colortex7, 2).rgb : texture(colortex7, texCoords).rgb;
    #endif

    #if BLOOM == 1
        bloomBuffer = luminance(clamp16(color.rgb)) / bits16 > BLOOM_LUMA_THRESH ? color : vec4(0.0);
    #else
        bloomBuffer = vec4(0.0);
    #endif

    color = max0(sqrt(color));
}
