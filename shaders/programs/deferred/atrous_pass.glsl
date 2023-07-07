/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#if GI == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 4,10 */

        layout (location = 0) out vec4 color;
        layout (location = 1) out vec4 temporalData;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #if GI_FILTER == 1
            #include "/include/fragment/atrous.glsl"
        #endif

        void main() {
            color = texture(DEFERRED_BUFFER, vertexCoords);

            #if GI_FILTER == 1
                aTrousFilter(color.rgb, temporalData, DEFERRED_BUFFER, vertexCoords, ATROUS_PASS_INDEX);
            #endif
        }
    #endif
#endif
