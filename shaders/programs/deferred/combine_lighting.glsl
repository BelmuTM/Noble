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
    flat out vec3 skyIlluminance;

    void main() {
        gl_Position    = vec4(gl_Vertex.xy * 2.0 - 1.0, 1.0, 1.0);
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w; + (RENDER_SCALE - 1.0);
        textureCoords  = gl_Vertex.xy;
        vertexCoords   = gl_Vertex.xy * RENDER_SCALE;

        #if defined WORLD_OVERWORLD || defined WORLD_END

            directIlluminance = decodeLog(texelFetch(IRRADIANCE_BUFFER, ivec2(0, 0), 0).rgb);

            #if defined WORLD_OVERWORLD
                skyIlluminance = texelFetch(IRRADIANCE_BUFFER, ivec2(0, 1), 0).rgb;
            #endif

        #endif
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec3 lighting;

    in vec2 textureCoords;
    in vec2 vertexCoords;
    flat in vec3 directIlluminance;
    flat in vec3 skyIlluminance;

    #include "/include/utility/rng.glsl"

    #include "/include/atmospherics/constants.glsl"

    #include "/include/utility/phase.glsl"
    #include "/include/utility/sampling.glsl"

    #include "/include/material/brdf.glsl"
    #include "/include/atmospherics/celestial.glsl"

    void main() {
        float depth = texture(depthtex0, vertexCoords).r;

        mat4 projectionInverse = gbufferProjectionInverse;

        #if defined CHUNK_LOADER_MOD_ENABLED

            if (depth >= 1.0) {
                #if defined VOXY
                    depth = texture(modDepthTex0, textureCoords).r;
                #else
                    depth = texture(modDepthTex0, vertexCoords).r;
                #endif

                projectionInverse = modProjectionInverse;
            }
            
        #endif

        vec3 screenPosition = vec3(vertexCoords, depth);
        vec3 viewPosition   = screenToView(vec3(textureCoords, depth), projectionInverse, true);

        if (depth == 1.0) {
            lighting = encodeLog(renderAtmosphere(vertexCoords, viewPosition, directIlluminance, skyIlluminance));
            return;
        }

        #if GI == 0

            lighting = texture(DEFERRED_BUFFER, vertexCoords).rgb;

        #else

            Material material = getMaterial(vertexCoords);

            vec3 directDiffuse = evaluateMicrosurfaceOpaque(vertexCoords, -normalize(viewPosition), shadowLightVector, material, directIlluminance);

            #if RENDER_MODE == 0 && ATROUS_FILTER == 1
                vec3 irradianceDiffuse = texture(MAIN_BUFFER, vertexCoords).rgb;
            #else
                vec3 irradianceDiffuse = texture(DEFERRED_BUFFER, vertexCoords).rgb;
            #endif
        
            lighting = material.albedo * (irradianceDiffuse + directDiffuse);
            
        #endif

        lighting = encodeLog(lighting);
    }
    
#endif
