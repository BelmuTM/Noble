/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if GI == 1
    #if defined STAGE_VERTEX
        #include "/programs/vertex_simple.glsl"

    #elif defined STAGE_FRAGMENT
        #if GI_FILTER == 1
            /* RENDERTARGETS: 5,11 */

            layout (location = 0) out vec4 color;
            layout (location = 1) out vec4 moments;

            #include "/include/fragment/atrous.glsl"
        #else
            /* RENDERTARGETS: 5 */

            layout (location = 0) out vec4 color;
        #endif

        void main() {
            color = texture(colortex5, texCoords);

            #if GI_FILTER == 1
                aTrousFilter(color.rgb, colortex5, texCoords, moments, 2);
            #endif
        }
    #endif
#else
    #include "/programs/discard.glsl"
#endif
