/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if GI == 1 && GI_FILTER == 1
    /* RENDERTARGETS: 5,12 */

    layout (location = 0) out vec3 color;
    layout (location = 1) out vec3 moments;

    #include "/include/fragment/atrous.glsl"
#else
    /* RENDERTARGETS: 5 */

    layout (location = 0) out vec3 color;
#endif

void main() {
    color = texture(colortex5, texCoords).rgb;

    #if GI == 1 && GI_FILTER == 1
        aTrousFilter(color, colortex5, texCoords, moments, 2);
    #endif
}
