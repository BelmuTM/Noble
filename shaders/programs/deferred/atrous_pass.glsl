/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if GI == 1
    #if defined STAGE_VERTEX
        #include "/programs/vertex_simple.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 5 */

        layout (location = 0) out vec4 color;

        #if GI_FILTER == 1
            #include "/include/fragment/atrous.glsl"
        #endif

        void main() {
            color = texture(colortex5, texCoords);

            #if GI_FILTER == 1
                aTrousFilter(color.rgb, colortex5, texCoords, ATROUS_PASS_INDEX);
            #endif
        }
    #endif
#else
    #include "/programs/discard.glsl"
#endif
