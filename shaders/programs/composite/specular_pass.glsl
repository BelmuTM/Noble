/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

/* RENDERTARGETS: 13 */

layout (location = 0) out vec3 lighting;

in vec2 textureCoords;
in vec2 vertexCoords;

uniform usampler2D colortex11;

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/rng.glsl"

#include "/include/atmospherics/constants.glsl"

#include "/include/utility/phase.glsl"

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/raytracer.glsl"
#include "/include/fragment/shadows.glsl"

#include "/include/utility/sampling.glsl"

#if REFRACTIONS == 1
    #include "/include/fragment/refractions.glsl"
#endif

#include "/include/post/exposure.glsl"

#if TAA == 1 && DOF == 0
    #include "/include/post/grading.glsl"
#endif

void main() {
    vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	if(saturate(fragCoords) != fragCoords) { discard; return; }

    lighting = vec3(0.0);

    vec3 coords = vec3(vertexCoords, 0.0);

    vec3 sunSpecular = vec3(0.0), envSpecular = vec3(0.0);

    float depth = texture(depthtex0, vertexCoords).r;

    mat4 projection        = gbufferProjection;
    mat4 projectionInverse = gbufferProjectionInverse;

    float nearPlane = near;
    float farPlane  = far;

    #if defined DISTANT_HORIZONS
        if(depth >= 1.0) {
            depth = texture(dhDepthTex0, vertexCoords).r;
                    
            projection        = dhProjection;
            projectionInverse = dhProjectionInverse;
        
            nearPlane = dhNearPlane;
            farPlane  = dhFarPlane;
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
                lighting = computeRefractions(projection, viewPosition0, viewPosition1, material, coords);
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

            if(material.id == WATER_ID) visibility = material.albedo;

            if(visibility != vec3(0.0)) {
                sunSpecular = computeSpecular(material, -normalize(viewPosition0), shadowVec) * visibility * directIlluminance;
            }    
        #endif

        #if REFLECTIONS > 0
            envSpecular = texture(REFLECTIONS_BUFFER, vertexCoords).rgb;
        #endif
    } else {
        lighting = texture(DEFERRED_BUFFER, vertexCoords).rgb;
    }

    //////////////////////////////////////////////////////////
    /*--------------------- FOG FILTER ---------------------*/
    //////////////////////////////////////////////////////////

    vec3 scattering    = vec3(0.0);
    vec3 transmittance = vec3(0.0);

    float totalWeight = 0.0;

    const int filterSize = 2;
    for(int x = -filterSize; x <= filterSize; x++) {
        for(int y = -filterSize; y <= filterSize; y++) {
            vec2  sampleCoords = coords.xy + vec2(x, y) * texelSize * 2.0;
            uvec2 packedFog    = texture(FOG_BUFFER, sampleCoords).rg;

            float weight = gaussianDistribution2D(vec2(x, y), 1.0);

            float linearDepth       = linearizeDepth(texture(depthtex1, coords.xy).r   , nearPlane, farPlane);
            float linearSampleDepth = linearizeDepth(texture(depthtex1, sampleCoords).r, nearPlane, farPlane);

            weight *= step(abs(linearDepth - linearSampleDepth) / max(linearDepth, linearSampleDepth), 0.1);
            
            scattering    += logLuvDecode(unpackUnormArb(packedFog[0], uvec4(8))) * weight;
            transmittance += logLuvDecode(unpackUnormArb(packedFog[1], uvec4(8))) * weight;

            totalWeight += weight;
        }
    }
    scattering    /= totalWeight;
    transmittance /= totalWeight;
    
    if(isEyeInWater == 1) {
        lighting += sunSpecular;
        lighting += envSpecular;
        lighting  = lighting * transmittance + scattering;
    } else {
        lighting  = lighting * transmittance + scattering;
        lighting += sunSpecular;
        lighting += envSpecular;
    }

    //////////////////////////////////////////////////////////
    /*------------------ ALPHA BLENDING --------------------*/
    //////////////////////////////////////////////////////////

    vec4 basic = texture(GBUFFERS_BASIC_BUFFER, vertexCoords);

    bool isEnchantmentGlint = basic.a == 0.0;
    bool isDamageOverlay    = basic.a > 0.0 && basic.a < 1e-2;

    bool isHand = depth < handDepth;

    float exposure = 1.0;

    if(isEnchantmentGlint || (!isEnchantmentGlint && !isDamageOverlay))
        exposure = computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);

    if(isEnchantmentGlint) {
        lighting.rgb += basic.rgb / exposure;
    } else if(isDamageOverlay) {
        if(!isHand) lighting.rgb = 2.0 * basic.rgb * lighting.rgb;
    } else {
        if(!isHand) lighting.rgb = mix(lighting.rgb, basic.rgb / exposure, basic.a);
    }

    //////////////////////////////////////////////////////////
    /*---------------- TAA PRE-TONEMAPPING -----------------*/
    //////////////////////////////////////////////////////////

    #if TAA == 1 && DOF == 0
        lighting = lighting * computeExposure(texelFetch(HISTORY_BUFFER, ivec2(0), 0).a);
        lighting = reinhard(lighting);
    #endif
}
