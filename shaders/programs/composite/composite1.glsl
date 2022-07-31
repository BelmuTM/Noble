/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if GI == 1 && GI_FILTER == 1
    /* RENDERTARGETS: 4,2,12 */

    layout (location = 0) out vec3 color;
    layout (location = 1) out vec3 fog;
    layout (location = 2) out vec3 moments;

    #include "/include/fragment/atrous.glsl"
#else
    /* RENDERTARGETS: 4,2 */

    layout (location = 0) out vec3 color;
    layout (location = 1) out vec3 fog;
#endif

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/fog.glsl"

#include "/include/fragment/reflections.glsl"
#include "/include/fragment/water.glsl"

void main() {
    color = texture(colortex4, texCoords).rgb;

    Material mat = getMaterial(texCoords);
    vec3 coords  = vec3(texCoords, 0.0);

    vec3 viewPos0 = getViewPos0(texCoords);
    vec3 viewPos1 = getViewPos1(texCoords);

    vec3 worldPos0 = transMAD(gbufferModelViewInverse, viewPos0);
    vec3 worldPos1 = transMAD(gbufferModelViewInverse, viewPos1);

    float VdotL = dot(normalize(worldPos0), sceneShadowDir);

    vec3 directIlluminance = sampleDirectIlluminance();
    vec3 skyIlluminance    = texture(colortex6, texCoords).rgb * RCP_PI;

    bool  sky      = isSky(texCoords);
    float skyLight = 0.0;

    if(!sky) {
        skyLight = getSkyLightFalloff(mat.lightmap.y);

        //////////////////////////////////////////////////////////
        /*---------------- GLOBAL ILLUMINATION -----------------*/
        //////////////////////////////////////////////////////////

        #if GI == 1
            #if GI_FILTER == 1
                aTrousFilter(color, colortex4, texCoords, moments, 4);
            #endif

            vec3 direct         = texture(colortex10, texCoords * GI_RESOLUTION).rgb;
            vec3 indirectBounce = texture(colortex11, texCoords * GI_RESOLUTION).rgb;
            
            color = direct + (indirectBounce * color);
        #endif

        if(viewPos0.z != viewPos1.z) {
            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if REFRACTIONS == 1
                color = simpleRefractions(viewPos0, mat, coords);
                mat   = getMaterial(coords.xy);

                worldPos0 = transMAD(gbufferModelViewInverse, getViewPos0(coords.xy));
                worldPos1 = transMAD(gbufferModelViewInverse, getViewPos1(coords.xy));
            #endif

            //////////////////////////////////////////////////////////
            /*---------------- FRONT TO BACK AIR_FOG -------------------*/
            //////////////////////////////////////////////////////////

            #ifdef WORLD_OVERWORLD
                if(isEyeInWater != 1 && mat.blockId == 1) {
                    #if WATER_FOG == 0
                        waterFog(color, worldPos0, worldPos1, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #else
                        volumetricWaterFog(color, worldPos0, worldPos1, VdotL, directIlluminance, skyIlluminance, skyLight, false);
                    #endif
                } else {
                    #if AIR_FOG == 1
                        volumetricFog(color, worldPos0, worldPos1, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #else
                        groundFog(color, worldPos0, directIlluminance, skyIlluminance, skyLight, skyCheck);
                    #endif
                }
            #endif
        }
    
        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            vec3 viewDir0 = -normalize(viewPos0);

            #if SPECULAR == 1
                vec3 shadowmap = texture(colortex3, coords.xy).rgb;
                color         += computeSpecular(mat.normal, viewDir0, shadowDir, mat) * directIlluminance * shadowmap;
            #endif

            #if REFLECTIONS == 1
                color += texture(colortex2, texCoords * REFLECTIONS_RES).rgb;
            #endif
        #endif
    } else {
        skyLight = 1.0;
    }

    //////////////////////////////////////////////////////////
    /*---------------- EYE TO FRONT AIR_FOG ----------------*/
    //////////////////////////////////////////////////////////

    #ifdef WORLD_OVERWORLD
        if(isEyeInWater == 1) {
            #if WATER_FOG == 0
                waterFog(color, gbufferModelViewInverse[3].xyz, worldPos0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #else
                volumetricWaterFog(color, gbufferModelViewInverse[3].xyz, worldPos0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        } else {
            #if AIR_FOG == 1
                volumetricFog(color, gbufferModelViewInverse[3].xyz, worldPos0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #else
                groundFog(color, gbufferModelViewInverse[3].xyz, directIlluminance, skyIlluminance, skyLight, skyCheck);
            #endif
        }
    #endif
}
