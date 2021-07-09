/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
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
varying vec3 viewPos;

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D depthtex0;

uniform float rainStrength;
uniform float near;
uniform float far;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

#include "/settings.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/color.glsl"

#ifdef ENTITY
uniform vec4 entityColor;
#endif

/*
const int colortex0Format = RGBA16F;
*/

void main() {
	//Sample textures
	vec4 albedoTex = texture2D(texture, texCoords);
	vec4 normalTex = texture2D(normals, texCoords);
	vec4 specularTex = texture2D(specular, texCoords);

	if(albedoTex.a < 0.1) discard;
	albedoTex *= color;

	#ifdef TERRAIN
		albedoTex.a *= color.a;

		#if WHITE_WORLD == 1
			albedoTex = vec4(1.0);
		#endif
	#endif

	#ifdef BLOCK 
		#if WHITE_WORLD == 1
			albedoTex = vec4(1.0);
		#endif
	#endif

	#ifdef ENTITY
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif
	
	//Normals
	vec3 normal;
	normal.xy = normalTex.xy * 2.0 - 1.0;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy)); //Reconstruct Z
	normal = clamp(normal, -1.0, 1.0); //Clamp into right range
	normal = TBN * normal; //Rotate by TBN matrix

	float ao = normalTex.z;
	
    	float roughness = pow(1.0 - specularTex.x, 2.0);
	float F0 = specularTex.y;
	bool isMetal = (F0 * 255.0) > 229.5;
	vec2 lightmap = lmCoords.xy;

	float emission = (specularTex.w * 255.0) < 254.5 ? specularTex.w : 0.0;

	float scattering = 0.0;
	if(!isMetal) {
		scattering = (specularTex.z * 255.0) < 65.0 ? 0.0 : specularTex.z;
	}
	
	/*DRAWBUFFERS:0123*/
	gl_FragData[0] = albedoTex;
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, ao);
	gl_FragData[2] = vec4(clamp(roughness, 0.001, 1.0), F0, lightmap);
	gl_FragData[3] = vec4(blockId / 255.0, 0.0, scattering, emission);
}