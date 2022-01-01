/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:012 */

layout (location = 0) out vec4 albedoBuffer;
layout (location = 1) out vec4 normalBuffer;
layout (location = 2) out vec4 labPBRBuffer;

in float blockId;
in vec2 texCoords;
in vec2 lmCoords;
in vec3 waterNormals;
in vec3 viewPos;
in vec4 vertexColor;
in mat3 TBN;

#include "/settings.glsl"
#define STAGE STAGE_FRAGMENT

#include "/include/uniforms.glsl"
#include "/include/utility/math.glsl"

#ifdef ENTITY
	uniform vec4 entityColor;
#endif

void main() {
	vec4 albedoTex   = texture(colortex0, texCoords);
	vec4 normalTex   = texture(normals,   texCoords);
	vec4 specularTex = texture(specular,  texCoords);

	albedoTex *= vertexColor;

	#ifdef ENTITY
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif

	float F0 		 = specularTex.y;
	float ao 		 = normalTex.z;
	float roughness  = hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x;
	float emission   = specularTex.w * 255.0 < 254.5 ? specularTex.w : 0.0;
	float subsurface = (specularTex.z * 255.0) < 65.0 ? 0.0 : specularTex.z;

	vec3 normal;
	// WOTAH
	if(int(blockId + 0.5) == 1) { 
		albedoTex = vec4(1.0, 1.0, 1.0, 0.0);
		F0 		  = 0.02;
		roughness = 0.0;
		normal 	  = waterNormals;
	} else {
		normal.xy = normalTex.xy * 2.0 - 1.0;
		normal.z  = sqrt(1.0 - dot(normal.xy, normal.xy));
	}
	
	albedoBuffer = albedoTex;
	normalBuffer = vec4(encodeNormal(TBN * normal), lmCoords.xy);
	labPBRBuffer = vec4(clamp01(roughness), (blockId + 0.25) / 255.0, pack2x4(vec2(ao, emission)), pack2x8(vec2(F0, subsurface)));
}
