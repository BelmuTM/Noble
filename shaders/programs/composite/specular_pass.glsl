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

#include "/include/utility/sampling.glsl"

//////////////////////////////////////////////////////////
/*--------------------- REFRACTIONS --------------------*/
//////////////////////////////////////////////////////////

#if REFRACTIONS == 1
    vec3 computeRefractions(vec3 viewPosition, vec3 scenePosition, Material material, inout vec3 hitPosition) {
        vec3 n1 = vec3(airIOR), n2 = material.N;
        if(isEyeInWater == 1) {
            n1 = vec3(1.333);
            n2 = vec3(airIOR);
        }

        vec3 viewDirection = normalize(viewPosition);
        vec3 refracted     = refract(viewDirection, material.normal, n1.r / n2.r);
        bool hit           = raytrace(depthtex1, viewPosition, refracted, REFRACT_STEPS, randF(), hitPosition);
        
        if(saturate(hitPosition.xy) != hitPosition.xy || !hit && texture(depthtex1, hitPosition.xy).r != 1.0 || isHand(hitPosition.xy)) {
            hitPosition.xy = textureCoords;
        }

        vec3 fresnel  = fresnelDielectric(dot(material.normal, -viewDirection), n1, n2);
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
    #endif

    vec3 coords = vec3(textureCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), specular = vec3(0.0);

    #if GI == 0
        color = texture(DEFERRED_BUFFER, textureCoords).rgb;

        if(!isSky(textureCoords)) {
            Material material = getMaterial(textureCoords);

            vec3 viewPosition0 = getViewPosition0(textureCoords);
            vec3 viewPosition1 = getViewPosition1(textureCoords);

            vec3 directIlluminance = vec3(0.0);
    
            #if defined WORLD_OVERWORLD
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

                #if defined SUNLIGHT_LEAKING_FIX
                    directIlluminance *= float(material.lightmap.y > EPS || isEyeInWater == 1);
                #endif
            #endif

            if(viewPosition0.z != viewPosition1.z) {
                //////////////////////////////////////////////////////////
                /*-------------------- REFRACTIONS ---------------------*/
                //////////////////////////////////////////////////////////

                #if REFRACTIONS == 1
                    if(material.F0 > EPS) {
                        color = computeRefractions(viewPosition0, viewToScene(viewPosition1), material, coords);
                    }
                #endif
            }

            //////////////////////////////////////////////////////////
            /*-------------------- REFLECTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if SPECULAR == 1
                vec3 visibility = viewPosition0.z == viewPosition1.z ? texture(SHADOWMAP_BUFFER, coords.xy).rgb : vec3(1.0);

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && PRIMARY_CLOUDS == 1
                    visibility *= getCloudsShadows(scenePosition0);
                #endif

                sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
            #endif

            #if REFLECTIONS == 1
                specular = texture(REFLECTIONS_BUFFER, textureCoords).rgb;
            #endif
        }
    #endif

    #if defined WORLD_OVERWORLD
        vec3 scattering    = vec3(0.0);
        vec3 transmittance = vec3(0.0);

        const int filterSize = 2;

        for(int x = -filterSize; x <= filterSize; x++) {
            for(int y = -filterSize; y <= filterSize; y++) {
                float weight = gaussianDistribution2D(vec2(x, y), 3.0);
            
                scattering    += texture(colortex12, coords.xy + vec2(x, y) * pixelSize).rgb * weight;
                transmittance += texture(colortex13, coords.xy + vec2(x, y) * pixelSize).rgb * weight;
            }
        }
    #else
        vec3 scattering    = texture(colortex12, coords.xy).rgb;
        vec3 transmittance = texture(colortex13, coords.xy).rgb;
    #endif

    color += sunSpecular;
    color  = color * transmittance + scattering;
    color += specular;
}