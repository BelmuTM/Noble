/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#if DOF == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 13 */

        layout (location = 0) out vec3 color;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/common.glsl"

        // https://en.wikipedia.org/wiki/Circle_of_confusion#Determining_a_circle_of_confusion_diameter_from_the_object_field
        float getCoC(float fragDepth, float targetDepth) {
            return fragDepth <= MC_HAND_DEPTH ? 0.0 : abs((FOCAL / F_STOPS) * ((FOCAL * (targetDepth - fragDepth)) / (fragDepth * (targetDepth - FOCAL)))) * 0.5;
        }

        void depthOfField(inout vec3 color, sampler2D tex, vec2 coords, float coc) {
            color = vec3(0.0);

            float weight = pow2(DOF_SAMPLES);
            float totalWeight = 0.0;

            float distFromCenter = distance(coords, vec2(0.5));
            vec2  caOffset       = vec2(distFromCenter) * coc / weight;

            for(float angle = 0.0; angle < TAU; angle += TAU / DOF_ANGLE_SAMPLES) {
                for(int i = 0; i < DOF_SAMPLES; i++) {
                    vec2 sampleCoords = coords + vec2(cos(angle), sin(angle)) * i * coc * texelSize;
                    if(saturate(sampleCoords) != sampleCoords) continue;

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

        void main() {
            float depth0 = linearizeDepthFast(texelFetch(depthtex0, ivec2(gl_FragCoord.xy), 0).r);

            #if DOF_DEPTH == 0
                float targetDepth = linearizeDepthFast(texture(depthtex0, vec2(RENDER_SCALE * 0.5)).r);
            #else
                float targetDepth = float(DOF_DEPTH);
            #endif

            depthOfField(color, DEFERRED_BUFFER, vertexCoords, getCoC(depth0, targetDepth));
        }
    #endif
#endif
