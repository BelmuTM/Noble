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
    vec3 computeRefractions(vec3 viewPosition, vec3 scenePosition, Material material, inout vec3 hitPosition) {
        vec3 viewDirection = normalize(viewPosition);

        vec3 n1 = vec3(airIOR), n2 = material.N;
        if(isEyeInWater == 1) {
            n1 = vec3(1.333);
            n2 = vec3(airIOR);
        }

        vec3 refracted = refract(viewDirection, material.normal, n1.r / n2.r);
        bool hit       = raytrace(depthtex1, viewPosition, refracted, REFRACT_STEPS, randF(), hitPosition);
        
        if(saturate(hitPosition.xy) != hitPosition.xy || !hit && texture(depthtex1, hitPosition.xy).r != 1.0 || isHand(hitPosition.xy)) {
            hitPosition.xy = textureCoords;
        }

        vec3 fresnel  = fresnelDielectricConductor(dot(material.normal, -viewDirection), material.N, material.K);
        vec3 hitColor = texture(DEFERRED_BUFFER, hitPosition.xy).rgb;

        float density     = clamp(distance(viewToScene(screenToView(hitPosition)), scenePosition), EPS, 5.0);
        vec3  attenuation = material.blockId == 1 ? vec3(1.0) : exp(-(1.0 - material.albedo) * density);

        return hitColor * (1.0 - fresnel) * attenuation;
    }
#endif

void main() {

    #if GI == 1
        //////////////////////////////////////////////////////////
        /*---------------- GLOBAL ILLUMINATION -----------------*/
        //////////////////////////////////////////////////////////

        vec2 scaledUv = textureCoords * GI_SCALE;
        color = texture(DEFERRED_BUFFER, scaledUv).rgb;

        vec3 direct   = texture(DIRECT_BUFFER  , scaledUv).rgb;
        vec3 indirect = texture(INDIRECT_BUFFER, scaledUv).rgb;
        
        color = direct + (indirect * color);
    #else
        color = texture(DEFERRED_BUFFER, textureCoords).rgb;
    #endif

    Material material = getMaterial(textureCoords);

    vec3 coords = vec3(textureCoords, 0.0);

    vec3 viewPosition0  = getViewPosition0(textureCoords);
    vec3 viewPosition1  = getViewPosition1(textureCoords);
    vec3 scenePosition0 = viewToScene(viewPosition0);
    vec3 scenePosition1 = viewToScene(viewPosition1);

    float VdotL = dot(normalize(scenePosition0), shadowLightVector);

    vec3 skyIlluminance = vec3(0.0), directIlluminance = vec3(0.0);
    
    #if defined WORLD_OVERWORLD
        directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
        skyIlluminance    = texture(ILLUMINANCE_BUFFER, textureCoords).rgb;

        #if defined SUNLIGHT_LEAKING_FIX
            directIlluminance *= float(material.lightmap.y > EPS);
        #endif
    #endif

    bool  sky      = isSky(textureCoords);
    float skylight = 0.0;

    if(!sky) {
        skylight = getSkylightFalloff(material.lightmap.y);

        if(viewPosition0.z != viewPosition1.z) {
            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if GI == 0 && REFRACTIONS == 1
                if(material.F0 > EPS) {
                    color = computeRefractions(viewPosition0, scenePosition1, material, coords);
                    if(saturate(coords.xy) == coords.xy) viewToScene(getViewPosition1(coords.xy));
                }
            #endif

            //////////////////////////////////////////////////////////
            /*---------------- FRONT TO BACK FOG -------------------*/
            //////////////////////////////////////////////////////////

            #if defined WORLD_OVERWORLD
                if(isEyeInWater != 1 && material.blockId == 1) {
                    #if WATER_FOG == 0
                        waterFog(color, scenePosition0, scenePosition1, VdotL, directIlluminance, skyIlluminance, skylight);
                    #else
                        bool skyTranslucents = texture(depthtex1, coords.xy).r == 1.0;
                        computeVolumetricWaterFog(color, scenePosition0, scenePosition1, VdotL, directIlluminance, skyIlluminance, skylight, skyTranslucents);
                    #endif
                } else {
                    #if AIR_FOG == 1
                        volumetricFog(color, scenePosition0, scenePosition1, viewPosition0, VdotL, directIlluminance, skyIlluminance, skylight);
                    #elif AIR_FOG == 2
                        fog(color, viewPosition0, VdotL, directIlluminance, skyIlluminance, skylight, sky);
                    #endif
                }
            #endif
        }
    
        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0
            #if SPECULAR == 1
                vec3  shadowPosition = distortShadowSpace(worldToShadow(scenePosition0)) * 0.5 + 0.5;
                float shadowDepth0   = texture(shadowtex0, shadowPosition.xy).r;
                float shadowDepth1   = texture(shadowtex1, shadowPosition.xy).r;

                vec3 visibility = shadowDepth0 == shadowDepth1 ? texture(SHADOWMAP_BUFFER, coords.xy).rgb : vec3(1.0);

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                    visibility *= getCloudsShadows(scenePosition0);
                #endif

                color += computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
            #endif

            #if REFLECTIONS == 1
                color += texture(REFLECTIONS_BUFFER, textureCoords).rgb;
            #endif
        #endif
    } else {
        skylight = 1.0;
    }

    //////////////////////////////////////////////////////////
    /*------------------ EYE TO FRONT FOG ------------------*/
    //////////////////////////////////////////////////////////

    #if defined WORLD_OVERWORLD
        if(isEyeInWater == 1) {
            #if WATER_FOG == 0
                waterFog(color, gbufferModelViewInverse[3].xyz, scenePosition0, VdotL, directIlluminance, skyIlluminance, skylight);
            #else
                computeVolumetricWaterFog(color, gbufferModelViewInverse[3].xyz, scenePosition0, VdotL, directIlluminance, skyIlluminance, skylight, sky);
            #endif
        } else {
            #if AIR_FOG == 1
                volumetricFog(color, gbufferModelViewInverse[3].xyz, scenePosition0, viewPosition0, VdotL, directIlluminance, skyIlluminance, skylight);
            #elif AIR_FOG == 2
                fog(color, viewPosition0, VdotL, directIlluminance, skyIlluminance, skylight, sky);
            #endif
        }
    #endif
}
