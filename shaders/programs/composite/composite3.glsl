/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:047 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec3 bloomBuffer;
layout (location = 2) out vec4 volumetricLight;

#include "/include/atmospherics/celestial.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/atmospherics/fog.glsl"

#include "/include/fragment/water.glsl"

void main() {
         color   = texture(colortex0, texCoords).rgb;
    bool inWater = isEyeInWater > 0.5;
    bool sky     = isSky(texCoords);

    vec3 viewPos0 = getViewPos0(texCoords);
    vec3 viewDir0 = normalize(mat3(gbufferModelViewInverse) * viewPos0);

    Material mat = getMaterial(texCoords);
    vec2 coords  = texCoords;

    if(!sky) {
        // Props to SixthSurge#3922 for suggesting to use depthtex2 as the caustics texture
        #if WATER_CAUSTICS == 1
            bool canCast = isEyeInWater > 0.5 ? viewPos0.z == getViewPos1(texCoords).z : mat.blockId == 1;
            //if(canCast) color += waterCaustics(texCoords) * 500.0 * max0(dot(mat3(gbufferModelViewInverse) * mat.normal, vec3(0.0, 1.0, 0.0)));
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFRACTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if REFRACTIONS == 1
            vec3 hitPos;
            if(mat.blockId > 0 && mat.blockId <= 4) {
                color  = simpleRefractions(viewPos0, mat, hitPos);
                coords = hitPos.xy;
            }
        #endif

        //////////////////////////////////////////////////////////
        /*------------------ ALPHA BLENDING --------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            vec4 translucents = texture(colortex1, coords);
                 color        = mix(color, translucents.rgb, translucents.a);
        #endif
    }

        //////////////////////////////////////////////////////////
        /*-------------------- WATER FOG -----------------------*/
        //////////////////////////////////////////////////////////

        #ifdef WORLD_OVERWORLD
            bool canFog = inWater ? true : mat.blockId == 1;
        
            if(canFog) {
                vec3 worldPos0 = transMAD(gbufferModelViewInverse, getViewPos0(coords));
                vec3 worldPos1 = transMAD(gbufferModelViewInverse, getViewPos1(coords));

                vec3 startPos = inWater ? vec3(0.0) : worldPos0;
                vec3 endPos   = inWater ? worldPos0 : worldPos1;

                vec3 skyIlluminance = texture(colortex7, texCoords).rgb;

                #if WATER_FOG == 0
                    float depthDist = inWater ? length(worldPos0) : distance(worldPos0, worldPos1);
                    waterFog(color, depthDist, dot(viewDir0, sceneSunDir), skyIlluminance, mat.lightmap.y);
                #else
                    vec3 worldDir  = normalize(inWater ? worldPos0 : worldPos1);
                    volumetricWaterFog(color, startPos, endPos, worldDir, skyIlluminance, mat.lightmap.y);
                #endif
            }
        #endif

    if(!sky) {
        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            #if REFLECTIONS == 1
                vec3 reflections = texture(colortex4, texCoords * REFLECTIONS_RES).rgb;
                float NdotV      = maxEps(dot(mat.normal, -normalize(viewPos0)));

                if(mat.rough > 0.05) {
                    float DFG = envBRDFApprox(NdotV, mat);
                    color = mix(color, reflections, DFG);
                } else {
                    color += reflections;
                }
            #endif
        #endif
    }

    //////////////////////////////////////////////////////////
    /*------------------ VL / RAIN FOG ---------------------*/
    //////////////////////////////////////////////////////////

    #if VL == 1
        #ifdef WORLD_OVERWORLD
            volumetricLight = vec4(volumetricLighting(viewPos0), 1.0);
        #endif
    #else
        #if RAIN_FOG == 1
            if(rainStrength > 0.0 && !inWater) { volumetricGroundFog(color, viewPos0, getMaterial(texCoords).lightmap.y); }
        #endif
    #endif

    #if BLOOM == 1
        bloomBuffer = color;
    #endif
}
