/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/*
    [Credits]:
        Zombye - providing the off-center rejection weight (https://github.com/zombye)

    [References]:
        Pedersen, L. J. F. (2016). Temporal Reprojection Anti-Aliasing in INSIDE. http://s3.amazonaws.com/arena-attachments/655504/c5c71c5507f0f8bf344252958254fb7d.pdf?1468341463
*/

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

    #if TAA == 1
        #include "/include/utility/sampling.glsl"

        vec3 clipAABB(vec3 prevColor, vec3 minColor, vec3 maxColor) {
            vec3 pClip = 0.5 * (maxColor + minColor); // Center
            vec3 eClip = 0.5 * (maxColor - minColor); // Size

            vec3 vClip  = prevColor - pClip;
            float denom = maxOf(abs(vClip / eClip));

            return denom > 1.0 ? pClip + vClip / denom : prevColor;
        }

        vec3 neighbourhoodClipping(sampler2D currTex, vec3 prevColor) {
            vec3 minColor = vec3(1e10), maxColor = vec3(-1e10);
            const int size = 1;

            for(int x = -size; x <= size; x++) {
                for(int y = -size; y <= size; y++) {
                    vec3 color = SRGB_2_YCoCg_MAT * texelFetch(currTex, ivec2(gl_FragCoord.xy * RENDER_SCALE) + ivec2(x, y), 0).rgb;
                    minColor = min(minColor, color); 
                    maxColor = max(maxColor, color); 
                }
            }
            return clipAABB(prevColor, minColor, maxColor);
        }

        vec3 getClosestFragment(vec3 position) {
	        vec3 closestFragment = position;
            vec3 currentFragment;

            for(int x = -1; x <= 1; x++) {
                for(int y = -1; y <= 1; y++) {
                    currentFragment.xy = position.xy + vec2(x, y) * pixelSize;
                    currentFragment.z  = texture(depthtex0, currentFragment.xy * RENDER_SCALE).r;
                    closestFragment    = currentFragment.z < closestFragment.z ? currentFragment : closestFragment;
                }
            }
            return closestFragment;
        }
    #endif

    void main() {
        #if TAA == 0
            color.rgb = texture(MAIN_BUFFER, vertexCoords).rgb;
        #else
            vec3 closestFragment = getClosestFragment(vec3(textureCoords, texture(depthtex0, vertexCoords).r));
            vec2 prevCoords      = textureCoords + getVelocity(closestFragment).xy;

            vec3 currColor = SRGB_2_YCoCg_MAT * textureCatmullRom(MAIN_BUFFER   , vertexCoords).rgb;
            vec3 prevColor = SRGB_2_YCoCg_MAT * textureCatmullRom(HISTORY_BUFFER, prevCoords  ).rgb;
                 prevColor = neighbourhoodClipping(MAIN_BUFFER, prevColor);

            float weight = float(saturate(prevCoords) == prevCoords) * TAA_STRENGTH;

            vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevCoords * viewSize) - 1.0);
                 weight         *= sqrt(pixelCenterDist.x * pixelCenterDist.y) * TAA_OFFCENTER_REJECTION + (1.0 - TAA_OFFCENTER_REJECTION);

            color.rgb = YCoCg_2_SRGB_MAT * mix(currColor, prevColor, saturate(weight));
        #endif

        #if EXPOSURE > 0
            color.a = sqrt(luminance(color.rgb));
        #endif
    }
#endif
