/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 4 */

layout (location = 0) out vec3 color;

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/fog.glsl"

#include "/include/fragment/reflections.glsl"
#include "/include/fragment/water.glsl"

void main() {
    color = texture(colortex13, texCoords).rgb;

    //////////////////////////////////////////////////////////
    /*---------------- GLOBAL ILLUMINATION -----------------*/
    //////////////////////////////////////////////////////////

    #if GI == 1
        vec2 scaledUv = texCoords * GI_SCALE;
        color = texture(colortex5, scaledUv).rgb;

        vec3 direct   = texture(colortex9,  scaledUv).rgb;
        vec3 indirect = texture(colortex10, scaledUv).rgb;
        
        color = direct + (indirect * color);
        // color = vec3(texture(colortex11, scaledUv).b);
    #endif

    Material mat = getMaterial(texCoords);
    vec3 coords  = vec3(texCoords, 0.0);

    vec3 viewPos0  = getViewPos0(texCoords);
    vec3 viewPos1  = getViewPos1(texCoords);
    vec3 scenePos0 = viewToScene(viewPos0);
    vec3 scenePos1 = viewToScene(viewPos1);

    float VdotL = dot(normalize(scenePos0), shadowLightVector);

    vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
    
    #ifdef WORLD_OVERWORLD
        skyIlluminance    = texture(colortex6,  texCoords).rgb * RCP_PI;
        directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;
    #endif

    bool  sky      = isSky(texCoords);
    float skyLight = 0.0;

    if(!sky) {
        skyLight = getSkyLightFalloff(mat.lightmap.y);

        if(viewPos0.z != viewPos1.z) {
            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if GI == 0 && REFRACTIONS == 1
                color     = refractions(viewPos0, scenePos1, mat, coords);
                scenePos1 = viewToScene(getViewPos1(coords.xy));
            #endif

            //////////////////////////////////////////////////////////
            /*---------------- FRONT TO BACK AIR_FOG -------------------*/
            //////////////////////////////////////////////////////////

            #ifdef WORLD_OVERWORLD
                if(isEyeInWater != 1 && mat.blockId == 1) {
                    #if WATER_FOG == 0
                        waterFog(color, scenePos0, scenePos1, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #else
                        bool skyTranslucents = texture(depthtex1, coords.xy).r == 1.0;
                        volumetricWaterFog(color, scenePos0, scenePos1, VdotL, directIlluminance, skyIlluminance, skyLight, skyTranslucents);
                    #endif
                } else {
                    #if AIR_FOG == 1
                        volumetricFog(color, scenePos0, scenePos1, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #else
                        fog(color, viewPos0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
                    #endif
                }
            #endif
        }
    
        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            #if SPECULAR == 1
                vec3 visibility = texture(colortex3, coords.xy).rgb;
                #ifdef SUNLIGHT_LEAKING_FIX
                    visibility *= float(mat.lightmap.y > EPS);
                #endif

                color += computeSpecular(mat.normal, normalize(-viewPos0), shadowVec, mat) * directIlluminance * visibility;
            #endif

            #if REFLECTIONS == 1
                color += texture(colortex2, texCoords).rgb;
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
                waterFog(color, gbufferModelViewInverse[3].xyz, scenePos0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #else
                volumetricWaterFog(color, gbufferModelViewInverse[3].xyz, scenePos0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        } else {
            #if AIR_FOG == 1
                volumetricFog(color, gbufferModelViewInverse[3].xyz, scenePos0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #else
                fog(color, viewPos0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        }
    #endif
}
