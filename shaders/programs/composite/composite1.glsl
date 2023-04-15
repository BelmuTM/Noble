/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

#include "/include/common.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/atmospherics/celestial.glsl"
#include "/include/atmospherics/fog.glsl"

//////////////////////////////////////////////////////////
/*--------------------- REFRACTIONS --------------------*/
//////////////////////////////////////////////////////////

#if REFRACTIONS == 1
    vec3 refractions(vec3 viewPos, vec3 scenePos, Material material, inout vec3 hitPos) {
        vec3 viewDir = normalize(viewPos);

        vec3 n1 = vec3(airIOR), n2 = material.N;
        if(isEyeInWater == 1) { n1 = vec3(1.333); n2 = vec3(airIOR); }

        vec3 refracted = refract(viewDir, material.normal, n1.r / n2.r);
        bool hit       = raytrace(depthtex1, viewPos, refracted, REFRACT_STEPS, randF(), hitPos);
        if(!hit || isHand(hitPos.xy)) { hitPos.xy = texCoords; }

        vec3 fresnel  = fresnelDielectric(dot(material.normal, -viewDir), n1, n2);
        vec3 hitColor = texture(DEFERRED_BUFFER, hitPos.xy).rgb;

        float distThroughMedium = clamp(distance(viewToScene(screenToView(hitPos)), scenePos), EPS, 5.0);
        vec3  beer              = material.blockId == 1 ? vec3(1.0) : exp(-(1.0 - material.albedo) * distThroughMedium);

        return max0(hitColor * (1.0 - fresnel) * beer);
    }
#endif

void main() {

    #if GI == 1
        //////////////////////////////////////////////////////////
        /*---------------- GLOBAL ILLUMINATION -----------------*/
        //////////////////////////////////////////////////////////

        vec2 scaledUv = texCoords * GI_SCALE;
        color = texture(DEFERRED_BUFFER, scaledUv).rgb;

        vec3 direct   = texture(DIRECT_BUFFER,  scaledUv).rgb;
        vec3 indirect = texture(INDIRECT_BUFFER, scaledUv).rgb;
        
        color = direct + (indirect * color);
    #else
        color = texture(DEFERRED_BUFFER, texCoords).rgb;
    #endif

    Material material = getMaterial(texCoords);

    vec3 coords = vec3(texCoords, 0.0);

    vec3 viewPos0  = getViewPos0(texCoords);
    vec3 viewPos1  = getViewPos1(texCoords);
    vec3 scenePos0 = viewToScene(viewPos0);
    vec3 scenePos1 = viewToScene(viewPos1);

    float VdotL = dot(normalize(scenePos0), shadowLightVector);

    vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
    
    #if defined WORLD_OVERWORLD
        skyIlluminance    = texture(ILLUMINANCE_BUFFER,  texCoords).rgb * RCP_PI;
        directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
    #endif

    bool  sky      = isSky(texCoords);
    float skyLight = 0.0;

    if(!sky) {
        skyLight = getSkyLightFalloff(material.lightmap.y);

        if(viewPos0.z != viewPos1.z) {
            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if GI == 0 && REFRACTIONS == 1
                if(material.F0 > EPS) {
                    color     = refractions(viewPos0, scenePos1, material, coords);
                    scenePos1 = viewToScene(getViewPos1(coords.xy));
                }
            #endif

            //////////////////////////////////////////////////////////
            /*---------------- FRONT TO BACK FOG -------------------*/
            //////////////////////////////////////////////////////////

            #if defined WORLD_OVERWORLD
                if(isEyeInWater != 1 && material.blockId == 1) {
                    #if WATER_FOG == 0
                        waterFog(color, scenePos0, scenePos1, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #else
                        bool skyTranslucents = texture(depthtex1, coords.xy).r == 1.0;
                        volumetricWaterFog(color, scenePos0, scenePos1, VdotL, directIlluminance, skyIlluminance, skyLight, skyTranslucents);
                    #endif
                } else {
                    #if AIR_FOG == 1
                        volumetricFog(color, scenePos0, scenePos1, viewPos0, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #elif AIR_FOG == 2
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
                vec3 visibility = texture(SHADOWMAP_BUFFER, coords.xy).rgb;
                #if defined SUNLIGHT_LEAKING_FIX
                    visibility *= float(material.lightmap.y > EPS);
                #endif

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                    visibility *= getCloudsShadows(scenePos0);
                #endif

                color += computeSpecular(material, -normalize(viewPos0), shadowVec) * directIlluminance * clamp01(visibility);
            #endif

            #if REFLECTIONS == 1
                color += texture(REFLECTIONS_BUFFER, texCoords).rgb;
            #endif
        #endif
    } else {
        skyLight = 1.0;
    }

    //////////////////////////////////////////////////////////
    /*------------------ EYE TO FRONT FOG ------------------*/
    //////////////////////////////////////////////////////////

    #if defined WORLD_OVERWORLD
        if(isEyeInWater == 1) {
            #if WATER_FOG == 0
                waterFog(color, gbufferModelViewInverse[3].xyz, scenePos0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #else
                volumetricWaterFog(color, gbufferModelViewInverse[3].xyz, scenePos0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        } else {
            #if AIR_FOG == 1
                volumetricFog(color, gbufferModelViewInverse[3].xyz, scenePos0, viewPos0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #elif AIR_FOG == 2
                fog(color, viewPos0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        }
    #endif
}
