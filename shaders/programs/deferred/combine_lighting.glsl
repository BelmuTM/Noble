/***********************************************/
/*          Copyright (C) 2024 Belmu           */
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
		#else
        	vec3 direct = texture(DIRECT_BUFFER, vertexCoords).rgb;
			vec3 albedo = ((uvec3(texture(GBUFFERS_DATA, vertexCoords).z) >> uvec3(0, 8, 16)) & 255u) * rcpMaxFloat8;

        	#if ATROUS_FILTER == 1
            	vec3 irradiance = texture(DEFERRED_BUFFER, vertexCoords).rgb;
        	#else
            	vec3 irradiance = texture(ACCUMULATION_BUFFER, vertexCoords).rgb;
        	#endif
        
        	lighting = direct + albedo * irradiance;
		#endif
	}
	
#endif
