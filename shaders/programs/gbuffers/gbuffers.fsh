/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
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
#include "/lib/frag/dither.glsl"
#include "/lib/util/math.glsl"

#ifdef ENTITY
uniform vec4 entityColor;
#endif

/*
const int colortex0Format = RGBA16F;
const int colortex1Format = RGBA16F;
*/

void main() {
	vec4 albedoTex = texture2D(texture, texCoords);
	vec4 normalTex = texture2D(normals, texCoords);
	vec4 specularTex = texture2D(specular, texCoords);

	if(albedoTex.a < 0.1) discard;
	albedoTex *= color;

	#ifdef ENTITY
		// Alpha blending on entities
		albedoTex.rgb = mix(albedoTex.rgb, entityColor.rgb, entityColor.a);
	#endif
	
	vec3 normal;
	normal.xy = normalTex.xy * 2.0 - 1.0;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy)); // Reconstruct Z
	normal = clamp(normal, -1.0, 1.0); // Clamping to the right range
	normal = TBN * normal; // Rotate by TBN matrix

	float ao = normalTex.z;
    	float roughness = pow(1.0 - specularTex.x, 2.0);
	float F0 = specularTex.y;
	bool isMetal = (F0 * 255.0) > 229.5;
	vec2 lightmap = lmCoords.xy;
	float emission = (specularTex.w * 255.0) < 254.5 ? specularTex.w : 0.0;

	if(int(blockId) == 1) albedoTex.a = WATER_COLOR.a;
	
	/*DRAWBUFFERS:0123*/
	gl_FragData[0] = albedoTex;
	gl_FragData[1] = vec4(encodeNormal(normal), emission, ao);
	gl_FragData[2] = vec4(clamp(roughness, EPS, 1.0), F0, lightmap);
	gl_FragData[3] = vec4(blockId / 255.0);
}
