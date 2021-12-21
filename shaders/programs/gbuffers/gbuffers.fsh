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
in vec3 viewPos;
in vec4 color;
in mat3 TBN;
in float blockId;

#include "/settings.glsl"
#define STAGE STAGE_FRAGMENT

#include "/include/uniforms.glsl"
#include "/include/utility/math.glsl"

#ifdef ENTITY
	uniform vec4 entityColor;
#endif

// https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
float waterCaustics(vec3 oldPos, vec3 normal) {
	vec3 lightDir = mat3(shadowModelView) * mat3(gbufferModelViewInverse) * normalize(shadowLightPosition);
	vec3 newPos   = oldPos + refract(lightDir, normal, 1.0 / 1.333) * 2.5;

	float oldArea = length(dFdy(oldPos) * dFdy(oldPos));
	float newArea = length(dFdy(newPos) * dFdy(newPos));

	return oldArea / newArea * 0.2;
}

void main() {
	vec4 albedoTex   = texture(colortex0, texCoords);
	vec4 normalTex   = texture(normals,   texCoords);
	vec4 specularTex = texture(specular,  texCoords);

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
	normal  = TBN * normal;
	normal *= 0.5 + 0.5;

	/*	
	if(int(blockId + 0.5) > 4 && int(blockId + 0.5) <= 11 && emission < 0.1) {
		emission = 0.8;
	}
	*/
	
	/*DRAWBUFFERS:012*/
	gl_FragData[0] = color * albedoTex;
	gl_FragData[1] = vec4(encodeNormal(normal), lmCoords.xy);
	gl_FragData[2] = vec4(clamp01(roughness), (blockId + 0.25) / 255.0, pack2x4(vec2(ao, emission)), pack2x4(vec2(F0, subsurface)));
}
