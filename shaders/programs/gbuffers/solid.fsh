/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:1 */

layout (location = 0) out uvec4 dataBuffer;

in float blockId;
in vec2 texCoords;
in vec2 lmCoords;
in vec3 viewPos;
in vec4 vertexColor;
in mat3 TBN;

#include "/settings.glsl"
#define STAGE STAGE_FRAGMENT

#include "/include/uniforms.glsl"
#include "/include/utility/math.glsl"
#include "/include/utility/transforms.glsl"

#ifdef ENTITY
	uniform vec4 entityColor;
#endif

void main() {
	vec4 albedoTex   = texture(colortex0, texCoords);
	vec4 normalTex   = texture(normals,   texCoords);
	vec4 specularTex = texture(specular,  texCoords);

	if(albedoTex.a < 0.102) discard;

	albedoTex *= vertexColor;

	#ifdef ENTITY
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif

	float F0 		 = specularTex.y;
	float ao 		 = normalTex.z;
	float roughness  = clamp01(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
	float emission   = specularTex.w * 255.0 < 254.5 ? specularTex.w : 0.0;
	float subsurface = (specularTex.z * 255.0) < 65.0 ? 0.0 : specularTex.z;

	vec3 normal;
	normal.xy = normalTex.xy * 2.0 - 1.0;
	normal.z  = sqrt(1.0 - dot(normal.xy, normal.xy));

	vec2 encNormal = encodeUnitVector(TBN * normal);
	
	dataBuffer.x = packUnorm4x8(vec4(roughness, (blockId + 0.25) / 255.0, clamp01(lmCoords.xy)));
	dataBuffer.y = packUnorm4x8(vec4(ao, emission, F0, subsurface));
	dataBuffer.z = (uint(albedoTex.r * 255.0) << 24u) | (uint(albedoTex.g * 255.0) << 16u) | (uint(albedoTex.b * 255.0) << 8u) | uint(encNormal.x * 255.0);
	dataBuffer.w = uint(encNormal.y * 255.0);
}
