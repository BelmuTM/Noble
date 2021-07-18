/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;
varying vec4 color;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"

float drawCircle(vec2 coords, float radius) {
    return step(length(coords), radius);
}

void main() {
	const vec3 sunColor = vec3(1.0, 0.6, 0.05);

	float angle = 1.0 - distance(texCoords, sunPosition.xy);
	vec3 Result = skyColor + (sunColor * angle);
	
  	gl_FragData[0] = vec4(skyColor, 1.0);
}
