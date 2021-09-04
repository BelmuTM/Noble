/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;
varying vec2 lmCoords;
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
const int colortex1Format = RGBA16F;
const int colortex2Format = RGBA16F;
*/

void main() {
	vec4 albedoTex = texture2D(texture, texCoords);
	vec4 normalTex = texture2D(normals, texCoords);
	vec4 specularTex = texture2D(specular, texCoords);

	#ifdef ENTITY
		// Alpha blending on entities
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif
	
	vec3 normal;
	normal.xy = normalTex.xy * 2.0 - 1.0;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy));
	normal = TBN * normal;
	normal = clamp(normal, -1.0, 1.0);

	float ao = normalTex.z;
    float roughness = hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x;
	float F0 = specularTex.y;

	vec2 lightmap = lmCoords.xy;
	float emission = specularTex.w * 255.0 < 254.5 ? specularTex.w : 0.0;

	if(int(blockId + 0.5) == 1) { 
		albedoTex.a = 0.0;
		F0 = 0.3;
		roughness = 0.01;
	}
	
	/*DRAWBUFFERS:0123*/
	gl_FragData[0] = color * albedoTex;
	gl_FragData[1] = vec4(encodeNormal(normal), emission, ao);
	gl_FragData[2] = vec4(roughness, F0, lightmap);
	gl_FragData[3] = vec4((blockId + 0.25) / 255.0);
}
