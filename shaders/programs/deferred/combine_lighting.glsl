/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

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

			uvec4 dataTexture = texture(GBUFFERS_DATA, vertexCoords);
			vec3  albedo      = (uvec3(dataTexture.z) >> uvec3(0, 8, 16) & 255u) * rcpMaxFloat8;

        	#if ATROUS_FILTER == 1
            	vec3 irradiance = texture(DEFERRED_BUFFER, vertexCoords).rgb;
        	#else
            	vec3 irradiance = texture(ACCUMULATION_BUFFER, vertexCoords).rgb;
        	#endif
        
        	lighting = direct + albedo * irradiance;
		#endif
	}
	
#endif
