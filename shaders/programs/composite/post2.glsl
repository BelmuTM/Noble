/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* DRAWBUFFERS:0 */

layout (location = 0) out vec4 color;

#include "/include/utility/blur.glsl"
#include "/include/post/bloom.glsl"
#include "/include/post/exposure.glsl"

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float cursorDepth) {
        return fragDepth < 0.56 ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, vec2 coords, sampler2D tex, int quality, float radius, float coc) {
        vec3 dof   = vec3(0.0);
        vec2 noise = uniformAnimatedNoise(vec2(randF(), randF()));

        vec2 caOffset;

        #if CHROMATIC_ABERRATION == 1
            float distFromCenter = pow2(distance(coords, vec2(0.5)));
                  caOffset       = vec2(ABERRATION_STRENGTH * distFromCenter) * coc / pow2(quality);
        #endif

        for(int i = 0; i < quality; i++) {
            for(int j = 0; j < quality; j++) {
                vec2 offset = ((vec2(i, j) + noise) - quality * 0.5) / quality;
            
                if(length(offset) < 0.5) {
                    vec2 sampleCoords = coords + (offset * radius * coc * pixelSize);

                    #if CHROMATIC_ABERRATION == 1
                        dof += vec3(
                            texture(tex, sampleCoords + caOffset).r,
                            texture(tex, sampleCoords).g,
                            texture(tex, sampleCoords - caOffset).b
                        );
                    #else
                        dof += texture(tex, sampleCoords).rgb;
                    #endif
                }
            }
        }
        color = dof * (1.0 / pow2(quality));
    }
#endif

#if UNDERWATER_DISTORTION == 1
    void underwaterDistortion(inout vec2 coords) {
        const float scale = 25.0;
        float speed   = frameTimeCounter * WATER_DISTORTION_SPEED;
        float offsetX = coords.x * scale + speed;
        float offsetY = coords.y * scale + speed;

        vec2 distorted = coords + vec2(
            WATER_DISTORTION_AMPLITUDE * cos(offsetX + offsetY) * 0.01 * cos(offsetY),
            WATER_DISTORTION_AMPLITUDE * sin(offsetX - offsetY) * 0.01 * sin(offsetY)
        );

        coords = clamp01(distorted) != distorted ? coords : distorted;
    }
#endif

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
#if PURKINJE == 1
    void purkinje(inout vec3 color, float exposure) {
        vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);
        vec3 xyzColor    = linearToXYZ(color);

        vec3 scotopicLuma = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje    = dot(rodResponse, XYZToLinear(scotopicLuma));

        color = max0(mix(color, purkinje * vec3(0.56, 0.67, 1.0), exp2(-purkinje * 20.0 * exposure)));
    }
#endif


#if CHROMATIC_ABERRATION == 1
    void chromaticAberration(inout vec3 color, float coc) {
        #if DOF == 0
            vec2 offset = (1.0 - pow2(texCoords - vec2(0.5))) * ABERRATION_STRENGTH * pixelSize;

            color = vec3(
                texture(colortex0, texCoords + offset).r,
                texture(colortex0, texCoords).g,
                texture(colortex0, texCoords - offset).b
            );
        #endif
    }
#endif

#if TONEMAP >= 0
    void tonemap(inout vec3 color) {
        #if TONEMAP == 0
            whitePreservingReinhard(color, 2.0); // Reinhard
        #elif TONEMAP == 1
            uncharted2(color);                   // Uncharted 2
        #elif TONEMAP == 2
            lottes(color);                       // Lottes
        #elif TONEMAP == 3
            uchimura(color);                     // Uchimura
        #elif TONEMAP == 4
            burgess(color);                      // Burgess
        #elif TONEMAP == 5
            ACESFitted(color);                   // ACES Fitted
        #elif TONEMAP == 6
            ACESApprox(color);                   // ACES Approximation
        #endif
    }
#endif

#if LUT > 0
    const int lutCount     = 15;
    const int lutTile      = 8;
    const int lutSize      = lutTile * lutTile;
    const int lutRes       = lutSize * lutTile;
    const float invLutTile = 1.0 / lutTile;

    // LUT grid concept from Raspberry shaders (https://rutherin.netlify.app/)
    const vec2 invRes = 1.0 / vec2(lutRes, lutRes * lutCount);
    const mat2 lutGrid = mat2(
        vec2(1.0, invRes.y * lutRes),
        vec2(0.0, (LUT - 1) * invRes.y * lutRes)
    );

    // https://developer.nvidia.com/gpugems/gpugems2/part-iii-high-quality-rendering/chapter-24-using-lookup-tables-accelerate-color
    void applyLUT(sampler2D lookupTable, inout vec3 color) {
        color = clamp(color, vec3(0.03), vec3(255.0 / 256.0));

        color.b *= lutSize - 1.0;
        int b0 = int(color.b);
        int b1 = b0 + 1;

        vec2 off0 = vec2(mod(b0, lutTile), b0 / lutTile) * invLutTile;
        vec2 off1 = vec2(mod(b1, lutTile), b1 / lutTile) * invLutTile;

        color = mix(
            texture(lookupTable, (off0 + color.rg * invLutTile) * lutGrid[0] + lutGrid[1]).rgb,
            texture(lookupTable, (off1 + color.rg * invLutTile) * lutGrid[0] + lutGrid[1]).rgb,
            fract(color.b)
        );
    }
#endif

void main() {
    vec2 tempCoords = texCoords;
    #if UNDERWATER_DISTORTION == 1
        if(isEyeInWater == 1) underwaterDistortion(tempCoords);
    #endif
    
    color          = texture(colortex0, tempCoords);
    float exposure = computeExposure(texture(colortex8, texCoords).a);

    float coc = 1.0;
    #if DOF == 1
        coc = getCoC(linearizeDepth(texture(depthtex0, texCoords).r), linearizeDepth(centerDepthSmooth));
        depthOfField(color.rgb, texCoords, colortex0, 8, DOF_RADIUS, coc);
    #endif

    #if CHROMATIC_ABERRATION == 1
        chromaticAberration(color.rgb, coc);
    #endif

    #if BLOOM == 1
        float bloomStrength = min(BLOOM_STRENGTH + rainStrength, 1.0);
        color.rgb          += readBloom() * exp2(exposure - 3.0 + bloomStrength);
    #endif

    #if FILM_GRAIN == 1
        color.rgb += randF() * color.rgb * FILM_GRAIN_STRENGTH;
    #endif

    #if PURKINJE == 1
        purkinje(color.rgb, exposure);
    #endif
    
    // Tonemapping & Color Correction

    color.rgb *= exposure;

    whiteBalance(color.rgb);
    vibrance(color.rgb,   1.0 + VIBRANCE);
    saturation(color.rgb, 1.0 + SATURATION);
    contrast(color.rgb,   1.0 + CONTRAST);
    liftGammaGain(color.rgb, LIFT * 0.1, 1.0 + GAMMA, 1.0 + GAIN);

    #if TONEMAP >= 0
        tonemap(color.rgb);
    #endif

    color.rgb = clamp01(color.rgb);
    color     = TONEMAP == 4 ? color : linearToRGB(color);

    #if LUT > 0
        applyLUT(colortex9, color.rgb);
    #endif

    color.rgb += bayer64(gl_FragCoord.xy) / 64.0;
}
