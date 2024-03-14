/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"

#if BLOOM == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX

        void main() {
            gl_Position = vec4(gl_Vertex.xy * 2.0 - 1.0, 0.0, 1.0);
        }

    #elif defined STAGE_FRAGMENT

		/* RENDERTARGETS: 3 */

		layout (location = 0) out vec3 bloom;

		uniform sampler2D colortex3;

		void main() {
            bloom = texelFetch(colortex3, ivec2(gl_FragCoord.xy), 0).rgb;
		}
        
	#endif
#endif
