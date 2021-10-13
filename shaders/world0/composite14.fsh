#version 400 compatibility
#include "/programs/extensions.glsl"

/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

varying vec2 texCoords;

#include "/settings.glsl"
#include "/programs/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/atmospherics/fog.glsl"

vec3 computeDOF(vec3 color, float depth) {
    float coc = getCoC(linearizeDepth(depth), linearizeDepth(centerDepthSmooth));
    vec4 outOfFocusColor = bokeh(texCoords, colortex0, pixelSize, 6, DOF_RADIUS);
    return saturate(mix(color, outOfFocusColor.rgb, quintic(0.0, 1.0, coc)));
}

void main() {
     vec3 viewPos = getViewPos(texCoords);
     vec4 Result = texture(colortex0, texCoords);

     vec4 bloom = vec4(0.0);
     #if BLOOM == 1
          bloom = writeBloom();
     #endif

     // Depth of Field
     #if DOF == 1
          float depth = texture(depthtex0, texCoords).r;
          Result.rgb = computeDOF(Result.rgb, depth);
     #endif
     
     Result.rgb += fog(viewPos, vec3(0.0), viewPosSkyColor(viewPos), (rainStrength * float(RAIN_FOG == 1)) + isEyeInWater, 0.03); // Applying Fog

     /*DRAWBUFFERS:05*/
     gl_FragData[0] = Result;
     gl_FragData[1] = bloom;
}
