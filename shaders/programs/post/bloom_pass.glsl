/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"

#if BLOOM == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
    
        out vec2 textureCoords;

        void main() {
            gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            textureCoords = gl_Vertex.xy;
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 3 */

        layout (location = 0) out vec3 tilemap;

        in vec2 textureCoords;

        #include "/include/utility/sampling.glsl"
        #include "/include/post/bloom.glsl"

        void main() {
            tilemap = BLOOM_PASS_INDEX == 0 ? vec3(0.0) : texture(colortex3, textureCoords).rgb;
            writeBloomTile(tilemap, BLOOM_PASS_INDEX);
        }
    #endif
#endif
