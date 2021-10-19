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
#include "/lib/post/bloom.glsl"
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

    return clamp01(distorted) != distorted ? coords : distorted;
} 

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
vec3 purkinje(vec3 color) {
    vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);
    vec3 xyzColor = linearToXYZ(color);

    vec3 scotopicLuma = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
    float purkinje = dot(rodResponse, XYZtoLinear(scotopicLuma));

    return mix(color, purkinje * vec3(0.5, 0.7, 1.0), exp2(-purkinje * 100.0));
}

vec3 computeAberration(vec3 color) {
    float depth = linearizeDepth(texture(depthtex0, texCoords).r);
    float coc = getCoC(depth, linearizeDepth(centerDepthSmooth));
    vec2 offset = coc * ABERRATION_STRENGTH * pixelSize;

    return vec3(
        texture(colortex0, texCoords + offset).r,
        texture(colortex0, texCoords).g,
        texture(colortex0, texCoords - offset).b
    );
}

void tonemap(inout vec3 color) {
    #if TONEMAPPING == 0
        color = whitePreservingReinhard(color); // Reinhard
    #elif TONEMAPPING == 1
        color = uncharted2(color); // Uncharted 2
    #elif TONEMAPPING == 2
        color = burgess(color); // Burgess
    #elif TONEMAPPING == 3
        color = ACESFitted(color); // ACES
    #endif
}

void main() {
    vec2 tempCoords = texCoords;
    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) tempCoords = underwaterDistortionCoords(tempCoords);
    #endif
    
    vec4 Result = texture(colortex0, tempCoords);

    #if CHROMATIC_ABERRATION == 1
        Result.rgb = computeAberration(Result.rgb);
    #endif

    #if BLOOM == 1
        // I wasn't supposed to use magic numbers like this in Noble :Sadge:
        Result.rgb += clamp01(readBloom().rgb * 0.01 * clamp01(BLOOM_STRENGTH + clamp(rainStrength, 0.0, 0.5)));
    #endif

    #if PURKINJE == 1
        Result.rgb = purkinje(Result.rgb);
    #endif
    
    // Tonemapping & Color Correction
    vec3 finalCol = Result.rgb * max(0.0, computeExposure(texture(colortex7, texCoords).r));
    tonemap(finalCol);
    finalCol = vibranceSaturation(finalCol, VIBRANCE, SATURATION);
    finalCol = contrast(finalCol, CONTRAST) + BRIGHTNESS;

    // Vignette
    #if VIGNETTE == 1
        vec2 coords = texCoords * (1.0 - texCoords.yx);
        finalCol *= pow(coords.x * coords.y * 15.0, VIGNETTE_STRENGTH);
    #endif

    finalCol = linearToSRGB(vec4(finalCol, 1.0)).rgb;

    /*DRAWBUFFERS:0*/
    finalCol += bayer64(gl_FragCoord.xy) / 255.0;
    gl_FragData[0] = vec4(finalCol, 1.0);
}
