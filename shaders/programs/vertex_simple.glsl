/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 texCoords;

void main() {
    gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
    texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
}
