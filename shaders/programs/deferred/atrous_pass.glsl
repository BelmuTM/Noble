/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if GI == 0
    #include "/programs/discard.glsl"
#else

    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 4,11 */

        layout (location = 0) out vec4 color;
        layout (location = 1) out vec4 temporalData;

        in vec2 textureCoords;

        #if GI_FILTER == 1
            #include "/include/fragment/atrous.glsl"
        #endif

        void main() {
            color = texture(DEFERRED_BUFFER, textureCoords);

            #if GI_FILTER == 1
                aTrousFilter(color.rgb, temporalData, DEFERRED_BUFFER, ATROUS_PASS_INDEX);
            #endif
        }
    #endif
#endif
