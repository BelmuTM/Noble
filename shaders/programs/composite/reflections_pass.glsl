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
    
        layout (location = 0) out vec3 reflections;

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

            float depth = texture(depthtex0, vertexCoords).r;

            if(depth == 1.0) { discard; return; }

            Material material = getMaterial(vertexCoords);
            vec3 currPosition = vec3(textureCoords, depth);
            vec3 viewPosition = screenToView(currPosition);
                    
            #if REFLECTIONS_TYPE == 0
                reflections.rgb = computeSmoothReflections(viewPosition, material);
            #else
                reflections.rgb = computeRoughReflections(viewPosition, material);
            #endif

            reflections.rgb = clamp16(reflections.rgb);

            vec2 prevCoords = vertexCoords + getVelocity(currPosition).xy * RENDER_SCALE;
            vec3 prevColor  = texture(REFLECTIONS_BUFFER, prevCoords).rgb;

            if(!any(isnan(prevColor)) && currPosition.z >= handDepth) {
                float frames = 0.0;
                if(material.id != WATER_ID) frames = texture(ACCUMULATION_BUFFER, prevCoords).a;

                #if GI == 1
                    frames *= 0.3;
                #endif

                float weight = 1.0 / max(frames, 1.0);
                reflections  = mix(prevColor, reflections.rgb, weight);
            } else {
                reflections  = reflections.rgb;
            }
        }
    #endif
#endif
