/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/common.glsl"

#if defined STAGE_VERTEX

    out vec2 texCoords;
    out float avgLuminance;

    #include "/include/post/exposure.glsl"

    void main() {
        gl_Position  = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords    = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        avgLuminance = 0.0;

        #if EXPOSURE == 1
            avgLuminance = computeAverageLuminance(colortex8);
        #endif
    }

#elif defined STAGE_FRAGMENT
    /* RENDERTARGETS: 0,8 */

    layout (location = 0) out vec3 color;
    layout (location = 1) out vec4 historyBuffer;

    in vec2 texCoords;
    in float avgLuminance;

    #include "/include/utility/blur.glsl"
    #include "/include/post/taa.glsl"

    void main() {
        color = texture(colortex0, texCoords).rgb;

        #if TAA == 1 && GI == 0
            color = clamp16(temporalAntiAliasing(colortex0, colortex8));
        #endif

        historyBuffer = vec4(color, avgLuminance);
    }
#endif
