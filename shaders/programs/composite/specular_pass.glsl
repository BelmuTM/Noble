/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

in vec2 textureCoords;
in vec2 vertexCoords;

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

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
        bool hit           = raytrace(depthtex1, viewPosition, refracted, 256, randF(), hitPosition);
        
        if(saturate(hitPosition.xy) != hitPosition.xy || !hit && texture(depthtex1, hitPosition.xy).r != 1.0 || isHand(hitPosition.xy * RENDER_SCALE)) {
            hitPosition.xy = textureCoords;
        }

        hitPosition.xy *= RENDER_SCALE;

        vec3 fresnel      = fresnelDielectric(dot(material.normal, -viewDirection), n1, n2);
        vec3 sampledColor = texture(DEFERRED_BUFFER, hitPosition.xy).rgb;

        float density     = material.blockId == NETHER_PORTAL_ID ? 3.0 : clamp(distance(viewToScene(screenToView(hitPosition)), scenePosition), EPS, 5.0);
        vec3  attenuation = material.blockId == WATER_ID         ? vec3(1.0) : exp(-(1.0 - material.albedo) * density);

        vec3 blocklightColor = getBlockLightColor(material);
        vec3 emissiveness    = material.emission * blocklightColor;

        return (sampledColor * (1.0 - fresnel) * attenuation) + (emissiveness * material.albedo);
    }
#endif

void main() {

    #if GI == 1
        //////////////////////////////////////////////////////////
        /*---------------- GLOBAL ILLUMINATION -----------------*/
        //////////////////////////////////////////////////////////

        vec2 scaledUv = vertexCoords * GI_SCALE;
        color = texture(DEFERRED_BUFFER, scaledUv).rgb;

        vec3 direct   = texture(DIRECT_BUFFER  , scaledUv).rgb;
        vec3 indirect = texture(INDIRECT_BUFFER, scaledUv).rgb;
        
        color = direct + (indirect * color);
    #endif

    vec3 coords = vec3(vertexCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

    #if GI == 0
        color = texture(DEFERRED_BUFFER, vertexCoords).rgb;

        if(!isSky(vertexCoords)) {
            Material material = getMaterial(vertexCoords);

            float depth0        = texture(depthtex0, vertexCoords).r;
            vec3  viewPosition0 = screenToView(vec3(textureCoords, depth0));

            float depth1        = texture(depthtex1, vertexCoords).r;
            vec3  viewPosition1 = screenToView(vec3(textureCoords, depth1));

            vec3 directIlluminance = vec3(0.0);
    
            #if defined WORLD_OVERWORLD || defined WORLD_END
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

                #if defined WORLD_OVERWORLD && defined SUNLIGHT_LEAKING_FIX
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

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    visibility *= getCloudsShadows(viewToScene(viewPosition0));
                #endif

                sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
            #endif

            #if REFLECTIONS == 1
                envSpecular = logLuvDecode(texture(REFLECTIONS_BUFFER, vertexCoords));
            #endif
        }
    #endif

    vec3 scattering    = vec3(0.0);
    vec3 transmittance = vec3(0.0);

    const int filterSize = 2;

    for(int x = -filterSize; x <= filterSize; x++) {
        for(int y = -filterSize; y <= filterSize; y++) {
            float weight = gaussianDistribution2D(vec2(x, y), 3.0);
            
            scattering    += logLuvDecode(texture(SCATTERING_BUFFER,    coords.xy + vec2(x, y) * pixelSize)) * weight;
            transmittance += logLuvDecode(texture(TRANSMITTANCE_BUFFER, coords.xy + vec2(x, y) * pixelSize)) * weight;
        }
    }
    
    if(isEyeInWater == 1) {
        color += sunSpecular;
        color  = color * transmittance + scattering;
    } else {
        color  = color * transmittance + scattering;
        color += sunSpecular;
    }
    
    color += envSpecular;
}
