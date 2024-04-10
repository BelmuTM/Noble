/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Zombye - providing the off-center rejection weight (https://github.com/zombye)

    [References]:
        Pedersen, L. J. F. (2016). Temporal Reprojection Anti-Aliasing in INSIDE. http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
        Intel. (2023). TAA. https://github.com/GameTechDev/TAA/tree/39786709cf70a1e0906196c600f6079571a33ceb
*/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec2 vertexCoords;

    void main() {
        gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        textureCoords = gl_Vertex.xy;
        vertexCoords  = gl_Vertex.xy * RENDER_SCALE;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec3 color;

    in vec2 textureCoords;
    in vec2 vertexCoords;

    #if EIGHT_BITS_FILTER == 0 && TAA == 1
    
        #include "/include/utility/sampling.glsl"

        vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
            vec3 pClip = 0.5 * (maxColor + minColor); // Center
            vec3 eClip = 0.5 * (maxColor - minColor); // Size

            vec3 vClip  = prevColor - pClip;
            float denom = maxOf(abs(vClip / eClip));

            return denom > 1.0 ? pClip + vClip / denom : prevColor;
        }

        #if GI == 0
            const float scale = RENDER_SCALE;
        #else
            const float scale = RENDER_SCALE * GI_SCALE * 0.01;
        #endif

        vec3 neighbourhoodClipping(sampler2D currTex, vec3 history) {
            vec3 minColor, maxColor;

            ivec2 coords = ivec2(gl_FragCoord.xy * scale);

            // Left to right, top to bottom
            vec3 sample_0 = texelFetch(currTex, coords + ivec2(-1,  1), 0).rgb;
            vec3 sample_1 = texelFetch(currTex, coords + ivec2( 0,  1), 0).rgb;
            vec3 sample_2 = texelFetch(currTex, coords + ivec2( 1,  1), 0).rgb;
            vec3 sample_3 = texelFetch(currTex, coords + ivec2(-1,  0), 0).rgb;
            vec3 sample_4 = texelFetch(currTex, coords                , 0).rgb;
            vec3 sample_5 = texelFetch(currTex, coords + ivec2( 1,  0), 0).rgb;
            vec3 sample_6 = texelFetch(currTex, coords + ivec2(-1, -1), 0).rgb;
            vec3 sample_7 = texelFetch(currTex, coords + ivec2( 0, -1), 0).rgb;
            vec3 sample_8 = texelFetch(currTex, coords + ivec2( 1, -1), 0).rgb;

            // Min and max nearest 5 + nearest 9
            minColor  = min(sample_1, min(sample_3, min(sample_4, min(sample_5, sample_7))));
	        minColor += min(minColor, min(sample_0, min(sample_2, min(sample_6, sample_8))));
	        minColor *= 0.5;

	        maxColor  = max(sample_1, max(sample_3, max(sample_4, max(sample_5, sample_7))));
	        maxColor += max(minColor, max(sample_0, max(sample_2, max(sample_6, sample_8))));
	        maxColor *= 0.5;

            history = clipAABB(history, minColor, maxColor);

            return history;
        }

        // https://iquilezles.org/articles/texture/
        vec4 textureCubic(sampler2D tex, vec2 uv) {
            uv = uv * viewSize + 0.5;
            vec2 fuv = fract(uv);
            uv = floor(uv) + fuv * fuv * (3.0 - 2.0 * fuv);
            uv = (uv - 0.5) * texelSize;
            return texture(tex, uv);
        }

        vec3 reinhard(vec3 color) {
            return color / (1.0 + luminance(color));
        }

        vec3 inverseReinhard(vec3 color) {
            return color / (1.0 - luminance(color));
        }

    #endif

    #if EIGHT_BITS_FILTER == 1
        vec4 samplePixelatedBuffer(sampler2D tex, vec2 coords, int size) {
            vec2 aspectCorrectedSize = size * vec2(aspectRatio, 1.0);
            return texelFetch(tex, ivec2((floor(coords * aspectCorrectedSize) / aspectCorrectedSize) * viewSize), 0);
        }
    #endif

    void main() {
        #if EIGHT_BITS_FILTER == 1 || TAA == 0
            #if EIGHT_BITS_FILTER == 1
                color = samplePixelatedBuffer(DEFERRED_BUFFER, vertexCoords, 400).rgb;
            #else
                color = texture(DEFERRED_BUFFER, vertexCoords).rgb;
            #endif
        #else
            sampler2D depthTex = depthtex0;
            float     depth    = texture(depthtex0, vertexCoords).r;

            mat4 projectionInverse = gbufferProjectionInverse;

            #if defined DISTANT_HORIZONS
                if(depth >= 1.0) {
                    depthTex = dhDepthTex0;
                    depth    = texture(dhDepthTex0, vertexCoords).r;

                    projectionInverse = dhProjectionInverse;
                }
            #endif

            vec3 closestFragment = getClosestFragment(depthTex, vec3(textureCoords, depth));
            vec2 velocity        = getVelocity(vec3(textureCoords, depth), projectionInverse).xy;
            vec2 prevCoords      = textureCoords + velocity;

            if(saturate(prevCoords) == prevCoords) {
                vec2 jitteredCoords = vertexCoords + taaOffsets[framemod] * texelSize;

                vec3 currColor = textureCubic(DEFERRED_BUFFER, jitteredCoords).rgb;

                vec3 history = max0(textureCatmullRom(HISTORY_BUFFER, prevCoords).rgb);
                     history = neighbourhoodClipping(DEFERRED_BUFFER, history);

	            float luminanceDelta = pow2(distance(history, currColor) / luminance(history));

	            float weight = saturate(length(velocity * viewSize));

                if(depth > handDepth) {
	                weight = (1.0 - TAA_STRENGTH + weight * 0.2) / (1.0 + luminanceDelta);
                } else {
                    weight = 1.0 - TAA_STRENGTH + weight;
                }

                color = inverseReinhard(mix(reinhard(history), reinhard(currColor), saturate(weight)));
            } else {
                color = texture(DEFERRED_BUFFER, vertexCoords).rgb;
            }
        #endif

        color = max0(color);
    }
    
#endif
