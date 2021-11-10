/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec3 waterNormals;
varying vec4 color;
varying mat3 TBN;
varying float blockId;

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util/math.glsl"

#ifdef ENTITY
	uniform vec4 entityColor;
#endif

/*
const int colortex0Format = RGBA16F;
const int colortex2Format = RGBA8F;
*/

void main() {
	vec4 albedoTex = texture(colortex0, texCoords);
	vec4 normalTex = texture(normals, texCoords);
	vec4 specularTex = texture(specular, texCoords);

	#ifdef ENTITY
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif

    float roughness = hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x;
	float F0 = specularTex.y;
	float ao = normalTex.z;

	vec2 lightmap = lmCoords.xy;
	float emission = specularTex.w * 255.0 < 254.5 ? specularTex.w : 0.0;

	vec3 normal;
	// WOTAH
	if(int(blockId + 0.5) == 1) { 
		albedoTex.a = 0.0;
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
	if(int(blockId + 0.5) > 4 && int(blockId + 0.5) <= 10 && emission < 0.1) {
		emission = 0.8;
	}
	*/
	
	/*DRAWBUFFERS:012*/
	gl_FragData[0] = color * albedoTex;
	gl_FragData[1] = vec4(encodeNormal(normal), pack2x4(vec2(ao, emission)), (blockId + 0.25) / 255.0);
	gl_FragData[2] = vec4(clamp01(roughness), F0, lightmap);
}
