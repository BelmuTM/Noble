/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/taau_scale.glsl"
#include "/include/common.glsl"

#if REFLECTIONS == 0 || GI == 1
    #include "/programs/discard.glsl"
#else
    #if defined STAGE_VERTEX
        #include "/programs/vertex_taau.glsl"

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 2 */
    
        layout (location = 0) out vec4 reflections;

        in vec2 textureCoords;
        in vec2 vertexCoords;

        #include "/include/atmospherics/constants.glsl"

        #include "/include/fragment/brdf.glsl"
    
        #include "/include/atmospherics/celestial.glsl"

        #include "/include/fragment/raytracer.glsl"
        #include "/include/fragment/reflections.glsl"

        void main() {
            vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	        if(saturate(fragCoords) != fragCoords) { discard; return; }

            if(isSky(vertexCoords)) return;

            Material material  = getMaterial(vertexCoords);
            float depth        = texture(depthtex0, vertexCoords).r;
            vec3  viewPosition = screenToView(vec3(textureCoords, depth));
                    
            #if REFLECTIONS_TYPE == 0
                reflections.rgb = computeSmoothReflections(viewPosition, material);
            #else
                reflections.rgb = computeRoughReflections(viewPosition, material);
            #endif

            vec3 currPosition = vec3(textureCoords, texture(depthtex0, vertexCoords).r);
            vec2 prevCoords   = vertexCoords + getVelocity(currPosition).xy * RENDER_SCALE;
            vec3 prevColor    = logLuvDecode(texture(REFLECTIONS_BUFFER, prevCoords));

            if(!any(isnan(prevColor)) && !isHand(vertexCoords)) {
                float weight = 1.0 / max(texture(LIGHTING_BUFFER, prevCoords).w * (1.0 - material.roughness), 1.0);
                reflections  = logLuvEncode(mix(prevColor, reflections.rgb, weight));
            } else {
                reflections  = logLuvEncode(reflections.rgb);
            }
        }
    #endif
#endif
