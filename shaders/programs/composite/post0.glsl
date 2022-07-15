/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 4,3,9 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec3 bloomBuffer;
layout (location = 2) out vec4 previousBuffer;

#include "/include/post/bloom.glsl"
#include "/include/post/taa.glsl"

/*
        vec3 filterVL(sampler2D tex, vec2 coords, Material mat, float radius, float sigma, int steps) {
            vec3 color = vec3(0.0);

            for(int x = -steps; x <= steps; x++) {
                for(int y = -steps; y <= steps; y++) {
                    vec2 sampleCoords = coords + vec2(x, y) * radius * pixelSize;
                    if(clamp01(sampleCoords) != sampleCoords) continue;

                    float weight = gaussianDistrib2D(vec2(x, y), sigma);
                    color       += texelFetch(tex, ivec2(sampleCoords * viewSize), 0).rgb * weight;
                }
            }
            return color;
        }
*/

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float cursorDepth) {
        return fragDepth < MC_HAND_DEPTH ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, sampler2D tex, vec2 coords, int quality, float radius, float coc) {
        vec3 dof   = vec3(0.0);
        vec2 noise = vec2(randF(), randF());
        vec2 caOffset;

        #if CHROMATIC_ABERRATION == 1
            float distFromCenter = pow2(distance(coords, vec2(0.5)));
                  caOffset       = vec2(ABERRATION_STRENGTH * distFromCenter) * coc / pow2(quality);
        #endif

        for(int x = 0; x < quality; x++) {
            for(int y = 0; y < quality; y++) {
                vec2 offset = ((vec2(x, y) + noise) - quality * 0.5) * rcp(quality);
            
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
        color = dof * rcp(pow2(quality));
    }
#endif

void main() {
    color        = texture(colortex4, texCoords);
    Material mat = getMaterial(texCoords);
    
    #if DOF == 1
        float coc = getCoC(linearizeDepthFast(mat.depth1), linearizeDepthFast(centerDepthSmooth));
        depthOfField(color.rgb, colortex4, texCoords, 8, DOF_RADIUS, coc);
    #endif

    #if BLOOM == 1
        writeBloom(bloomBuffer);
    #endif

    color.a        = log2(luminance(color.rgb));
    previousBuffer = vec4(mat.normal * 0.5 + 0.5, mat.depth1);
}
