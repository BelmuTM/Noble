/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/* RENDERTARGETS: 0,4,10 */

layout (location = 0) out vec3 color;
layout (location = 1) out vec3 bloomBuffer;
layout (location = 2) out vec4 previousBuffer;

#include "/include/utility/blur.glsl"
#include "/include/post/bloom.glsl"

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float cursorDepth) {
        return fragDepth < 0.56 ? 0.0 : abs((FOCAL / APERTURE) * ((FOCAL * (cursorDepth - fragDepth)) / (fragDepth * (cursorDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, vec2 coords, sampler2D tex, int quality, float radius, float coc) {
        vec3 dof   = vec3(0.0);
        vec2 noise = vec2(randF(rngState), randF(rngState));
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

void main() {
    color        = texture(colortex0, texCoords).rgb;
    Material mat = getMaterial(texCoords);
    
    #if DOF == 1
        float coc = getCoC(linearizeDepthFast(mat.depth1), linearizeDepthFast(centerDepthSmooth));
        depthOfField(color, texCoords, colortex0, 8, DOF_RADIUS, coc);
    #endif

    #if BLOOM == 1
        bloomBuffer = clamp16(writeBloom());
    #endif

    #if VL == 1
        #if VL_FILTER == 1
            color += gaussianBlur(texCoords, colortex7, 1.5, 2.0, 4).rgb;
        #else
            color += texture(colortex7, texCoords).rgb;
        #endif
    #endif

    previousBuffer = vec4(mat.normal * 0.5 + 0.5, mat.depth0);
}
