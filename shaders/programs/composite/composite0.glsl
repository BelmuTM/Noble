/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0 */

layout (location = 0) out vec3 color;

void main() {
    // TO-DO FILTERING GI
    color = texture(colortex0, texCoords).rgb;

    // Overlay
    vec4 overlay = texelFetch(colortex4, ivec2(gl_FragCoord.xy), 0);
    color        = mix(color, sRGBToLinear(overlay.rgb) * 1e4, overlay.a);
}
