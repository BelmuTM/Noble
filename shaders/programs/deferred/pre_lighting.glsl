/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
/*                                                                              */
/*    This program is free software: you can redistribute it and/or modify      */
/*    it under the terms of the GNU General Public License as published by      */
/*    the Free Software Foundation, either version 3 of the License, or         */
/*    (at your option) any later version.                                       */
/*                                                                              */
/*    This program is distributed in the hope that it will be useful,           */
/*    but WITHOUT ANY WARRANTY; without even the implied warranty of            */
/*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             */
/*    GNU General Public License for more details.                              */
/*                                                                              */
/*    You should have received a copy of the GNU General Public License         */
/*    along with this program.  If not, see <https://www.gnu.org/licenses/>.    */
/*                                                                              */
/********************************************************************************/

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#include "/include/utility/rng.glsl"

#include "/include/atmospherics/constants.glsl"

#if defined WORLD_OVERWORLD || defined WORLD_END
    #include "/include/utility/phase.glsl"
	#include "/include/atmospherics/atmosphere.glsl"
#endif

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec2 vertexCoords;
    out vec3 directIlluminance;

    #if GI == 0
        out vec3[9] skyIrradiance;
    #endif

    out vec3 uniformSkyIlluminance;

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

		#if defined WORLD_OVERWORLD || defined WORLD_END
			directIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0), 0).rgb;

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

    #if GI == 0
        in vec3[9] skyIrradiance;
    #endif

    in vec3 uniformSkyIlluminance;

    #if defined WORLD_OVERWORLD && SHADOWS > 0
        #include "/include/fragment/shadows.glsl"
    #endif

    #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    /*
    float computeLowerHiZDepthLevels() {
        float tiles = 0.0;

        for (int i = 1; i < HIZ_LOD_COUNT; i++) {
            int scale   = int(exp2(i)); 
	        vec2 coords = (textureCoords - hiZOffsets[i - 1]) * scale;
                 tiles += find2x2MinimumDepth(coords, scale);
        }
        return tiles;
    }
    */

    void main() {
        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
	    if (saturate(fragCoords) != fragCoords) discard;

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

            if (receivesSkylight) {
                #if GI == 0 && AO > 0
                    vec3 aoBuffer = texture(AO_BUFFER, vertexCoords).rgb;

                    vec4 ao;
                    ao.xyz = decodeUnitVector(aoBuffer.xy);
                    ao.w   = aoBuffer.z;

                    skyIlluminance = max0(evaluateDirectionalSkyIrradiance(skyIrradiance, max0(ao.xyz), ao.w));
                #else
                    skyIlluminance = uniformSkyIlluminance;
                #endif
            }
        #endif

        if (ivec2(gl_FragCoord.xy) == ivec2(0, 0))
            illuminance.rgb = directIlluminance;
        else if (ivec2(gl_FragCoord.xy) == ivec2(0, 1))
            illuminance.rgb = uniformSkyIlluminance;
        else
            illuminance.rgb = skyIlluminance;
                
        //////////////////////////////////////////////////////////
        /*----------------- SHADOW MAPPING ---------------------*/
        //////////////////////////////////////////////////////////

        if (material.depth0 == 1.0) return;
            
        #if defined WORLD_OVERWORLD
            #if SHADOWS > 0
                mat4 projection        = gbufferProjection;
                mat4 projectionInverse = gbufferProjectionInverse;

                float nearPlane = near;
                float farPlane  = far;

                #if defined DISTANT_HORIZONS
                    if (texture(depthtex0, vertexCoords).r >= 1.0) {
                        projection        = dhProjection;
                        projectionInverse = dhProjectionInverse;

                        nearPlane = dhNearPlane;
                        farPlane  = dhFarPlane;
                    }
                #endif

                vec3 geometricNormal = decodeUnitVector(texture(SHADOWMAP_BUFFER, vertexCoords).rg);
                vec3 screenPosition  = vec3(textureCoords, material.depth0);
                vec3 viewPosition    = screenToView(screenPosition, projectionInverse, true);
                vec3 scenePosition   = viewToScene(viewPosition);

                shadowmap.rgb = abs(calculateShadowMapping(scenePosition, geometricNormal, material.depth0, shadowmap.a));

                #if POM > 0 && POM_SHADOWING == 1
                    shadowmap.rgb *= material.parallaxSelfShadowing;
                #endif
            #endif

            #if CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1
                illuminance.a = calculateCloudsShadows(getCloudsShadowPosition(gl_FragCoord.xy, atmosphereRayPosition), cloudLayer0, 20);
            #endif
        #endif
    }
    
#endif
