/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 13 */

layout (location = 0) out vec3 lighting;

in vec2 textureCoords;
in vec2 vertexCoords;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/utility/phase.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadowmap.glsl"

#include "/include/utility/sampling.glsl"

#if REFRACTIONS == 1
    #include "/include/fragment/refractions.glsl"
#endif

void main() {
    vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	if(saturate(fragCoords) != fragCoords) { discard; return; }

    lighting = vec3(0.0);

    vec3 coords = vec3(vertexCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

    float depth = texture(depthtex0, vertexCoords).r;

    sampler2D depthTex1 = depthtex1;

    mat4 projection        = gbufferProjection;
    mat4 projectionInverse = gbufferProjectionInverse;

    #if defined DISTANT_HORIZONS
        if(depth >= 1.0) {
            depth = texture(dhDepthTex0, vertexCoords).r;

            depthTex1 = dhDepthTex1;
                    
            projection        = dhProjection;
            projectionInverse = dhProjectionInverse;
        }
    #endif

    if(depth != 1.0) {
        Material material = getMaterial(vertexCoords);

        if(material.F0 * maxFloat8 <= 229.5) {
            lighting = texture(DEFERRED_BUFFER, vertexCoords).rgb;
        }

        vec3 viewPosition0 = screenToView(vec3(textureCoords, material.depth0), projectionInverse, true);
        vec3 viewPosition1 = screenToView(vec3(textureCoords, material.depth1), projectionInverse, true);

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
                lighting = computeRefractions(depthTex1, projection, viewPosition0, material, coords);
            }
        #endif

        //////////////////////////////////////////////////////////
        /*-------------------- REFLECTIONS ---------------------*/
        //////////////////////////////////////////////////////////

        #if SPECULAR == 1
            vec3 visibility = texture(SHADOWMAP_BUFFER, max(coords.xy, texelSize)).rgb;

            #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                visibility *= getCloudsShadows(viewToScene(viewPosition0));
            #endif

            if(visibility != vec3(0.0)) {
                sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowVec) * directIlluminance * saturate(visibility);
            }
        #endif

        #if REFLECTIONS > 0
            envSpecular = texture(REFLECTIONS_BUFFER, vertexCoords).rgb;
        #endif
    } else {
        lighting = texture(DEFERRED_BUFFER, vertexCoords).rgb;
    }

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
        lighting += sunSpecular;
        lighting += envSpecular;
        lighting  = lighting * transmittance + scattering;
    } else {
        lighting  = lighting * transmittance + scattering;
        lighting += sunSpecular;
        lighting += envSpecular;
    }
}
