/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

in vec2 texCoords;
in vec2 lmCoords;
in vec3 waterNormals;
in vec4 color;
in mat3 TBN;
in float blockId;

#include "/settings.glsl"
#include "/include/uniforms.glsl"
#include "/include/utility/math.glsl"

#ifdef ENTITY
	uniform vec4 entityColor;
#endif

void main() {
	vec4 albedoTex   = texture(colortex0, texCoords);
	vec4 normalTex   = texture(normals,   texCoords);
	vec4 specularTex = texture(specular,  texCoords);

	#ifdef ENTITY
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif

	float F0 		= specularTex.y;
	float ao 		= normalTex.z;
	float roughness = hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x;
	float emission  = specularTex.w * 255.0 < 254.5 ? specularTex.w : 0.0;

	vec3 normal;
	// WOTAH
	if(int(blockId + 0.5) == 1) { 
		albedoTex = vec4(0.0);
		F0 = 0.02;
		roughness = 0.0;
		normal = waterNormals;
	} else {
		normal.xy = normalTex.xy * 2.0 - 1.0;
		normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
	}
	normal = TBN * normal;
	normal *= 0.5 + 0.5;

	/*	
	if(int(blockId + 0.5) > 4 && int(blockId + 0.5) <= 11 && emission < 0.1) {
		emission = 0.8;
	}
	*/
	
	/*DRAWBUFFERS:012*/
	gl_FragData[0] = color * albedoTex;
	gl_FragData[1] = vec4(encodeNormal(normal), pack2x4(vec2(ao, emission)), (blockId + 0.25) / 255.0);
	gl_FragData[2] = vec4(clamp01(roughness), F0, lmCoords.xy);
}
