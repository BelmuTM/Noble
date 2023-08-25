/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#if REFLECTIONS == 0
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 2 */
    
        layout (location = 0) out vec4 reflections;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/common.glsl"

        #include "/include/atmospherics/constants.glsl"

        #include "/include/utility/phase.glsl"

        #include "/include/fragment/brdf.glsl"
    
        #include "/include/atmospherics/celestial.glsl"

        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/reflections.glsl"

        void main() {
            vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	        if(saturate(fragCoords) != fragCoords) { discard; return; }

            if(isSky(vertexCoords)) { discard; return; }

            Material material = getMaterial(vertexCoords);
            vec3 viewPosition = getViewPosition0(textureCoords);
                    
            #if REFLECTIONS_TYPE == 0
                reflections.rgb = computeSmoothReflections(viewPosition, material);
            #else
                reflections.rgb = computeRoughReflections(viewPosition, material);
            #endif

            reflections.rgb = clamp16(reflections.rgb);

            vec3 currPosition = vec3(textureCoords, texture(depthtex0, vertexCoords).r);
            vec2 prevCoords   = vertexCoords + getVelocity(currPosition).xy * RENDER_SCALE;
            vec3 prevColor    = logLuvDecode(texture(REFLECTIONS_BUFFER, prevCoords));

            if(!any(isnan(prevColor)) && !isHand(vertexCoords)) {
                float frames  = texture(ACCUMULATION_BUFFER, prevCoords).a;
                      frames *= (1.0 - material.roughness);

                #if GI == 1
                    frames *= 0.3;
                #endif

                float weight = 1.0 / max(frames, 1.0);
                reflections  = logLuvEncode(mix(prevColor, reflections.rgb, weight));
            } else {
                reflections  = logLuvEncode(reflections.rgb);
            }
        }
    #endif
#endif
