/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"

#if REFLECTIONS == 0
    #include "/programs/discard.glsl"
#else
    #include "/include/taau_scale.glsl"

    #if defined STAGE_VERTEX
        #if defined WORLD_OVERWORLD && CLOUDS_LAYER0_ENABLED == 1 || defined WORLD_OVERWORLD && CLOUDS_LAYER1_ENABLED == 1
            #include "/include/common.glsl"

            #include "/include/utility/phase.glsl"
            #include "/include/atmospherics/constants.glsl"
        
            #include "/include/atmospherics/atmosphere.glsl"
        #endif

        out vec2 textureCoords;
        out vec2 vertexCoords;
        out vec3 directIlluminance;
        out vec3 skyIlluminance;

        void main() {
            gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
            gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
            textureCoords  = gl_Vertex.xy;
            vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

            #if defined WORLD_OVERWORLD && CLOUDS_LAYER0_ENABLED == 1 || defined WORLD_OVERWORLD && CLOUDS_LAYER1_ENABLED == 1
                directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
                skyIlluminance    = evaluateUniformSkyIrradianceApproximation();
            #endif
        }

    #elif defined STAGE_FRAGMENT

        /* RENDERTARGETS: 2 */
    
        layout (location = 0) out vec3 reflections;

        in vec2 textureCoords;
        in vec2 vertexCoords;
        in vec3 directIlluminance;
        in vec3 skyIlluminance;

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

            bool  dhFragment = false;
            float depth      = texture(depthtex0, vertexCoords).r;

			mat4 projection        = gbufferProjection;
			mat4 projectionInverse = gbufferProjectionInverse;

            #if defined DISTANT_HORIZONS
                if(depth >= 1.0) {
                    dhFragment = true;
                    depth      = texture(dhDepthTex0, vertexCoords).r;
                    
                    projection        = dhProjection;
                    projectionInverse = dhProjectionInverse;
                }
            #endif

            if(depth == 1.0) { discard; return; }

            Material material   = getMaterial(vertexCoords);
            vec3 screenPosition = vec3(textureCoords, depth);
            vec3 viewPosition   = screenToView(screenPosition, projectionInverse, true);
                    
            #if REFLECTIONS == 1
                reflections = computeRoughReflections(dhFragment, projection, viewPosition, material);
            #elif REFLECTIONS == 2
                reflections = computeSmoothReflections(dhFragment, projection, viewPosition, material);
            #endif
        }
        
    #endif
#endif
