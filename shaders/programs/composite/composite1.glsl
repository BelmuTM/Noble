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
    vec2 coords  = texCoords;

    vec3 viewPos0  = getViewPos0(texCoords);
    vec3 sceneDir0 = normalize(mat3(gbufferModelViewInverse) * viewPos0);

    bool inWater  = isEyeInWater > 0.5;
    bool skyCheck = isSky(texCoords);

    vec3 directIlluminance = sampleDirectIlluminance();
    vec3 skyIlluminance    = texture(colortex6, texCoords).rgb * RCP_PI;
    float skyLight         = getSkyLightFalloff(mat.lightmap.y);

    if(!skyCheck) {
        #if GI == 1
            #if GI_FILTER == 1
                aTrousFilter(color, colortex4, texCoords, moments, 4);
            #endif

            vec3 direct         = texture(colortex10, texCoords * GI_RESOLUTION).rgb;
            vec3 indirectBounce = texture(colortex11, texCoords * GI_RESOLUTION).rgb;

            color = direct + (indirectBounce * color);
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

                #if WATER_FOG == 0
                    float depthDist = inWater ? length(worldPos0) : distance(worldPos0, worldPos1);
                    waterFog(color, depthDist, dot(sceneDir0, sceneSunDir), directIlluminance, skyIlluminance, skyLight);
                #else
                    vec3 worldDir  = normalize(inWater ? worldPos0 : worldPos1);
                    volumetricWaterFog(color, startPos, endPos, worldDir, directIlluminance, skyIlluminance, skyLight, mat.depth1);
                #endif
            }
        #endif

    if(!skyCheck) {
        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            vec3 viewDir0 = -normalize(viewPos0);

            #if SPECULAR == 1
                vec3 shadowmap = texture(colortex3, coords).rgb;
                color         += computeSpecular(mat.normal, viewDir0, shadowDir, mat) * directIlluminance * shadowmap;
            #endif

            #if REFLECTIONS == 1
                color += texture(colortex2, texCoords * REFLECTIONS_RES).rgb;
            #endif
        #endif
    }

    //////////////////////////////////////////////////////////
    /*------------------ FOG / RAIN FOG ---------------------*/
    //////////////////////////////////////////////////////////

    #if GI == 0
        #ifdef WORLD_OVERWORLD
            #if FOG == 1
                volumetricFog(color, viewPos0, directIlluminance, skyIlluminance, skyLight);
            #else
                groundFog(color, viewPos0, directIlluminance, skyIlluminance, skyLight, skyCheck);
            #endif
        #endif
    #endif
}
