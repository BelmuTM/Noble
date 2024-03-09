/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#if BLOOM == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
    
        out vec2 textureCoords;

        void main() {
            gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
            textureCoords = gl_Vertex.xy;
        }

    #elif defined STAGE_FRAGMENT

		/* RENDERTARGETS: 3 */

		layout (location = 0) out vec3 bloom;

		in vec2 textureCoords;

		uniform sampler2D colortex3;

		void main() {
            bloom = texture(colortex3, textureCoords).rgb;
		}
        
	#endif
#endif
