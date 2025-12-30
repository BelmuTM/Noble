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

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec2 vertexCoords;
    out vec3 directIlluminance;

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

        #if defined WORLD_OVERWORLD
            directIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0), 0).rgb;
        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 4,10 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 momentsOut;

    in vec2 textureCoords;
    in vec2 vertexCoords;
    in vec3 directIlluminance;

    #include "/include/utility/rng.glsl"

    #include "/include/atmospherics/constants.glsl"

    #include "/include/utility/phase.glsl"
    #include "/include/utility/sampling.glsl"

    #include "/include/fragment/brdf.glsl"

    #if GI == 1
        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/pathtracer.glsl"
    #endif

    #if RENDER_MODE == 0 && ATROUS_FILTER == 1
    
        float estimateSpatialVariance(sampler2D colorTex, vec2 moments) {
            float sum = moments.r, sqSum = moments.g, totalWeight = 1.0;

            const float waveletKernel[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);
            
            vec2 stepSize = texelSize;

            for (int x = -1; x <= 1; x++) {
                for (int y = -1; y <= 1; y++) {
                    if (x == 0 && y == 0) continue;

                    vec2 sampleCoords = textureCoords + vec2(x, y) * stepSize;
                    if (saturate(sampleCoords) != sampleCoords) continue;

                    float weight    = waveletKernel[abs(x)] * waveletKernel[abs(y)];
                    float luminance = luminance(texture(colorTex, sampleCoords).rgb);
                
                    sum   += luminance             * weight;
                    sqSum += luminance * luminance * weight;

                    totalWeight += weight;
                }
            }
            sum   /= totalWeight;
            sqSum /= totalWeight;
            return max0(sqSum - sum * sum);
        }

    #endif
    
    #if RENDER_MODE == 0 && TEMPORAL_ACCUMULATION == 1

        float cubic(float x) {
            x = abs(x);
            int segment = int(x);
            x = fract(x);

            switch (segment) {
                case 0:  return 1.0 + x * x * (3.0 * x - 5.0) * 0.5;
                case 1:  return x * (x * (2.0 - x) - 1.0) * 0.5;
                default: return 0.0;
            }
        }

        vec2 cubic(vec2 coords) {
            return vec2(cubic(coords.x), cubic(coords.y));
        }

        vec4 filterHistory(sampler2D colorTex, vec2 coords, vec3 normal, float depth, out bool rejectHistory) {
            vec2 resolution = floor(viewSize);

            coords = coords * resolution - 0.5;

            ivec2 fragCoords = ivec2(floor(coords));

            coords = fract(coords);

            vec4  history     = vec4(0.0);
            float totalWeight = 0.0;

            vec4 minColor = vec4(1e9), maxColor = vec4(-1e9);

            float centerLuminance = 0.0;
            float luminanceSum    = 0.0;

            for (int x = -1; x <= 2; x++) {
                for (int y = -1; y <= 2; y++) {
                    ivec2 sampleCoords = fragCoords + ivec2(x, y);

                    if (clamp(sampleCoords, ivec2(0), ivec2(resolution)) != sampleCoords) continue;

                    float sampleDepth = linearizeDepth(exp2(texelFetch(MOMENTS_BUFFER, sampleCoords, 0).r), near, far);
                    float depthWeight = pow(exp(-abs(sampleDepth - depth)), 8.0);

                    vec2 cubicWeights = cubic(abs(vec2(x, y) - coords));

                    float weight = saturate(cubicWeights.x * cubicWeights.y * depthWeight);

                    vec4 sampleColor = texelFetch(colorTex, sampleCoords, 0);

                    float sampleLuminance = luminance(sampleColor.rgb);

                    if (x == 0 && y == 0) centerLuminance = sampleLuminance;
                    else                  luminanceSum   += sampleLuminance * weight;

                    history     += sampleColor * weight;
                    totalWeight += weight;

                    minColor = min(minColor, sampleColor);
                    maxColor = max(maxColor, sampleColor);
                }
            }

            history = clamp(history / totalWeight, minColor, maxColor);

            bool fireflyRejection = distance(centerLuminance, luminanceSum / totalWeight) > 200.0;

            rejectHistory = totalWeight <= 1e-3;
            
            return history;
        }

    #endif

    void main() {
        color = vec4(0.0);

        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
        if (saturate(fragCoords) != fragCoords) { discard; return; }

        bool  modFragment = false;
        float depth       = texture(depthtex0, vertexCoords).r;

        mat4 projection         = gbufferProjection;
        mat4 projectionInverse  = gbufferProjectionInverse;
        mat4 projectionPrevious = gbufferPreviousProjection;

        float nearPlane = near;
        float farPlane  = far;

        #if defined CHUNK_LOADER_MOD_ENABLED
            if (depth >= 1.0) {
                modFragment = true;
                depth       = texture(modDepthTex0, vertexCoords).r;

                projection         = modProjection;
                projectionInverse  = modProjectionInverse;
                projectionPrevious = modProjectionPrevious;

                nearPlane = modNearPlane;
                farPlane  = modFarPlane;
            }
        #endif

        if (depth == 1.0) { discard; return; }

        vec3 viewPosition = screenToView(vec3(textureCoords, depth), projectionInverse, true);

        vec3 skyIlluminance = vec3(0.0);
        #if defined WORLD_OVERWORLD || defined WORLD_END
            skyIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(gl_FragCoord.xy), 0).rgb;
        #endif

        Material material = getMaterial(vertexCoords);

        #if AO > 0 && AO_FILTER == 1 && GI == 0 || GI == 1 && TEMPORAL_ACCUMULATION == 1

            vec3 prevPosition = vec3(vertexCoords, depth) + getVelocity(vec3(textureCoords, depth), projectionInverse, projectionPrevious) * RENDER_SCALE;
            vec4 history      = texture(DEFERRED_BUFFER, prevPosition.xy);

            color.a  = history.a;
            color.a *= float(clamp(prevPosition.xy, 0.0, RENDER_SCALE) == prevPosition.xy);
            color.a *= float(depth >= handDepth);

            momentsOut = texture(MOMENTS_BUFFER, prevPosition.xy);

            #if RENDER_MODE == 0
                float prevDepth = exp2(momentsOut.r);
                
                momentsOut.r = log2(prevPosition.z);

                float linearDepth     = linearizeDepth(prevPosition.z, nearPlane, farPlane);
                float linearPrevDepth = linearizeDepth(prevDepth     , nearPlane, farPlane);

                vec3 prevScenePosition = viewToScene(screenToView(prevPosition, projectionInverse, false));
                bool closeToCamera     = distance(gbufferModelViewInverse[3].xyz, prevScenePosition) > 1.1;

                float depthWeight = step(abs(linearDepth - linearPrevDepth) / max(linearDepth, linearPrevDepth), 0.1);

                color.a *= (closeToCamera ? depthWeight : 1.0);

                #if GI == 0
                    color.a = min(color.a + 1.0, MAX_ACCUMULATED_FRAMES);
                #else
                    bool rejectHistory;
                    history = filterHistory(DEFERRED_BUFFER, prevPosition.xy, material.normal, linearizeDepth(prevPosition.z, nearPlane, farPlane), rejectHistory);

                    color.a = history.a;

                    if (!rejectHistory) {
                        color.a = min(color.a + 1.0, MAX_ACCUMULATED_FRAMES);
                    } else {
                        color.a = 0.0;
                    }

                    color.a *= float(depth >= handDepth);
                #endif
            #else
                color.a *= float(hideGUI);

                color.a++;
            #endif
            
        #endif

        bool isMetal = material.F0 * maxFloat8 > labPBRMetals;

        #if GI == 0
        
            color.rgb = vec3(0.0);

            float cloudsShadows = 1.0; 
            vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                cloudsShadows = getCloudsShadows(viewToScene(viewPosition));
            #endif

            #if SHADOWS > 0
                shadowmap = textureBicubic(SHADOWMAP_BUFFER, vertexCoords);
            #endif

            float ao = 1.0;
            #if AO > 0
                ao = texture(AO_BUFFER, vertexCoords).b;
            #endif

            color.rgb = computeDiffuse(viewPosition, shadowLightVector, material, isMetal, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows);

        #else

            if (length(viewToScene(viewPosition)) > GI_RENDER_DISTANCE) return; 

            pathtraceDiffuse(modFragment, projection, projectionInverse, directIlluminance, isMetal, color.rgb, vec3(vertexCoords, depth));

            #if TEMPORAL_ACCUMULATION == 1

                float weight = saturate(1.0 / max(color.a, 1.0));
                color.rgb = mix(history.rgb, color.rgb, weight);

            #endif

            #if ATROUS_FILTER == 1

                float luminance = luminance(color.rgb);
                vec2  moments   = vec2(luminance, luminance * luminance);

                #if TEMPORAL_ACCUMULATION == 1
                    momentsOut.gb = mix(momentsOut.gb, moments, weight);
                #endif

                if (color.a < VARIANCE_STABILIZATION_THRESHOLD) {
                    momentsOut.a = estimateSpatialVariance(DEFERRED_BUFFER, moments);
                } else { 
                    momentsOut.a = max0(momentsOut.b - momentsOut.g * momentsOut.g);
                }
        
            #endif

        #endif
    }
#endif
