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
            directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
        #endif
    }

#elif defined STAGE_FRAGMENT

    #if GI == 1
        /* RENDERTARGETS: 4,9,10 */

        layout (location = 0) out vec4 color;
        layout (location = 1) out vec3 directOut;
        layout (location = 2) out vec4 momentsOut;
    #else
        /* RENDERTARGETS: 4,10 */

        layout (location = 0) out vec4 color;
        layout (location = 1) out vec4 momentsOut;
    #endif

    in vec2 textureCoords;
    in vec2 vertexCoords;
    in vec3 directIlluminance;

    #include "/include/atmospherics/constants.glsl"

    #include "/include/utility/phase.glsl"

    #include "/include/fragment/brdf.glsl"
    #include "/include/atmospherics/celestial.glsl"

    #if GI == 1
        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/pathtracer.glsl"

        #if RENDER_MODE == 0 && ATROUS_FILTER == 1
			float estimateSpatialVariance(sampler2D tex, vec2 moments) {
				float sum = moments.r, sqSum = moments.g, totalWeight = 1.0;

				const float waveletKernel[3] = float[3](1.0, 2.0 / 3.0, 1.0 / 6.0);

				vec2 stepSize = 5.0 * texelSize;

				for(int x = -1; x <= 1; x++) {
					for(int y = -1; y <= 1; y++) {
						if(x == 0 && y == 0) continue;

						vec2 sampleCoords = textureCoords + vec2(x, y) * stepSize;
						if(saturate(sampleCoords) != sampleCoords) continue;

						float weight    = waveletKernel[abs(x)] * waveletKernel[abs(y)];
						float luminance = luminance(texture(tex, sampleCoords).rgb);
                    
						sum   += luminance * weight;
						sqSum += luminance * luminance * weight;

						totalWeight += weight;
					}
				}
				sum   /= totalWeight;
				sqSum /= totalWeight;
				return abs(sqSum - sum * sum);
    		}
	    #endif
    #endif

    void main() {
        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	    if(saturate(fragCoords) != fragCoords) { discard; return; }

        sampler2D depthTex = depthtex0;
        float     depth    = texture(depthtex0, vertexCoords).r;

        mat4 projection        = gbufferProjection;
        mat4 projectionInverse = gbufferProjectionInverse;

        float nearPlane = near;
        float farPlane  = far;

        #if defined DISTANT_HORIZONS
            if(depth >= 1.0) {
                depthTex = dhDepthTex0;
                depth    = texture(dhDepthTex0, vertexCoords).r;

                projection        = dhProjection;
                projectionInverse = dhProjectionInverse;

                nearPlane = dhNearPlane;
                farPlane  = dhFarPlane;
            }
        #endif

        vec3 viewPosition = screenToView(vec3(textureCoords, depth), projectionInverse, true);

        vec3 skyIlluminance = vec3(0.0);
        #if defined WORLD_OVERWORLD || defined WORLD_END
            skyIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(gl_FragCoord.xy), 0).rgb;
        #endif

        if(depth == 1.0) {
            vec3 sky = renderAtmosphere(vertexCoords, viewPosition, directIlluminance, skyIlluminance);
            #if GI == 1
                directOut = sky;
            #else
                color.rgb = sky;
            #endif
            return;
        }

        #if AO > 0 && AO_FILTER == 1 && GI == 0 || GI == 1 && TEMPORAL_ACCUMULATION == 1
            vec3 prevPosition = vec3(vertexCoords, depth) + getVelocity(vec3(textureCoords, depth), projectionInverse) * RENDER_SCALE;
            vec4 history      = texture(ACCUMULATION_BUFFER, prevPosition.xy);

            color.a  = history.a;
            color.a *= float(clamp(prevPosition.xy, 0.0, RENDER_SCALE) == prevPosition.xy);
            color.a *= float(depth >= handDepth);

            momentsOut = texture(MOMENTS_BUFFER, prevPosition.xy);

            #if RENDER_MODE == 0
                float prevDepth = exp2(momentsOut.a);
                
                momentsOut.a = log2(prevPosition.z);

                float linearDepth     = linearizeDepth(prevPosition.z, nearPlane, farPlane);
			    float linearPrevDepth = linearizeDepth(prevDepth     , nearPlane, farPlane);

                vec3 prevScenePosition = viewToScene(screenToView(prevPosition, projectionInverse, false));
                bool closeToCamera     = distance(gbufferModelViewInverse[3].xyz, prevScenePosition) > 1.1;

                float depthWeight = step(abs(linearDepth - linearPrevDepth) / max(linearDepth, linearPrevDepth), 0.1);

                color.a *= (closeToCamera ? depthWeight : 1.0);

                #if GI == 0
                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
                         color.a     *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.3 + 0.7;
                #else
                    color.a *= float(depth >= handDepth);
                #endif

                color.a = min(color.a, 60.0);
            #else
                color.a *= float(hideGUI);
            #endif

            color.a++;
        #endif

        Material material = getMaterial(vertexCoords);

        bool isMetal = material.F0 * maxFloat8 > 229.5;

        #if GI == 0
            color.rgb = vec3(0.0);

            float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

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

            color.rgb = computeDiffuse(viewPosition, shadowVec, material, isMetal, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows);
        #else
            pathtrace(depthTex, projection, projectionInverse, directIlluminance, isMetal, color.rgb, vec3(vertexCoords, depth), directOut);

            #if TEMPORAL_ACCUMULATION == 1
                float weight = 1.0 / max(color.a, 1.0);
                color.rgb = mix(history.rgb, color.rgb, weight);

                #if RENDER_MODE == 0 && ATROUS_FILTER == 1
                    float luminance = luminance(color.rgb);
                    vec2  moments   = vec2(luminance, luminance * luminance);

                    momentsOut.rg = mix(momentsOut.rg, moments, weight);

                    if(color.a < VARIANCE_STABILIZATION_THRESHOLD) {
                        momentsOut.b = estimateSpatialVariance(ACCUMULATION_BUFFER, moments);
                    } else { 
                        momentsOut.b = abs(momentsOut.g - momentsOut.r * momentsOut.r);
                    }
                #endif
            #endif
        #endif
    }
#endif
