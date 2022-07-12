/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

out vec2 texCoords;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
