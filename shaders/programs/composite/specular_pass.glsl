/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

in vec2 textureCoords;
in vec2 vertexCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/utility/phase.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/utility/sampling.glsl"

#if REFRACTIONS == 1
    #include "/include/fragment/refractions.glsl"
#endif

void main() {
    vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	if(saturate(fragCoords) != fragCoords) { discard; return; }

    #if GI == 1
        //////////////////////////////////////////////////////////
        /*---------------- GLOBAL ILLUMINATION -----------------*/
        //////////////////////////////////////////////////////////

        uvec2 packedFirstBounceData = texture(GI_DATA_BUFFER, vertexCoords).rg;

        vec3 direct   = logLuvDecode(unpackUnormArb(packedFirstBounceData[0], uvec4(8)));
        vec3 indirect = logLuvDecode(unpackUnormArb(packedFirstBounceData[1], uvec4(8)));

        #if GI_FILTER == 1
            vec3 radiance = texture(MAIN_BUFFER, vertexCoords).rgb;
        #else
            vec3 radiance = texture(LIGHTING_BUFFER, vertexCoords).rgb;
        #endif
        
        color = direct + indirect * radiance;
    #endif

    vec3 coords = vec3(vertexCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

    #if GI == 0
        color = texture(LIGHTING_BUFFER, vertexCoords).rgb;

        if(!isSky(vertexCoords)) {
            Material material = getMaterial(vertexCoords);

            vec3 viewPosition0  = getViewPosition0(textureCoords);
            vec3 viewPosition1  = getViewPosition1(textureCoords);

            vec3 directIlluminance = vec3(0.0);
    
            #if defined WORLD_OVERWORLD || defined WORLD_END
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

                #if defined WORLD_OVERWORLD && defined SUNLIGHT_LEAKING_FIX
                    directIlluminance *= float(material.lightmap.y > EPS || isEyeInWater == 1);
                #endif
            #endif

            //////////////////////////////////////////////////////////
            /*-------------------- REFRACTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if REFRACTIONS == 1
                if(viewPosition0.z != viewPosition1.z && material.F0 > EPS) {
                    color = computeRefractions(viewPosition0, material, coords);
                }
            #endif

            //////////////////////////////////////////////////////////
            /*-------------------- REFLECTIONS ---------------------*/
            //////////////////////////////////////////////////////////

            #if SPECULAR == 1
                vec3 visibility = texture(SHADOWMAP_BUFFER, coords.xy).rgb;

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    visibility *= getCloudsShadows(viewToScene(viewPosition0));
                #endif

                if(visibility != vec3(0.0)) {
                    sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
                }
            #endif

            #if REFLECTIONS == 1
                envSpecular = logLuvDecode(texture(REFLECTIONS_BUFFER, vertexCoords));
            #endif
        }
    #endif

    vec3 scattering    = vec3(0.0);
    vec3 transmittance = vec3(0.0);

    const int filterSize = 1;

    for(int x = -filterSize; x <= filterSize; x++) {
        for(int y = -filterSize; y <= filterSize; y++) {
            float weight = gaussianDistribution2D(vec2(x, y), 1.0);

            uvec2 packedFog = texture(FOG_BUFFER, coords.xy + vec2(x, y) * texelSize).rg;
            
            scattering    += logLuvDecode(unpackUnormArb(packedFog[0], uvec4(8))) * weight;
            transmittance += logLuvDecode(unpackUnormArb(packedFog[1], uvec4(8))) * weight;
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

    vec4 basic = texture(RASTER_BUFFER, vertexCoords);
         color = mix(color, basic.rgb, basic.a * float(isHand(vertexCoords)));
}
