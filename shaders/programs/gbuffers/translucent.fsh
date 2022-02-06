/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:12 */

layout (location = 0) out vec4 sceneColor;
layout (location = 1) out uvec4 dataBuffer;

flat in int blockId;
in vec2 texCoords;
in vec2 lmCoords;
in vec3 viewPos;
in vec3 waterNormals;
in vec3 skyIlluminance;
in vec3 shadowLightTransmit;
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
    mat.ao         = normalTex.z;
    mat.subsurface = (specularTex.z * 255.0) < 65.0 ? 0.0 : specularTex.z;
    mat.isMetal    = mat.F0 * 255.0 > 229.5;

    mat.albedo = albedoTex.rgb;
    mat.alpha  = albedoTex.a;

    mat.blockId  = blockId;
    mat.lightmap = lmCoords;

	vec3 normal;
	// WOTAH
	if(blockId == 1) { 
		mat.albedo = vec3(1.0);
		mat.alpha  = 0.0;
		mat.F0 	   = 0.02;
		mat.rough  = 0.0;
		normal     = TBN * waterNormals;
		
	} else {
		normal.xy  = normalTex.xy * 2.0 - 1.0;
		normal.z   = sqrt(1.0 - dot(normal.xy, normal.xy));
		normal     = TBN * normal;
		mat.normal = normal;

		#if GI == 0
			vec3 shadowmap = vec3(1.0);
			#if SHADOWS == 1
            	shadowmap = shadowMap(viewPos);
        	#endif

			sceneColor.rgb = applyLighting(viewPos, mat, vec4(shadowmap, 1.0), shadowLightTransmit, skyIlluminance);
			sceneColor.a   = mat.alpha;
		#endif
	}
	
	vec2 encNormal = encodeUnitVector(normal);
	
	dataBuffer.x = packUnorm4x8(vec4(mat.rough, (blockId + 0.25) / 255.0, clamp01(mat.lightmap)));
	dataBuffer.y = packUnorm4x8(vec4(mat.ao, mat.alpha, mat.F0, mat.subsurface));
	dataBuffer.z = (uint(mat.albedo.r * 255.0) << 24u) | (uint(mat.albedo.g * 255.0) << 16u) | (uint(mat.albedo.b * 255.0) << 8u) | uint(encNormal.x * 255.0);
	dataBuffer.w = uint(encNormal.y * 255.0);
}
