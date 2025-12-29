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

const float invShadowMapResolution = 1.0 / shadowMapResolution;

#if CONTACT_SHADOWS == 1

    float traceContactShadows(
        sampler2D depthTexture,
        mat4 projection,
        mat4 projectionInverse,
        vec3 viewPosition,
        float scale,
        out float subsurfaceDepth
    ) {
        float jitter = randF();

        // DDA setup (McGuire & Mara, 2014)
        vec3 rayPosition;
        vec3 rayDirection;
        rayPosition   = viewToScreen(viewPosition, projection, true);
        rayDirection  = viewPosition + abs(viewPosition.z) * shadowLightVector;
        rayDirection  = viewToScreen(rayDirection, projection, true) - rayPosition;
        rayDirection *= minOf((step(0.0, rayDirection) - rayPosition) / rayDirection);
        
        vec2 resolution = viewSize * scale;

        rayPosition.xy  *= resolution;
        rayDirection.xy *= resolution;

        vec3 startPosition = rayPosition;

        // Normalise the DDA ray step to walk a fixed amount of pixels per step
        rayDirection /= maxOf(abs(rayDirection.xy));
        // Scale it to the stride (in pixels)
        rayDirection *= float(CONTACT_SHADOWS_STRIDE);

        float initialDepth = rayPosition.z;

        // Jitter the first step
        rayPosition += rayDirection * jitter;

        bool intersected = false;

        for (int i = 0; i < CONTACT_SHADOWS_STEPS; i++) {
            float depth = texelFetch(depthTexture, ivec2(rayPosition.xy), 0).r;

            float linearDepth    = linearizeDepth(depth        , near, far);
            float linearRayDepth = linearizeDepth(rayPosition.z, near, far);

            float relativeGap = abs(linearRayDepth - linearDepth) / linearRayDepth;

            // Check if the ray and the fragment are near enough for contact shadows
            if (relativeGap < 0.025) {
                float maxZ  = rayPosition.z;
                float minZ  = rayPosition.z - float(CONTACT_SHADOWS_STRIDE) / linearDepth;
                
                // Intersection check, avoid player hand fragments
                if(depth < rayPosition.z && maxZ >= depth && minZ <= depth && depth >= handDepth){
                    intersected = true;
                    break;
                } 
            }

            rayPosition += rayDirection;
        }

        if (intersected) {
            subsurfaceDepth = distance(startPosition, rayPosition);
        }

        return float(!intersected);
    }

#endif

vec3 worldToShadow(vec3 worldPosition) {
    return projectOrthogonal(shadowProjection, transform(shadowModelView, worldPosition));
}

float visibility(sampler2D tex, vec3 samplePosition) {
    return step(samplePosition.z, texelFetch(tex, ivec2(samplePosition.xy * shadowMapResolution), 0).r);
}

vec3 getShadowColor(vec3 samplePosition) {
    if (saturate(samplePosition) != samplePosition) return vec3(1.0);

    float shadowDepth0 = visibility(shadowtex0, samplePosition);
    float shadowDepth1 = visibility(shadowtex1, samplePosition);
    vec4  shadowColor  = texelFetch(shadowcolor0, ivec2(samplePosition.xy * shadowMapResolution), 0);
    
    #if TONEMAP == ACES
        shadowColor.rgb = srgbToAP1Albedo(shadowColor.rgb);
    #else
        shadowColor.rgb = srgbToLinear(shadowColor.rgb);
    #endif

    return mix(vec3(shadowDepth0), shadowColor.rgb * (1.0 - shadowColor.a), saturate(shadowDepth1 - shadowDepth0));
}

float rng = interleavedGradientNoise(gl_FragCoord.xy);

