/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

out vec2 textureCoords;
out vec2 vertexCoords;

void main() {
    gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
    gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;
    textureCoords  = gl_Vertex.xy;
    vertexCoords   = gl_Vertex.xy * RENDER_SCALE;
}
