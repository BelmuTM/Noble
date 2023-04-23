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
    vec3 refractions(vec3 viewPosition, vec3 scenePosition, Material material, inout vec3 hitPosition) {
        vec3 viewDirection = normalize(viewPosition);

        vec3 n1 = vec3(airIOR), n2 = material.N;
        if(isEyeInWater == 1) {
            n1 = vec3(1.333);
            n2 = vec3(airIOR);
        }

        vec3 refracted = refract(viewDirection, material.normal, n1.r / n2.r);
        bool hit       = raytrace(depthtex1, viewPosition, refracted, REFRACT_STEPS, randF(), hitPosition);
        
        if(saturate(hitPosition.xy) != hitPosition.xy || !hit && texture(depthtex1, hitPosition.xy).r < 1.0 || isHand(hitPosition.xy)) {
            hitPosition.xy = texCoords;
        }

        vec3 fresnel  = fresnelDielectric(dot(material.normal, -viewDirection), n1, n2);
        vec3 hitColor = texture(DEFERRED_BUFFER, hitPosition.xy).rgb;

        float distThroughMedium = clamp(distance(viewToScene(screenToView(hitPosition)), scenePosition), EPS, 5.0);
        vec3  beer              = material.blockId == 1 ? vec3(1.0) : exp(-(1.0 - material.albedo) * distThroughMedium);

        return hitColor * (1.0 - fresnel) * beer;
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

    vec3 viewPosition0  = getViewPosition0(texCoords);
    vec3 viewPosition1  = getViewPosition1(texCoords);
    vec3 scenePosition0 = viewToScene(viewPosition0);
    vec3 scenePosition1 = viewToScene(viewPosition1);

    float VdotL = dot(normalize(scenePosition0), shadowLightVector);

    vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
    
    #if defined WORLD_OVERWORLD
        skyIlluminance    = texture(ILLUMINANCE_BUFFER, texCoords).rgb;
        directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
    #endif

    bool  sky      = isSky(texCoords);
    float skyLight = 0.0;

    if(!sky) {
        skyLight = getSkyLightFalloff(material.lightmap.y);

        if(viewPosition0.z != viewPosition1.z) {
            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if GI == 0 && REFRACTIONS == 1
                if(material.F0 > EPS) {
                    color          = refractions(viewPosition0, scenePosition1, material, coords);
                    scenePosition1 = viewToScene(getViewPosition1(coords.xy));
                }
            #endif

            //////////////////////////////////////////////////////////
            /*---------------- FRONT TO BACK FOG -------------------*/
            //////////////////////////////////////////////////////////

            #if defined WORLD_OVERWORLD
                if(isEyeInWater != 1 && material.blockId == 1) {
                    #if WATER_FOG == 0
                        waterFog(color, scenePosition0, scenePosition1, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #else
                        bool skyTranslucents = texture(depthtex1, coords.xy).r == 1.0;
                        volumetricWaterFog(color, scenePosition0, scenePosition1, VdotL, directIlluminance, skyIlluminance, skyLight, skyTranslucents);
                    #endif
                } else {
                    #if AIR_FOG == 1
                        volumetricFog(color, scenePosition0, scenePosition1, viewPosition0, VdotL, directIlluminance, skyIlluminance, skyLight);
                    #elif AIR_FOG == 2
                        fog(color, viewPosition0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
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
                    visibility *= getCloudsShadows(scenePosition0);
                #endif

                color += computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
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
                waterFog(color, gbufferModelViewInverse[3].xyz, scenePosition0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #else
                volumetricWaterFog(color, gbufferModelViewInverse[3].xyz, scenePosition0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        } else {
            #if AIR_FOG == 1
                volumetricFog(color, gbufferModelViewInverse[3].xyz, scenePosition0, viewPosition0, VdotL, directIlluminance, skyIlluminance, skyLight);
            #elif AIR_FOG == 2
                fog(color, viewPosition0, VdotL, directIlluminance, skyIlluminance, skyLight, sky);
            #endif
        }
    #endif
}
