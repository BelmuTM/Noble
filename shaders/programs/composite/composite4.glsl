/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 5,6 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec3 fog;

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/reflections.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/fog.glsl"

#include "/include/fragment/pathtracer.glsl"

#include "/include/fragment/water.glsl"
#include "/include/fragment/atrous.glsl"

void main() {
    color = texture(colortex5, texCoords).rgb;

    Material mat = getMaterial(texCoords);
    vec2 coords  = texCoords;

    vec3 viewPos0  = getViewPos0(texCoords);
    vec3 sceneDir0 = normalize(mat3(gbufferModelViewInverse) * viewPos0);

    bool inWater = isEyeInWater > 0.5;
    bool sky     = isSky(texCoords);

    if(!sky) {
        #if GI == 1
            #if GI_FILTER == 1
                vec3 a;
                aTrousFilter(color, colortex5, texCoords, a, 4);
            #endif

            vec3 direct         = texture(colortex10, texCoords * GI_RESOLUTION).rgb;
            vec3 indirectBounce = texture(colortex11, texCoords * GI_RESOLUTION).rgb;

            color = direct + (indirectBounce * color);
            //color = vec3(gaussianVariance(colortex12, texCoords));
        #endif

        #if WATER_CAUSTICS == 1
            //bool canCast = isEyeInWater > 0.5 ? viewPos0.z == getViewPos1(texCoords).z : mat.blockId == 1;
            //if(canCast) color += waterCaustics(texCoords) * 500.0 * max0(dot(mat3(gbufferModelViewInverse) * mat.normal, vec3(0.0, 1.0, 0.0)));
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFRACTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if REFRACTIONS == 1
            vec3 hitPos;
            if(viewPos0.z != getViewPos1(texCoords).z) {
                color  = simpleRefractions(viewPos0, mat, hitPos);
                coords = hitPos.xy;
            }
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

                vec3 skyIlluminance = texture(colortex6, texCoords).rgb;

                #if WATER_FOG == 0
                    float depthDist = inWater ? length(worldPos0) : distance(worldPos0, worldPos1);
                    waterFog(color, depthDist, dot(sceneDir0, sceneSunDir), skyIlluminance, mat.lightmap.y);
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
            vec3 viewDir0 = -normalize(viewPos0);

            #if SPECULAR == 1
                vec3 shadowmap = texture(colortex3, coords).rgb;
                color         += (computeSpecular(mat.normal, viewDir0, shadowDir, mat) * sampleDirectIlluminance()) * shadowmap;
            #endif

            #if REFLECTIONS == 1
                color += texture(colortex2, texCoords * REFLECTIONS_RES).rgb;
            #endif
        #endif
    }

    //////////////////////////////////////////////////////////
    /*------------------ VL / RAIN FOG ---------------------*/
    //////////////////////////////////////////////////////////

    #if VL == 1
        #ifdef WORLD_OVERWORLD
            fog = volumetricFog(viewPos0, mat.lightmap.y);
        #endif
    #else
        #if RAIN_FOG == 1
            if(wetness > 0.0 && !inWater) { groundFog(color, viewPos0, getMaterial(texCoords).lightmap.y, sky); }
        #endif
    #endif
}
