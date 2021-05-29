/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec4 color;
varying mat3 tbn_matrix;
varying float blockId;
varying vec3 viewPos;

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;

void main() {
	//Sample textures
	vec4 albedo_tex = texture2D(texture, texCoords);
	vec4 normal_tex = texture2D(normals, texCoords);
	vec4 specular_tex = texture2D(specular, texCoords);	
	
	//Normals
	vec3 normal;
	normal.xy = normal_tex.xy * 2.0 - 1.0;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy)); //Reconstruct Z
	normal = clamp(normal, -1.0, 1.0); //Clamp into right range
	normal = tbn_matrix * normal; //Rotate by TBN matrix
	
    float roughness = pow(1.0 - specular_tex.x, 2.0);
	float F0 = specular_tex.y;
    bool is_metal = (specular_tex.y * 255.0) > 229.5;
	vec2 lightmap = lmCoords.xy;

	vec4 Result = albedo_tex * color;

	if(int(blockId) == 6) {
		/*
		vec3 depthWorldPos = vec3(texCoords, texture2D(depthtex0, texCoords).r) * 2.0 - 1.0;
        float waterAlpha = 1.0 - exp2(-(0.9 / log(2.0)) * distance(depthWorldPos, mat3(gbufferModelViewInverse) * viewPos));
		*/
        Result = vec4(0.345, 0.58, 0.62, 0.65);
	}
	
    /* DRAWBUFFERS:0123 */
	gl_FragData[0] = Result;
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
	gl_FragData[2] = vec4(roughness, F0, lightmap);
	gl_FragData[3] = vec4(blockId / 255.0);
}