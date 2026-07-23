/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec2 vertexCoords;

    flat out vec3 directIlluminance;
    flat out vec3 uniformSkyIlluminance;

    #include "/include/atmospherics/illuminance_fetch.glsl"

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

        #if defined WORLD_OVERWORLD || defined WORLD_END

            directIlluminance     = DIRECT_ILLUMINANCE();
            uniformSkyIlluminance = UNIFORM_SKY_ILLUMINANCE();

        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0,4 */

    layout (location = 0) out vec3 lightingOut;
    layout (location = 1) out vec2 temporalDataOut;

    in vec2 textureCoords;
    in vec2 vertexCoords;

    flat in vec3 directIlluminance;
    flat in vec3 uniformSkyIlluminance;

    #include "/include/utility/rng.glsl"

    #include "/include/atmospherics/atmosphere_header.glsl"

    #include "/include/utility/sampling.glsl"

    #include "/include/material/brdf.glsl"

    #if defined WORLD_OVERWORLD || defined WORLD_END
    
        #include "/include/atmospherics/celestial.glsl"

    #endif

    #include "/include/post/exposure.glsl"

    void main() {
        
        lightingOut = vec3(0.0);

        #if DOWNSCALED_RENDERING == 1
            vec2 fragCoords = gl_FragCoord.xy * texelSize;
            if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { return; }
        #endif

        // Diffuse setup

        bool  modFragment = false;
        float depth       = texture(depthtex0, vertexCoords).r;

        mat4 projection         = gbufferProjection;
        mat4 projectionInverse  = gbufferProjectionInverse;
        mat4 projectionPrevious = gbufferPreviousProjection;

        float nearPlane = near;
        float farPlane  = far;

        #if defined CHUNK_LOADER_MOD_ENABLED

            if (depth >= 1.0) {
                modFragment = true;

                #if defined VOXY
                    depth = texture(modDepthTex0, textureCoords).r;
                #else
                    depth = texture(modDepthTex0, vertexCoords).r;
                #endif

                projection         = modProjection;
                projectionInverse  = modProjectionInverse;
                projectionPrevious = modProjectionPrevious;

                nearPlane = modNearPlane;
                farPlane  = modFarPlane;
            }
            
        #endif

        vec3 viewPosition = screenToView(vec3(textureCoords, depth), projectionInverse, true);

        // Exposure to pre-apply and store values in smaller range buffer

        float exposure = CURRENT_EXPOSURE();

        // Atmosphere rendering

        if (depth == 1.0) {

            #if defined WORLD_OVERWORLD || defined WORLD_END

                lightingOut  = renderAtmosphere(vertexCoords, viewPosition, directIlluminance, uniformSkyIlluminance);
                lightingOut += renderCelestialBodies(vertexCoords, viewPosition);
                lightingOut *= exposure;

            #endif
            
            return;
        }

        Material material = getMaterial(vertexCoords);

        // Temporal reprojection

        vec3 velocity     = getVelocity(vec3(textureCoords, depth), projectionInverse, projectionPrevious);
        vec3 prevPosition = vec3(vertexCoords, depth) + velocity * RENDER_SCALE;

        // Previous depth decoding / encoding

        temporalDataOut = texture(TEMPORAL_DATA_BUFFER, prevPosition.xy).rg;

        float prevDepth   = exp2(temporalDataOut.r);
        temporalDataOut.r = log2(prevPosition.z);

        float linearDepth     = linearizeDepth(prevPosition.z, nearPlane, farPlane);
        float linearPrevDepth = linearizeDepth(prevDepth, nearPlane, farPlane);

        // Temporal accumulation weight computation

        vec3 prevScenePosition = viewToWorld(screenToView(prevPosition, projectionInverse, false));
        bool closeToCamera     = distance(gbufferModelViewInverse[3].xyz, prevScenePosition) > 1.1;

        float depthWeight = pow(exp(-abs(linearDepth - linearPrevDepth)), 2.0);

        temporalDataOut.g *= float(insideScreenBounds(prevPosition.xy, RENDER_SCALE));
        temporalDataOut.g *= float(depth >= handDepth);
        temporalDataOut.g *= (closeToCamera ? depthWeight : 1.0);
        temporalDataOut.g  = min(temporalDataOut.g + 1.0, MAX_ACCUMULATED_FRAMES);

        // Diffuse lighting

        float cloudsShadows = 1.0; 

        #if defined WORLD_OVERWORLD && CLOUDS_SHADOWS == 1 && CLOUDS_LAYER0_ENABLED == 1

            cloudsShadows = getCloudsShadows(viewToWorld(viewPosition));

        #endif

        vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

        #if SHADOWS > 0

            shadowmap = textureBicubic(SHADOWMAP_BUFFER, vertexCoords);

        #endif

        vec3 skyIlluminance = vec3(0.0);
        
        #if defined WORLD_OVERWORLD || defined WORLD_END

            skyIlluminance = texelFetch(ILLUMINANCE_BUFFER, ivec2(gl_FragCoord.xy), 0).rgb;
            
        #endif

        float ao = 1.0;
        
        #if AO > 0
            ao = texture(AO_BUFFER, vertexCoords).b;
        #endif

        lightingOut = computeDiffuse(
            viewPosition,
            shadowLightVector,
            material,
            material.F0 * maxFloat8 > labPBRMetals,
            shadowmap,
            directIlluminance,
            skyIlluminance,
            ao,
            cloudsShadows
        );

        lightingOut *= exposure;
    }

#endif
