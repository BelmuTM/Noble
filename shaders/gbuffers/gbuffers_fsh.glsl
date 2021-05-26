/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

varying vec2 texCoords;
varying vec2 lmCoords;
varying vec4 color;
varying mat3 tbn_matrix;

uniform sampler2D lightmap;
uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;

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
	
    /* DRAWBUFFERS:0123 */
	gl_FragData[0] = albedo_tex * color;
	gl_FragData[1] = vec4(normal * 0.5 + 0.5, 1.0);
	gl_FragData[2] = vec4(roughness, F0, lightmap);
	gl_FragData[3] = vec4(0.0);
}