/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/post/exposure.glsl"

#if defined STAGE_VERTEX

    out float exposure;

    void main() {
        exposure = computeExposure();

        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 4,8 */

    layout (location = 0) out vec3 color;
    layout (location = 1) out vec4 historyBuffer;

    #include "/include/post/taa.glsl"

    in float exposure;

    void main() {
        color = texture(colortex4, texCoords).rgb;

        #if TAA == 1
            color = max0(temporalAntiAliasing(getMaterial(texCoords), colortex4, colortex8));
        #endif

        historyBuffer.rgb = color;
        historyBuffer.a   = exposure;
    }

#endif
