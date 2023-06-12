/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 textureCoords;

void main() {
    gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
    textureCoords = gl_Vertex.xy;
}
