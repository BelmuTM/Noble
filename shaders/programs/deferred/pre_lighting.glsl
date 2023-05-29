/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

#include "/include/common.glsl"
#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
	#include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

    out vec3 directIlluminance;
    out vec3[9] skyIrradiance;

    void main() {
        gl_Position   = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        textureCoords = gl_MultiTexCoord0.xy;

		#if defined WORLD_OVERWORLD || defined WORLD_END
			directIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(0), 0).rgb;
			skyIrradiance     = sampleUniformSkyIrradiance();
		#endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,5,12 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec4 illuminance;
    layout (location = 2) out vec4 depth;

    in vec3 directIlluminance;
    in vec3[9] skyIrradiance;

    #if defined WORLD_OVERWORLD && SHADOWS == 1
        #include "/include/fragment/shadows.glsl"
    #endif

    #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    float computeLowerHiZDepthLevels() {
        float tiles = 0.0;

        for(int i = 1; i < HIZ_LOD_COUNT; i++) {
            int scale   = int(exp2(i)); 
	        vec2 coords = (textureCoords - hiZOffsets[i - 1]) * scale;
                 tiles += find2x2MinimumDepth(coords, scale);
        }
        return tiles;
    }

    void main() {
        vec3 viewPosition = getViewPosition0(textureCoords);
        Material material = getMaterial(textureCoords);

        //depth.a = computeLowerHiZDepthLevels();

        //////////////////////////////////////////////////////////
        /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
        //////////////////////////////////////////////////////////

        vec4 ao = vec4(0.0);

        #if GI == 0 && AO == 1
            ao = texture(INDIRECT_BUFFER, textureCoords);
            if(any(greaterThan(ao, vec4(0.0)))) ao = saturate(ao);
        #endif

        //////////////////////////////////////////////////////////
        /*--------------------- IRRADIANCE ---------------------*/
        //////////////////////////////////////////////////////////

        vec3 skyIlluminance = vec3(0.0);

        #if defined WORLD_OVERWORLD || defined WORLD_END
            bool receivesSkylight = true;

            #if defined WORLD_OVERWORLD
                receivesSkylight = material.lightmap.y > EPS;
            #endif

            if(receivesSkylight) skyIlluminance = max0(evaluateDirectionalSkyIrradiance(skyIrradiance, ao.xyz, ao.w));
        #endif

        if(ivec2(gl_FragCoord) == ivec2(0))
            illuminance.rgb = directIlluminance;
        else
            illuminance.rgb = skyIlluminance;
                
        //////////////////////////////////////////////////////////
        /*----------------- SHADOW MAPPING ---------------------*/
        //////////////////////////////////////////////////////////

        if(isSky(textureCoords)) return;
            
        #if defined WORLD_OVERWORLD
            #if SHADOWS == 1
                vec3 geoNormal = decodeUnitVector(texture(SHADOWMAP_BUFFER, textureCoords).rg);
                shadowmap.rgb  = calculateShadowMapping(viewToScene(viewPosition), geoNormal, shadowmap.a);
                shadowmap.rgb  = abs(shadowmap.rgb) * material.parallaxSelfShadowing;
            #endif

            #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                illuminance.a = calculateCloudsShadows(getCloudsShadowPosition(gl_FragCoord.xy), shadowLightVector, cloudLayer0, 20);
            #endif
        #endif
    }
#endif
