/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/fragment/bayer.glsl"
#include "/lib/fragment/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/post/aberration.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/post/dof.glsl"
#include "/lib/post/outline.glsl"
#include "/lib/post/exposure.glsl"

vec3 computeBloom() {
    vec3 color  = getBloomTile(2, vec2(0.0      , 0.0   ));
	     color += getBloomTile(3, vec2(0.0      , 0.26  ));
	     color += getBloomTile(4, vec2(0.135    , 0.26  ));
	     color += getBloomTile(5, vec2(0.2075   , 0.26  ));
	     color += getBloomTile(6, vec2(0.135    , 0.3325));
	     color += getBloomTile(7, vec2(0.160625 , 0.3325));
	     color += getBloomTile(8, vec2(0.1784375, 0.3325));
    return color;
}

void main() {
    vec4 Result = texture2D(colortex0, texCoords);
    float depth = texture2D(depthtex0, texCoords).r;

    // Chromatic Aberration
    #if CHROMATIC_ABERRATION == 1
        Result.rgb = computeAberration(Result.rgb);
    #endif

    // Depth of Field
    #if DOF == 1
        Result.rgb = computeDOF(Result.rgb, depth);
    #endif

    // Bloom
    #if BLOOM == 1
        Result.rgb += clamp(computeBloom() * mix(0.03 + (rainStrength * 0.1), 0.0, 0.3) * BLOOM_STRENGTH, 0.0, 1.0);
    #endif

    // Outline
    #if OUTLINE == 1
        Result = mix(Result, vec4(0.0), clamp(edgeDetection(OUTLINE_THICKNESS), 0.0, OUTLINE_DARKNESS));
    #endif

    // Vignette
    #if VIGNETTE == 1
        float dist = distance(texCoords, vec2(0.5));
        Result.rgb *= smoothstep(0.8, VIGNETTE_FALLOFF * 0.799, dist * (VIGNETTE_STRENGTH + VIGNETTE_FALLOFF));
    #endif
    
    // Tonemapping
    Result.rgb *= computeExposure(texture2D(colortex7, texCoords).r);

    #if TONEMAPPING == 0
        Result.rgb = reinhard_jodie(Result.rgb); // Reinhard
    #elif TONEMAPPING == 1
        Result.rgb = uncharted2(Result.rgb); // Uncharted 2
    #elif TONEMAPPING == 2
        Result.rgb = burgess(Result.rgb); // Burgess
    #elif TONEMAPPING == 3
        Result.rgb = ACESFitted(Result.rgb); // ACES
    #endif

    Result.rgb = vibrance_saturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = adjustContrast(Result.rgb, CONTRAST) + BRIGHTNESS;

    Result.rgb += bayer2(gl_FragCoord.xy) * (1.0 / 255.0); // Removes color banding from the screen

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = toSRGB(Result);
}
