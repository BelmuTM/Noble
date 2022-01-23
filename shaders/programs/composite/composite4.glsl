/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:07 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec4 volumetricLight;

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

            #ifdef WORLD_OVERWORLD
                // Outer fog
                if(isWater) {
                    vec3 worldPos0 = transMAD3(gbufferModelViewInverse, getViewPos0(coords));
                    vec3 worldPos1 = transMAD3(gbufferModelViewInverse, getViewPos1(coords));
                    vec3 waterDir  = normalize(inWater ? worldPos0 : worldPos1);

                    #if WATER_FOG == 0
                        depthDist = distance(worldPos0, worldPos1);
                        waterFog(color.rgb, depthDist, dot(viewDir0, sceneSunDir), skyIlluminance);
                    #else
                        volumetricWaterFog(color.rgb, worldPos0, worldPos1, waterDir);
                    #endif
                }
            #endif

            #if GI == 0
                #ifdef WORLD_OVERWORLD
                    skyIlluminance = texture(colortex7, texCoords).rgb;
                    totalIllum     = shadowLightTransmittance();
                #else
                    shadowmap.rgb = vec3(0.0);
                #endif

                vec3 transLighting = applyLighting(viewPos0, mat, shadowmap.rgb, totalIllum, skyIlluminance, shadowmap.a, false);
                color.rgb          = mix(color.rgb, transLighting, mat.alpha);
            #endif
        }

        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            #if REFLECTIONS == 1
                vec3 reflections = texture(colortex4, texCoords * REFLECTIONS_RES).rgb;

                if(mat.rough > 0.05) {
                    vec3 DFG  = envBRDFApprox(getMetalF0(mat.F0, mat.albedo), mat.rough, dot(mat.normal, -normalize(viewPos0)));
                    color.rgb = mix(color.rgb, reflections, DFG);
                } else {
                    color.rgb += reflections;
                }
            #endif
        #endif

        #ifdef WORLD_OVERWORLD
            // Inner fog
            if(inWater) {
                vec3 worldPos0 = transMAD3(gbufferModelViewInverse, viewPos0);

                #if WATER_FOG == 0
                    waterFog(color.rgb, length(worldPos0), dot(viewDir0, sceneSunDir), skyIlluminance);
                #else
                    vec3 worldPos1 = transMAD3(gbufferModelViewInverse, viewPos1);
                    vec3 waterDir  = normalize(inWater ? worldPos0 : worldPos1);
                    
                    volumetricWaterFog(color.rgb, vec3(0.0), worldPos0, waterDir);
                #endif
            }
        #endif
    }

    #if VL == 1
        #ifdef WORLD_OVERWORLD
            volumetricLight = vec4(volumetricLighting(viewPos0), 1.0);
        #endif
    #else
        #if RAIN_FOG == 1
            if(rainStrength > 0.0 && isEyeInWater < 0.5) {
                vlGroundFog(color.rgb, viewPos0);
            }
        #endif
    #endif
}
