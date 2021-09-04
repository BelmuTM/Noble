/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

void main() {
    gl_Position = ftransform();
    texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
