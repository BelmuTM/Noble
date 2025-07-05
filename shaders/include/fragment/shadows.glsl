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

vec3 worldToShadow(vec3 worldPosition) {
    return projectOrthogonal(shadowProjection, transform(shadowModelView, worldPosition));
}

float visibility(sampler2D tex, vec3 samplePos) {
    return step(samplePos.z, texelFetch(tex, ivec2(samplePos.xy * shadowMapResolution), 0).r);
}

vec3 getShadowColor(vec3 samplePos) {
    if (saturate(samplePos) != samplePos) return vec3(1.0);

    float shadowDepth0 = visibility(shadowtex0, samplePos);
    float shadowDepth1 = visibility(shadowtex1, samplePos);
    vec4  shadowColor  = texelFetch(shadowcolor0, ivec2(samplePos.xy * shadowMapResolution), 0);
    
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

            vec3 samplePos = distortShadowSpace(shadowPosition + vec3(offset, 0.0)) * 0.5 + 0.5;
            shadowResult  += getShadowColor(samplePos - selfIntersectionBias);
        }
        return shadowResult * rcp(SHADOW_SAMPLES);
    }

#endif

vec3 calculateShadowMapping(vec3 scenePosition, vec3 geometricNormal, float depth, out float subsurfaceDepth) {
    #if SHADOWS > 0
        vec3  shadowPosition = worldToShadow(scenePosition);
        float NdotL          = dot(geometricNormal, shadowLightVector);

        // Shadow bias implementation from Emin and concept from gri573
        float biasAdjust = log2(max(4.0, shadowDistance - shadowMapResolution * 0.125)) * 0.35;
        shadowPosition  += mat3(shadowProjection) * (mat3(shadowModelView) * geometricNormal) * getDistortionFactor(shadowPosition.xy) * biasAdjust;
        shadowPosition  *= 1.0002;

        float penumbraSize = NORMAL_SHADOW_PENUMBRA;

        subsurfaceDepth = 0.0;

        vec3 selfIntersectionBias = vec3(0.0);

        if (depth < handDepth) selfIntersectionBias = vec3(0.0, 0.0, 1e-3);

        #if SHADOWS == 1
            vec3  shadowPosDistort = distortShadowSpace(shadowPosition) * 0.5 + 0.5;
            float avgBlockerDepth  = findBlockerDepth(shadowPosition.xy, shadowPosDistort.z, subsurfaceDepth);

            if (avgBlockerDepth < EPS) {
                subsurfaceDepth = 1.0;
                //return vec3(-1.0);
            }

            if (NdotL < EPS) return vec3(0.0);

            penumbraSize = max(MIN_SHADOW_PENUMBRA, LIGHT_SIZE * (shadowPosDistort.z - avgBlockerDepth) / avgBlockerDepth);
        #endif

        return PCF(shadowPosition, penumbraSize, selfIntersectionBias);
    #else
        return vec3(1.0);
    #endif
}
