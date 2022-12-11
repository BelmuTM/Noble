/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if GI == 1 && GI_FILTER == 1
    /* RENDERTARGETS: 13,11 */

    layout (location = 0) out vec3 color;
    layout (location = 1) out vec4 moments;

    #include "/include/fragment/atrous.glsl"
#else
    /* RENDERTARGETS: 13 */

    layout (location = 0) out vec3 color;
#endif

void main() {
    color = texture(colortex4, texCoords).rgb;

    #if GI == 1 && GI_FILTER == 1
        aTrousFilter(color, colortex4, texCoords, moments, 2);
    #endif
}
