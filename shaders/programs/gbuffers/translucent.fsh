/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 1,2 */

layout (location = 0) out vec4 sceneColor;
layout (location = 1) out uvec4 dataBuffer;

flat in int blockId;
in vec2 texCoords;
in vec2 lmCoords;
in vec3 viewPos;
in vec3 geoNormal;
in vec3 waterNormals;
in vec3 skyIlluminance;
in vec3 directLightTransmit;
in vec4 vertexColor;
in mat3 TBN;

#include "/include/fragment/brdf.glsl"
#include "/include/fragment/shadows.glsl"

void main() {
	vec4 albedoTex   = texture(colortex0, texCoords);
	vec4 normalTex   = texture(normals,   texCoords);
	vec4 specularTex = texture(specular,  texCoords);

	albedoTex *= vertexColor;

	Material mat;
    mat.F0         = specularTex.y;
    mat.rough      = clamp01(hardCodedRoughness != 0.0 ? hardCodedRoughness : 1.0 - specularTex.x);
    mat.ao         = all(greaterThan(geoNormal, vec3(0.0))) ? normalTex.z : 1.0; // Thanks Kneemund for the nametag fix
	mat.emission   = specularTex.w * maxVal8 < 254.5 ? specularTex.w : 0.0;
    mat.subsurface = (specularTex.z * maxVal8) < 65.0 ? 0.0 : specularTex.z;
    mat.isMetal    = mat.F0 * maxVal8 > 229.5;

    mat.albedo = albedoTex.rgb;
    mat.alpha  = albedoTex.a;

    mat.blockId  = blockId;
    mat.lightmap = lmCoords;

	#if WHITE_WORLD == 1
	    mat.albedo = vec3(1.0);
    #endif

	// WOTAH
	if(blockId == 1) { 
		mat.albedo = vec3(1.0);
		mat.alpha  = 0.0;
		mat.F0 	   = 0.02;
		mat.rough  = 0.0;
		mat.normal = TBN * waterNormals;
		
	} else {
		mat.normal.xy = normalTex.xy * 2.0 - 1.0;
		mat.normal.z  = sqrt(1.0 - dot(mat.normal.xy, mat.normal.xy));
		mat.normal    = TBN * mat.normal;

		#if GI == 0
			vec3 scenePos  = viewToScene(viewPos);
			vec3 shadowmap = shadowMap(scenePos, mat.normal);

			#if TONEMAP == 0
       			mat.albedo = sRGBToAP1Albedo(mat.albedo);
    		#endif

			sceneColor.rgb = computeDiffuse(scenePos, sceneShadowDir, mat, vec4(shadowmap, 1.0), directLightTransmit, skyIlluminance);
			sceneColor.a   = mat.alpha;
		#endif
	}
	
	vec2 encNormal = encodeUnitVector(mat.normal);
	
	dataBuffer.x = packUnorm4x8(vec4(mat.rough, (blockId + 0.25) / maxVal8, clamp01(mat.lightmap)));
	dataBuffer.y = packUnorm4x8(vec4(mat.ao, mat.emission, mat.F0, mat.subsurface));
	dataBuffer.z = (uint(albedoTex.r * maxVal8) << 16u) | (uint(albedoTex.g * maxVal8) << 8u) | uint(albedoTex.b * maxVal8);
	dataBuffer.w = (uint(encNormal.x * maxVal16) << 16u) | uint(encNormal.y * maxVal16);
}
