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

uniform vec3 cameraPosition;
uniform sampler2D depthtex0;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;

void main() {
	//Sample textures
	vec4 albedo_tex = texture2D(texture, texCoords);
	vec4 normal_tex = texture2D(normals, texCoords) * 2.0 - 1.0;
	vec4 specular_tex = texture2D(specular, texCoords);	

	if(albedo_tex.a < 0.1) discard;
	albedo_tex.rgb *= color.rgb;
	
	//Normals
	vec3 normal;
	normal.xy = normal_tex.xy;
	normal.z = sqrt(1.0 - dot(normal.xy, normal.xy)); //Reconstruct Z
	normal = clamp(normal, -1.0, 1.0); //Clamp into right range
	normal = tbn_matrix * normal; //Rotate by TBN matrix
	
    float roughness = pow(1.0 - specular_tex.x, 2.0);
	float F0 = specular_tex.y;
	vec2 lightmap = lmCoords.xy;

	if(int(blockId) == 6) {
		albedo_tex = vec4(0.259, 0.608, 0.961, 0.5);
	}
	
    /* DRAWBUFFERS:0123 */
	gl_FragData[0] = albedo_tex;
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
	gl_FragData[2] = vec4(clamp(roughness, 0.001, 1.0), F0, lightmap);
	gl_FragData[3] = vec4(blockId / 255.0);
}