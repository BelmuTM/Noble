/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    #include "/include/utility/phase.glsl"
    #include "/include/atmospherics/constants.glsl"
    #include "/include/atmospherics/atmosphere.glsl"

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

        layout (location = 0) out vec4 radianceOut;
        layout (location = 1) out uvec2 firstBounceData;
        layout (location = 2) out vec4 momentsOut;
    #else
        /* RENDERTARGETS: 4,10 */

        layout (location = 0) out vec4 radianceOut;
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
		    float estimateSpatialVariance(sampler2D tex, vec2 coords) {
			    float sum = 0.0, sqSum = 0.0, totalWeight = 1.0;

			    int filterSize = 1;

			    for(int x = -filterSize; x <= filterSize; x++) {
				    for(int y = -filterSize; y <= filterSize; y++) {
					    if(x == 0 && y == 0) continue;

					    vec2 sampleCoords = coords + vec2(x, y) * texelSize;
					    if(saturate(sampleCoords) != sampleCoords) continue;

					    float weight    = gaussianDistribution2D(vec2(x, y), 1.0);
					    float luminance = luminance(texture(tex, sampleCoords).rgb);
                    
					    sum   += luminance * weight;
					    sqSum += luminance * luminance * weight;

					    totalWeight += weight;
				    }
			    }
			    sum   /= totalWeight;
			    sqSum /= totalWeight;
			    return sqrt(abs(sqSum - (sum * sum)));
    	    }
	    #endif
    #endif

    #if RENDER_MODE == 0
	    float calculateGaussianDepthWeight(float depth, float sampleDepth, float sigma) {
    	    return pow(exp(-abs(linearizeDepthFast(depth) - linearizeDepthFast(sampleDepth))), sigma);
	    }
    #endif

    void main() {
        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	    if(saturate(fragCoords) != fragCoords) { discard; return; }

        float depth        = texture(depthtex0, vertexCoords).r;
        vec3  viewPosition = screenToView(vec3(textureCoords, depth));

        vec3 skyIlluminance = vec3(0.0);
        #if defined WORLD_OVERWORLD || defined WORLD_END
            skyIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(gl_FragCoord.xy), 0).rgb;
        #endif

        if(depth == 1.0) {
            vec3 sky = renderAtmosphere(vertexCoords, viewPosition, directIlluminance, skyIlluminance);
            #if GI == 1
                firstBounceData.x = packUnormArb(logLuvEncode(sky), uvec4(8));
            #else
                radianceOut.rgb = sky;
            #endif
            return;
        }

        Material material = getMaterial(vertexCoords);

        #if HARDCODED_SSS == 1
            if(material.blockId > NETHER_PORTAL_ID && material.blockId <= PLANTS_ID && material.subsurface <= EPS) material.subsurface = HARDCODED_SSS_VAL;
        #endif

        #if AO_FILTER == 1 && GI == 0 || REFLECTIONS == 1 && GI == 0 || GI == 1 && TEMPORAL_ACCUMULATION == 1
            vec3 prevPosition = vec3(vertexCoords, depth) + getVelocity(vec3(textureCoords, depth)) * RENDER_SCALE;
            vec4 history      = texture(ACCUMULATION_BUFFER, prevPosition.xy);

            radianceOut.a  = history.a;
            radianceOut.a *= float(clamp(prevPosition.xy, 0.0, RENDER_SCALE) == prevPosition.xy);
            radianceOut.a *= float(depth >= handDepth);

            momentsOut = texture(MOMENTS_BUFFER, prevPosition.xy);

            #if RENDER_MODE == 0
                float prevDepth = exp2(momentsOut.a);

                #if GI == 0
                    radianceOut.a *= calculateGaussianDepthWeight(prevPosition.z, prevDepth, 0.3);

                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPosition.xy * viewSize) - 1.0);
                         radianceOut.a  *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.1 + 0.9;

                    momentsOut.a = log2(prevPosition.z);
                #else
				    float linearDepth     = linearizeDepthFast(prevPosition.z);
				    float linearPrevDepth = linearizeDepthFast(prevDepth);

				    radianceOut.a *= float(depth < 1.0);
				    radianceOut.a *= float(abs(linearDepth - linearPrevDepth) / abs(linearDepth) < 0.3);
				    radianceOut.a *= calculateGaussianDepthWeight(prevPosition.z, prevDepth, 0.5);
                    radianceOut.a *= float(material.depth0 >= handDepth);

				    momentsOut.a = log2(prevPosition.z);
                #endif
            #else
                radianceOut.a *= float(hideGUI);
            #endif

            radianceOut.a++;
        #endif

        #if GI == 0
            radianceOut.rgb = vec3(0.0);

            if(material.F0 * maxVal8 <= 229.5) {
                float cloudsShadows = 1.0; vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

                #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                    cloudsShadows = getCloudsShadows(viewToScene(viewPosition));
                #endif

                #if SHADOWS == 1
                    shadowmap = texelFetch(SHADOWMAP_BUFFER, ivec2(gl_FragCoord.xy), 0);
                #endif

                float ao = 1.0;
                #if AO == 1
                    ao = texture(AO_BUFFER, vertexCoords).b;
                #endif

                radianceOut.rgb = computeDiffuse(viewPosition, shadowVec, material, shadowmap, directIlluminance, skyIlluminance, ao, cloudsShadows);
            }
        #else
            vec3 direct   = vec3(0.0);
            vec3 indirect = vec3(1.0);

            if(material.F0 * maxVal8 <= 229.5) {
                pathtrace(radianceOut.rgb, vec3(vertexCoords, depth), direct, indirect);

                #if TEMPORAL_ACCUMULATION == 1
                    radianceOut.a = min(radianceOut.a, 256.0);
                    float weight  = saturate(1.0 / max(radianceOut.a, 1.0));

                    radianceOut.rgb = clamp16(mix(history.rgb, radianceOut.rgb, weight));

                    uint data = texture(GI_DATA_BUFFER, prevPosition.xy).g;
                    indirect  = mix(logLuvDecode(unpackUnormArb(data, uvec4(8))), indirect, 1.0);

			        #if RENDER_MODE == 0 && ATROUS_FILTER == 1
				        float luminance = luminance(radianceOut.rgb);
				        vec2  moments   = vec2(luminance, luminance * luminance);

				        momentsOut.rg = mix(momentsOut.rg, moments, weight);

				        if(radianceOut.a < VARIANCE_STABILIZATION_THRESHOLD) {
					        momentsOut.b = estimateSpatialVariance(ACCUMULATION_BUFFER, vertexCoords);
				        } else { 
					        momentsOut.b = abs(momentsOut.g - (momentsOut.r * momentsOut.r));
				        }
			        #endif
                #endif

                firstBounceData.x = packUnormArb(logLuvEncode(direct  ), uvec4(8));
                firstBounceData.y = packUnormArb(logLuvEncode(indirect), uvec4(8));
            }
        #endif
    }
#endif
