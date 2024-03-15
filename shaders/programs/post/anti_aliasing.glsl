/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Zombye - providing the off-center rejection weight (https://github.com/zombye)

    [References]:
        Pedersen, L. J. F. (2016). Temporal Reprojection Anti-Aliasing in INSIDE. http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
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

    layout (location = 0) out vec4 color;

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

        vec3 neighbourhoodClipping(sampler2D currTex, vec3 prevColor) {
            vec3 minColor = vec3(1e6), maxColor = vec3(-1e6);
            const int size = 1;

            for(int x = -size; x <= size; x++) {
                for(int y = -size; y <= size; y++) {
                    vec3 color = SRGB_2_YCoCg_MAT * texelFetch(currTex, ivec2(gl_FragCoord.xy * scale) + ivec2(x, y), 0).rgb;
                    minColor = min(minColor, color); 
                    maxColor = max(maxColor, color); 
                }
            }
            return clipAABB(prevColor, minColor, maxColor);
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
                color.rgb = samplePixelatedBuffer(DEFERRED_BUFFER, vertexCoords, 400).rgb;
            #else
                color.rgb = texture(DEFERRED_BUFFER, vertexCoords).rgb;
            #endif
        #else
            vec3 closestFragment = getClosestFragment(vec3(textureCoords, texture(depthtex0, vertexCoords).r));
            vec2 velocity        = getVelocity(closestFragment).xy;
            vec2 prevCoords      = textureCoords + velocity;

            if(saturate(prevCoords) == prevCoords) {
                vec2 jitteredCoords = vertexCoords + taaOffsets[framemod] * texelSize;

                vec3 currColor = SRGB_2_YCoCg_MAT * textureBicubic(DEFERRED_BUFFER, jitteredCoords).rgb;
                vec3 prevColor = SRGB_2_YCoCg_MAT * max0(textureCatmullRom(HISTORY_BUFFER, prevCoords).rgb);
                     prevColor = neighbourhoodClipping(DEFERRED_BUFFER, prevColor);

	            float luminanceDelta = pow2(distance(prevColor, currColor) / luminance(prevColor));

	            float weight = saturate(length(velocity * viewSize));
	                  weight = (1.0 - TAA_STRENGTH + weight * 0.3) / (1.0 + luminanceDelta);

                color.rgb = max0(YCoCg_2_SRGB_MAT * mix(prevColor, currColor, saturate(weight)));
            } else {
                color.rgb = texture(DEFERRED_BUFFER, vertexCoords).rgb;
            }
        #endif

        #if EXPOSURE > 0
            color.a = sqrt(luminance(max(color.rgb, vec3(EPS))));
        #endif
    }
    
#endif
