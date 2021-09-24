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
#include "/lib/post/exposure.glsl"

void main() {
    vec4 Result = texture(colortex0, texCoords);
    float depth = texture(depthtex0, texCoords).r;

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
        // I wasn't supposed to use magic numbers like this in Noble :Sadge:
        Result.rgb += saturate(readBloom() * mix(0.06 + (rainStrength * 0.1), 0.0, 0.3) * BLOOM_STRENGTH);
    #endif

    // Vignette
    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        Result.rgb *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);

        //float diff = 0.55 - distance(texCoords, vec2(0.5));
	    //Result.rgb *= smoothstep(-0.20, 0.20, diff);
    #endif
    
    // Tonemapping
    Result.rgb *= computeExposure(texture(colortex7, pixelSize).r);

    #if TONEMAPPING == 0
        Result.rgb = whitePreservingReinhard(Result.rgb); // Reinhard
    #elif TONEMAPPING == 1
        Result.rgb = uncharted2(Result.rgb); // Uncharted 2
    #elif TONEMAPPING == 2
        Result.rgb = burgess(Result.rgb); // Burgess
    #elif TONEMAPPING == 3
        Result.rgb = ACESFitted(Result.rgb); // ACES
    #endif

    Result.rgb = vibrance_saturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = adjustContrast(Result.rgb, CONTRAST) + BRIGHTNESS;

    Result.rgb += bayer2(gl_FragCoord.xy) * (1.0 / 256.0); // Removes color banding from the screen
    #if TONEMAPPING != 2
        Result = linearToSRGB(Result);
    #endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = Result;
}
