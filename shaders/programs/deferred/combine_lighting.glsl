/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#if defined STAGE_VERTEX
    #include "/programs/vertex_taau.glsl"

#elif defined STAGE_FRAGMENT

	/* RENDERTARGETS: 13 */

	layout (location = 0) out vec3 lighting;

	in vec2 textureCoords;
	in vec2 vertexCoords;

	#include "/include/common.glsl"

	void main() {
		#if GI == 0
    		lighting = texture(ACCUMULATION_BUFFER, vertexCoords).rgb;
			return;
		#endif

        uvec2 packedFirstBounceData = texture(GI_DATA_BUFFER, vertexCoords).rg;

        vec3 direct   = logLuvDecode(unpackUnormArb(packedFirstBounceData[0], uvec4(8)));
        vec3 indirect = logLuvDecode(unpackUnormArb(packedFirstBounceData[1], uvec4(8)));

        #if ATROUS_FILTER == 1
            vec3 radiance = texture(DEFERRED_BUFFER, vertexCoords).rgb;
        #else
            vec3 radiance = texture(ACCUMULATION_BUFFER, vertexCoords).rgb;
        #endif
        
        lighting = direct + indirect * radiance;
	}
#endif
