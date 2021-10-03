/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/settings.glsl"
#include "/programs/common.glsl"
#include "/lib/util/blur.glsl"
#include "/lib/post/aberration.glsl"
#include "/lib/post/bloom.glsl"
#include "/lib/post/dof.glsl"
#include "/lib/post/exposure.glsl"

vec2 underwaterDistortionCoords(vec2 coords) {
    const float scale = 25.0;
    float speed = frameTimeCounter * WATER_DISTORTION_SPEED;
    float offsetX = coords.x * scale + speed;
    float offsetY = coords.y * scale + speed;

    vec2 distorted = coords + vec2(
        WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
        WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
    );

    return saturate(distorted) != distorted ? coords : distorted;
} 

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinje(vec3 color) {
    vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);
    vec3 xyzColor = linearToXYZ(color);

    vec3 scotopicLuma = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
    float purkinje = dot(rodResponse, XYZtoLinear(scotopicLuma));

    return mix(color, purkinje * vec3(0.5, 0.7, 1.0), exp2(-purkinje * 20.0));
}

void main() {
    vec2 tempCoords = texCoords;
    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) tempCoords = underwaterDistortionCoords(tempCoords);
    #endif

    vec4 Result = texture(colortex0, tempCoords);
    float depth = texture(depthtex0, tempCoords).r;

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
        Result.rgb += saturate(readBloom() * 0.05 * saturate(BLOOM_STRENGTH + clamp(rainStrength, 0.0, 0.5)));
    #endif

    // Purkinje
    #if PURKINJE == 1
        Result.rgb = purkinje(Result.rgb);
    #endif
    
    // Tonemapping
    vec3 exposedColor = Result.rgb * computeExposure(texture(colortex7, texCoords).r);
    #if TONEMAPPING == 0
        Result.rgb = whitePreservingReinhard(exposedColor); // Reinhard
    #elif TONEMAPPING == 1
        Result.rgb = uncharted2(exposedColor); // Uncharted 2
    #elif TONEMAPPING == 2
        Result.rgb = burgess(exposedColor); // Burgess
    #elif TONEMAPPING == 3
        Result.rgb = ACESFitted(exposedColor); // ACES
    #endif

    Result.rgb = vibrance_saturation(Result.rgb, VIBRANCE, SATURATION);
    Result.rgb = adjustContrast(Result.rgb, CONTRAST) + BRIGHTNESS;

    // Vignette
    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        Result.rgb *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    Result.rgb += bayer2(gl_FragCoord.xy) * (1.0 / 255.0); // Removes color banding from the screen
    #if TONEMAPPING != 2
        Result = linearToSRGB(Result);
    #endif

    /*DRAWBUFFERS:0*/
    gl_FragData[0] = Result;
}