#if SHADOWS > 0

    #if SHADOWS == 1

        float findBlockerDepth(vec2 shadowCoords, float shadowDepth, out float subsurfaceDepth) {
            float blockerDepthSum    = 0.0;
            float subsurfaceDepthSum = 0.0;

            float weightSum = 0.0;

            for (int i = 0; i < BLOCKER_SEARCH_SAMPLES; i++) {
                vec2 offset       = BLOCKER_SEARCH_RADIUS * sampleDisk(i, BLOCKER_SEARCH_SAMPLES, rng) * invShadowMapResolution;
                vec2 sampleCoords = distortShadowSpace(shadowCoords + offset) * 0.5 + 0.5;
                
                if (saturate(sampleCoords) != sampleCoords) return -1.0;

                float depth  = texelFetch(shadowtex0, ivec2(sampleCoords * shadowMapResolution), 0).r;
                float weight = step(depth, shadowDepth);

                blockerDepthSum += depth * weight;
                weightSum       += weight;

                subsurfaceDepthSum += max0(shadowDepth - depth);
            }
            
            // Subsurface depth calculation from sixthsurge
            // -shadowProjectionInverse[2].z helps us convert the depth to a meters scale
            subsurfaceDepth = (-shadowProjectionInverse[2].z * subsurfaceDepthSum) / (SHADOW_DEPTH_STRETCH * BLOCKER_SEARCH_SAMPLES);

            return weightSum == 0.0 ? -1.0 : blockerDepthSum / weightSum;
        }

    #endif

    vec3 PCF(vec3 shadowPosition, float penumbraSize, vec3 selfIntersectionBias) {
        if (penumbraSize < EPS) {
            return getShadowColor(distortShadowSpace(shadowPosition) * 0.5 + 0.5 - selfIntersectionBias);
        }

        vec3 shadowResult = vec3(0.0); vec2 offset = vec2(0.0);

        for (int i = 0; i < SHADOW_SAMPLES; i++) {
            #if SHADOWS != 3
                offset = sampleDisk(i, SHADOW_SAMPLES, rng) * penumbraSize * invShadowMapResolution;
            #endif

            vec3 samplePosition = distortShadowSpace(shadowPosition + vec3(offset, 0.0)) * 0.5 + 0.5;

            shadowResult += getShadowColor(samplePosition - selfIntersectionBias);
        }
        return shadowResult * rcp(SHADOW_SAMPLES);
    }

#endif

vec3 calculateShadowMapping(vec3 scenePosition, vec3 geometricNormal, float depth, out float subsurfaceDepth) {
    #if SHADOWS > 0
        vec3  shadowPosition = worldToShadow(scenePosition);
        float NdotL          = dot(geometricNormal, shadowLightVectorWorld);

        // Shadow bias implementation from Emin and concept from gri573
        float biasAdjust = log2(max(4.0, shadowDistance - shadowMapResolution * 0.125)) * 0.35;
        shadowPosition  += mat3(shadowProjection) * (mat3(shadowModelView) * geometricNormal) * getDistortionFactor(shadowPosition.xy) * biasAdjust;
        shadowPosition  *= 1.0002;

        float penumbraSize = NORMAL_SHADOW_PENUMBRA;

        subsurfaceDepth = 0.0;

        vec3 selfIntersectionBias = vec3(0.0);

        if (depth < handDepth) selfIntersectionBias = vec3(0.0, 0.0, 1e-3);

        #if SHADOWS == 1
            vec3 shadowPosDistort = distortShadowSpace(shadowPosition) * 0.5 + 0.5;

            if (saturate(shadowPosDistort) != shadowPosDistort) return vec3(1.0);

            float avgBlockerDepth = findBlockerDepth(shadowPosition.xy, shadowPosDistort.z, subsurfaceDepth);

            if (avgBlockerDepth < 0.0) {
                return vec3(-1.0);
            }

            if (NdotL < EPS) return vec3(0.0);

            penumbraSize = max(MIN_SHADOW_PENUMBRA, LIGHT_SIZE * (shadowPosDistort.z - avgBlockerDepth) / avgBlockerDepth);
        #endif

        return PCF(shadowPosition, penumbraSize, selfIntersectionBias);
    #else
        return vec3(1.0);
    #endif
}
