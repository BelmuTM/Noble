/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/post/exposure.glsl"

#ifdef STAGE_VERTEX

    out float avgLuminance;

    void main() {
        #if EXPOSURE == 1
            avgLuminance = computeAvgLuminance();
        #endif

        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 4,8 */

    layout (location = 0) out vec4 color;
    layout (location = 1) out vec4 history;

    #include "/include/post/taa.glsl"

    in float avgLuminance;

    void main() {
        color = texture(colortex4, texCoords);

        #if TAA == 1
            color.rgb = temporalAntiAliasing(getMaterial(texCoords), colortex4, colortex8);
        #endif

        history.rgb = color.rgb;

        #if EXPOSURE == 0
            float EV100 = log2(pow2(APERTURE) / (1.0 / SHUTTER_SPEED) * 100.0 / ISO);
            color.a     = EV100ToExposure(avgLuminance);
        #else
            color.a   = EV100ToExposure(EV100fromLuma(avgLuminance));
            history.a = avgLuminance;
        #endif

        color.a    = clamp(color.a, minExposure, maxExposure);
        color.rgb *= color.a;
    }
#endif
