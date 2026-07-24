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

#if REFLECTIONS == 1

    #include "/include/taau_scale.glsl"

    const float reflectionsScale = REFLECTIONS_SCALE * 0.01;
    const float renderScaleFinal = RENDER_SCALE * reflectionsScale;

    layout (rgba16f) uniform image2D colorimg2;

    layout (local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

    const vec2 workGroupsRender = vec2(renderScaleFinal, renderScaleFinal);

    shared vec3 directIlluminance;
    shared vec3 skyIlluminance;

    #include "/include/common.glsl"

    #include "/include/utility/rng.glsl"

    #include "/include/atmospherics/illuminance_fetch.glsl"
    #include "/include/atmospherics/atmosphere_header.glsl"

    #include "/include/material/brdf.glsl"

    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/reflections.glsl"

    #include "/include/post/exposure.glsl"

    void main() {
        ivec2 coords = ivec2(gl_GlobalInvocationID.xy);

        #if DOWNSCALED_RENDERING == 1
            if (!insideScreenBounds(coords * texelSize, renderScaleFinal)) { return; }
        #endif

        // Pre-fetching illuminance values

        if (gl_LocalInvocationID.x == 0 && gl_LocalInvocationID.y == 0) {
            directIlluminance = DIRECT_ILLUMINANCE();
            skyIlluminance    = UNIFORM_SKY_ILLUMINANCE();
        }

        memoryBarrierShared();
        barrier();

        // Reflections setup

        ivec2 bufferCoords = ivec2(coords * reflectionsScale);

        vec4 reflections = vec4(0.0);

        bool  modFragment = false;
        float depth       = texelFetch(depthtex0, coords, 0).r;

        mat4 projection         = gbufferProjection;
        mat4 projectionInverse  = gbufferProjectionInverse;
        mat4 projectionPrevious = gbufferPreviousProjection;

        float nearPlane = near;
        float farPlane  = far;

        #if defined CHUNK_LOADER_MOD_ENABLED

            if (depth >= 1.0) {
                modFragment = true;
                
                #if defined VOXY
                    depth = texelFetch(modDepthTex0, ivec2(coords * RCP_RENDER_SCALE), 0).r;
                #else
                    depth = texelFetch(modDepthTex0, coords, 0).r;
                #endif
                
                projection         = modProjection;
                projectionInverse  = modProjectionInverse;
                projectionPrevious = modProjectionPrevious;

                nearPlane = modNearPlane;
                farPlane  = modFarPlane;
            }
            
        #endif

        // Discard sky fragments

        if (depth == 1.0) {
            imageStore(colorimg2, bufferCoords, reflections);
            return;
        }

        uvec4 dataTexture = texelFetch(GBUFFERS_DATA, coords, 0);

        float F0    = unpackF0(dataTexture.y);
        float alpha = unpackAlpha(dataTexture.z);

        // Discard reflections if material's F0 is too low or if roughness is too high

        if (F0 <= EPS || alpha > REFLECTIONS_ROUGHNESS_THRESHOLD) {
            imageStore(colorimg2, bufferCoords, reflections);
            return;
        }

        float exposure = CURRENT_EXPOSURE();

        vec3 albedo = unpackAlbedo(dataTexture.z);

        bool isWater = isWater(unpackId(dataTexture.x));

        // Reflections tracing

        vec2 scaledPixelCoords = coords * texelSize;
        vec2 pixelCoords       = scaledPixelCoords * RCP_RENDER_SCALE;

        vec3 screenPosition = vec3(pixelCoords, depth);
        vec3 viewPosition   = screenToView(screenPosition, projectionInverse, true);

        float rayLength = 0.0;
                
        #if REFLECTIONS == 1

            reflections.rgb = computeRoughReflections(
                modFragment, projection, projectionInverse, viewPosition,
                unpackNormal(dataTexture.w), getN(albedo, F0), getK(albedo, F0), alpha, unpackLightmap(dataTexture.x).y, isWater,
                exposure,
                rayLength
            );

        #elif REFLECTIONS == 2

            reflections.rgb = computeSmoothReflections(
                modFragment, projection, projectionInverse, viewPosition,
                unpackNormal(dataTexture.w), getN(albedo, F0), getK(albedo, F0), alpha, unpackLightmap(dataTexture.x).y, isWater,
                exposure,
                rayLength
            );

        #endif

        // Reflections filtering

        vec3 velocity     = getVelocity(screenPosition, projectionInverse, projectionPrevious);
        vec3 prevPosition = vec3(scaledPixelCoords, depth) + velocity * RENDER_SCALE;

        float reprojectionDepth;
        bool  isReflectingSky = false;

        if (rayLength < EPS) {
            reprojectionDepth = texture(CLOUDMAP_BUFFER, pixelCoords).a;
            isReflectingSky   = true;

        } else {
            reprojectionDepth = depth + (alpha > 0.1 ? 0.0 : rayLength);
        }

        vec3 velocityReflected     = getVelocity(vec3(pixelCoords, reprojectionDepth), projectionInverse, projectionPrevious);
        vec3 prevPositionReflected = vec3(scaledPixelCoords, reprojectionDepth) + velocityReflected * RENDER_SCALE;

        vec4 prevReflections = texture(REFLECTIONS_BUFFER, prevPositionReflected.xy);

        bool isHand = depth < handDepth;

        float weight = 0.975;

        float linearDepth     = linearizeDepth(prevPosition.z         , nearPlane, farPlane);
        float linearPrevDepth = linearizeDepth(exp2(prevReflections.a), nearPlane, farPlane);
        float depthWeight     = step(abs(linearDepth - linearPrevDepth) / max(linearDepth, linearPrevDepth), 0.01);

        float velocityWeight = 1.0 - saturate(length(velocity.xy * viewSize)) * (isHand ? 1.0 : (isReflectingSky ? 0.8 : 0.5));

        vec2  pixelCenterDist  = 1.0 - abs(fract(prevPosition.xy * viewSize) * 2.0 - 1.0);
        float centerWeightHand = isHand ? sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.3 : 1.0;

        weight *= depthWeight * velocityWeight * centerWeightHand;
        weight  = saturate(weight);
        weight *= float(insideScreenBounds(prevPositionReflected.xy, RENDER_SCALE));
        weight *= mix(1.0, 0.5, float(isWater));

        reflections.rgb = max0(mix(reflections.rgb, prevReflections.rgb, weight));
        reflections.a   = log2(prevPosition.z);

        // Writing to buffer

        imageStore(colorimg2, bufferCoords, reflections);
    }
    
#else

    layout (local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

    void main() {
        return;
    }

#endif
