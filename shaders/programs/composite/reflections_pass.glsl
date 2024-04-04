/***********************************************/
/*          Copyright (C) 2024 Belmu           */
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

            sampler2D depthTex = depthtex0;
            float     depth    = texture(depthtex0, vertexCoords).r;

			mat4 projection        = gbufferProjection;
			mat4 projectionInverse = gbufferProjectionInverse;

            #if defined DISTANT_HORIZONS
                if(depth >= 1.0) {
                    depthTex = dhDepthTex0;
                    depth    = texture(dhDepthTex0, vertexCoords).r;
                    
                    projection        = dhProjection;
                    projectionInverse = dhProjectionInverse;
                }
            #endif

            if(depth == 1.0) { discard; return; }

            Material material = getMaterial(vertexCoords);
            vec3 currPosition = vec3(textureCoords, depth);
            vec3 viewPosition = screenToView(currPosition, projectionInverse, true);
                    
            #if REFLECTIONS == 1
                reflections = computeRoughReflections(depthTex, projection, viewPosition, material);
            #elif REFLECTIONS == 2
                reflections = computeSmoothReflections(depthTex, projection, viewPosition, material);
            #endif

            reflections = clamp16(reflections);
        }
        
    #endif
#endif
