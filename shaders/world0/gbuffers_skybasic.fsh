/*
  Author: Belmu (https://github.com/BelmuTM/)
  */

#version 120

varying vec4 Color;

const int GL_LINEAR = 9729;
const int GL_EXP = 2048;

uniform int fogMode;

void main() {
  	gl_FragData[0] = Color;
  	gl_FragData[1] = vec4(vec3(gl_FragCoord.z), 1.0f);

  	if (fogMode == GL_EXP)
  		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, 1.0f - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0f, 1.0f));
  	else if (fogMode == GL_LINEAR)
  		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0f, 1.0f));
}
