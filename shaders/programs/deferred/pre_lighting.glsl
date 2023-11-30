/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
    #include "/include/utility/phase.glsl"
	#include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec2 vertexCoords;
    out vec3 directIlluminance;
    out vec3[9] skyIrradiance;
    out vec3 uniformSkyIlluminance;

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

		#if defined WORLD_OVERWORLD || defined WORLD_END
			directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;

            #if GI == 0
			    skyIrradiance = sampleUniformSkyIrradiance();
            #endif

            uniformSkyIlluminance = evaluateUniformSkyIrradianceApproximation();
		#endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,5 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec4 illuminance;
    //layout (location = 2) out vec4 depth;

    in vec2 textureCoords;
    in vec2 vertexCoords;
    in vec3 directIlluminance;
    in vec3[9] skyIrradiance;
    in vec3 uniformSkyIlluminance;

    #if defined WORLD_OVERWORLD && SHADOWS == 1
        #include "/include/fragment/shadows.glsl"
    #endif

    #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    /*
    float computeLowerHiZDepthLevels() {
        float tiles = 0.0;

        for(int i = 1; i < HIZ_LOD_COUNT; i++) {
            int scale   = int(exp2(i)); 
	        vec2 coords = (textureCoords - hiZOffsets[i - 1]) * scale;
                 tiles += find2x2MinimumDepth(coords, scale);
        }
        return tiles;
    }
    */

    void main() {
        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	    if(saturate(fragCoords) != fragCoords) discard;

        Material material = getMaterial(vertexCoords);

        //depth.a = computeLowerHiZDepthLevels();

        //////////////////////////////////////////////////////////
        /*--------------------- IRRADIANCE ---------------------*/
        //////////////////////////////////////////////////////////

        vec3 skyIlluminance = vec3(0.0);

        #if defined WORLD_OVERWORLD || defined WORLD_END
            bool receivesSkylight = true;

            #if defined WORLD_OVERWORLD
                receivesSkylight = material.lightmap.y > EPS;
            #endif

            if(receivesSkylight) {
                #if GI == 0
                    vec4 ao = vec4(material.normal, 1.0);
                    #if AO == 1 && AO_TYPE == 1 || AO == 1 && AO_TYPE == 2
                        vec3 aoBuffer = texture(AO_BUFFER, vertexCoords).rgb;

                        ao.xyz = decodeUnitVector(aoBuffer.xy);
                        ao.w   = aoBuffer.z;
                    #endif

                    skyIlluminance = max0(evaluateDirectionalSkyIrradiance(skyIrradiance, ao.xyz, ao.w));
                #else
                    skyIlluminance = uniformSkyIlluminance;
                #endif
            }
        #endif

        if(ivec2(gl_FragCoord.xy) == ivec2(0))
            illuminance.rgb = directIlluminance;
        else
            illuminance.rgb = skyIlluminance;
                
        //////////////////////////////////////////////////////////
        /*----------------- SHADOW MAPPING ---------------------*/
        //////////////////////////////////////////////////////////
            
        #if defined WORLD_OVERWORLD
            #if SHADOWS == 1
                if(material.depth0 != 1.0) {
                    vec3 geoNormal = decodeUnitVector(texture(SHADOWMAP_BUFFER, vertexCoords).rg);
                    vec3 scenePos  = viewToScene(screenToView(vec3(textureCoords, material.depth0)));
                    shadowmap.rgb  = calculateShadowMapping(scenePos, geoNormal, shadowmap.a);
                    shadowmap.rgb  = abs(shadowmap.rgb) * material.parallaxSelfShadowing;
                }
            #endif

            #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                illuminance.a = calculateCloudsShadows(getCloudsShadowPosition(gl_FragCoord.xy, atmosphereRayPosition), shadowLightVector, cloudLayer0, 20);
            #endif
        #endif

        if(ivec2(gl_FragCoord.xy) == ivec2(0))
            shadowmap.rgb = uniformSkyIlluminance;
    }
#endif
