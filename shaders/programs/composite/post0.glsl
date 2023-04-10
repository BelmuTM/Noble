/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 4,3 */

layout (location = 0) out vec4 color;
layout (location = 1) out vec3 bloomBuffer;

#include "/include/common.glsl"

#if BLOOM == 1
    #include "/include/utility/sampling.glsl"
    #include "/include/post/bloom.glsl"
#endif

#if DOF == 1
    // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
    float getCoC(float fragDepth, float targetDepth) {
        return fragDepth < MC_HAND_DEPTH ? 0.0 : abs((FOCAL / F_STOPS) * ((FOCAL * (targetDepth - fragDepth)) / (fragDepth * (targetDepth - FOCAL)))) * 0.5;
    }

    void depthOfField(inout vec3 color, sampler2D tex, float coc) {
        color = vec3(0.0);

        float weight = pow2(DOF_SAMPLES);
        float totalWeight = 0.0;

        float distFromCenter = distance(texCoords, vec2(0.5));
        vec2  caOffset       = vec2(distFromCenter) * coc / weight;

        for(float angle = 0.0; angle < TAU; angle += TAU / DOF_ANGLE_SAMPLES) {
            for(int i = 0; i < DOF_SAMPLES; i++) {
                vec2 sampleCoords = texCoords + vec2(cos(angle), sin(angle)) * i * coc * pixelSize;
                if(clamp01(sampleCoords) != sampleCoords) continue;

                vec3 sampleColor  = vec3(
                    texture(tex, sampleCoords + caOffset).r,
                    texture(tex, sampleCoords).g,
                    texture(tex, sampleCoords - caOffset).b
                );

                color       += sampleColor * weight;
                totalWeight += weight;
            }
        }
        color /= totalWeight;
    }
#endif

void main() {
    color = texture(colortex4, texCoords);
    
    #if DOF == 1
        float depth0 = linearizeDepthFast(texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r);

        #if DOF_DEPTH == 0
            float targetDepth = linearizeDepthFast(centerDepthSmooth);
        #else
            float targetDepth = float(DOF_DEPTH);
        #endif

        depthOfField(color.rgb, colortex4, getCoC(depth0, targetDepth));
    #endif

    #if BLOOM == 1
        writeBloom(bloomBuffer);
    #endif

    #if EXPOSURE > 0
        color.a = sqrt(luminance(color.rgb));
    #endif

    vec4 basic     = texture(colortex15, texCoords);
         color.rgb = mix(color.rgb, basic.rgb, basic.a);
}
