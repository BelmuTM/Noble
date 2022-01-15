/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:047 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 bloomBuffer;
layout (location = 2) out vec4 volumetricLighting;

#include "/include/atmospherics/celestial.glsl"
#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/filter.glsl"
#include "/include/fragment/shadows.glsl"
#include "/include/atmospherics/fog.glsl"

void main() {
    color         = texture(colortex0, texCoords);
    vec3 viewPos0 = getViewPos0(texCoords);

    if(!isSky(texCoords)) {
        vec3 viewPos1 = getViewPos1(texCoords);
        vec3 viewDir0 = normalize(mat3(gbufferModelViewInverse) * viewPos0);

        material mat      = getMaterial(texCoords);
        material transMat = getMaterialTranslucents(texCoords);

        #if GI == 1
            #if GI_FILTER == 1                
                color.rgb = SVGF(texCoords, colortex0, viewPos0, mat.normal, 1.5, 3);
            #endif
        #endif

        bool isWater    = transMat.blockId == 1;
        bool inWater    = isEyeInWater > 0.5;
        float depthDist = 0.0;

        vec3 skyIlluminance = vec3(0.0), totalIllum = vec3(1.0);
        vec4 shadowmap      = texture(colortex3, texCoords);

        if(viewPos0.z != viewPos1.z) {
            vec2 coords = texCoords;
            mat         = transMat;

            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if REFRACTIONS == 1
                vec3 hitPos;
                if(mat.blockId > 0 && mat.blockId <= 4) {
                    color.rgb = simpleRefractions(viewPos0, mat, hitPos);
                    coords    = hitPos.xy;
                }
            #endif

            // Outer fog
            if(isWater) {
                depthDist = distance(
	                transMAD3(gbufferModelViewInverse, getViewPos0(coords)),
		            transMAD3(gbufferModelViewInverse, getViewPos1(coords))
	            );

                waterFog(color.rgb, depthDist, dot(viewDir0, playerSunDir), skyIlluminance);
            }

            #if GI == 0
                #ifdef WORLD_OVERWORLD
                    skyIlluminance = texture(colortex7, texCoords).rgb;

                    vec3 sunTransmit  = atmosphereTransmittance(atmosRayPos, playerSunDir)  * sunIlluminance;
                    vec3 moonTransmit = atmosphereTransmittance(atmosRayPos, playerMoonDir) * moonIlluminance;
                    totalIllum        = sunTransmit + moonTransmit;
                #else
                    shadowmap.rgb = vec3(0.0);
                #endif

                vec3 transLighting = applyLightingTranslucents(viewPos0, mat.normal, shadowDir, mat, shadowmap.rgb, totalIllum, skyIlluminance, shadowmap.a);
                color.rgb          = mix(color.rgb, transLighting, mat.alpha);
            #endif
        }

        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            #if REFLECTIONS == 1
                float resolution = REFLECTIONS_TYPE == 1 ? ROUGH_REFLECT_RES : 1.0;
                float NdotV      = maxEps(dot(mat.normal, -normalize(viewPos0)));
                vec3 reflections = texture(colortex4, texCoords * resolution).rgb;

                if(mat.rough > 0.05) {
                    vec3 DFG  = envBRDFApprox(getSpecularColor(mat.F0, mat.albedo), mat.rough, NdotV);
                    color.rgb = mix(color.rgb, reflections, DFG);
                } else {
                    color.rgb += reflections;
                }
            #endif
        #endif

        // Inner fog
        if(inWater) {
            depthDist = length(transMAD3(gbufferModelViewInverse, viewPos0));
            waterFog(color.rgb, depthDist, dot(viewDir0, playerSunDir), skyIlluminance);
        }
    }

    #if VL == 1
        #ifdef WORLD_OVERWORLD
            volumetricLighting = VL == 0 ? vec4(0.0) : vec4(volumetricFog(viewPos0), 1.0);
        #endif
    #endif

    #if BLOOM == 1
        bloomBuffer = luminance(clamp16(color.rgb)) / bits16 > BLOOM_LUMA_THRESH ? color : vec4(0.0);
    #else
        bloomBuffer = vec4(0.0);
    #endif

    color = max0(sqrt(color));
}
