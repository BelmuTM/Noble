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

/*
    [References]:
        LearnOpenGL. (2015). SSAO. https://learnopengl.com/Advanced-Lighting/SSAO
        Jimenez et al. (2016). Practical Real-Time Strategies for Accurate Indirect Occlusion. https://www.activision.com/cdn/research/Practical_Real_Time_Strategies_for_Accurate_Indirect_Occlusion_NEW%20VERSION_COLOR.pdf
        Jimenez et al. (2016). Practical Realtime Strategies for Accurate Indirect Occlusion. https://blog.selfshadow.com/publications/s2016-shading-course/activision/s2016_pbs_activision_occlusion.pdf
*/

#if AO == 1

    float multiBounceApprox(float visibility) { 
        const float albedo = 0.2; 
        return visibility / (albedo * visibility + (1.0 - albedo)); 
    }

    float findMaximumHorizonAngle(
        sampler2D depthTex,
        mat4 projectionInverse,
        vec3 viewPosition,
        vec3 viewDirection,
        vec3 normal,
        vec2 sliceStep
    ) {
        float horizonCosTheta = -1.0;

        const float cosThetaThreshold = 0.95; // We can stop searching once cosTheta approaches 1

        ivec2 slicePosition = ivec2(textureCoords * viewSize + sliceStep * rand2F());

        for (int i = 0; i < GTAO_HORIZON_STEPS && horizonCosTheta < cosThetaThreshold; i++) {

            float depth = texelFetch(depthTex, ivec2(slicePosition * RENDER_SCALE), 0).r;

            if (insideScreenBounds(vec3(slicePosition * texelSize, depth), 1.0)) {

                vec3 horizonVec = screenToView(vec3(slicePosition * texelSize, depth), projectionInverse, true) - viewPosition;

                float cosTheta = mix(
                    dot(horizonVec, viewDirection) * fastRcpLength(horizonVec),
                    -1.0,
                    linearStep(1.0, 2.0, lengthSqr(horizonVec))
                );

                horizonCosTheta = max(horizonCosTheta, cosTheta);
            }
            
            slicePosition += ivec2(sliceStep);

        }

        return fastAcos(horizonCosTheta);
    }

    float GTAO(sampler2D depthTex, mat4 projectionInverse, vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
        float visibility = 0.0;

        // World-space radius
        vec2 radius = viewSize * GTAO_RADIUS * RCP_GTAO_HORIZON_STEPS * gbufferProjection[1][1] / -viewPosition.z;

        vec3 viewDirection = -normalize(viewPosition);

        float jitter = temporalBlueNoise(gl_FragCoord.xy);

        for (int i = 0; i < GTAO_SLICES; i++) {

            vec2 sliceDirection = sincos(PI * RCP_GTAO_SLICES * (i + jitter));

            // Projecting the normal to the slice
            vec3 axis           = normalize(cross(vec3(sliceDirection, 0.0), viewDirection));
            vec3 orthoDirection = cross(viewDirection, axis);
            vec3 projNormal     = normal - axis * dot(normal, axis);

            float invNormLen = fastRcpLength(projNormal);
            float cosGamma   = saturate(dot(projNormal, viewDirection) * invNormLen);
            float gamma      = sign(dot(projNormal, orthoDirection)) * fastAcos(cosGamma);

            // Horizon search
            vec2 horizons = vec2(
                -findMaximumHorizonAngle(depthTex, projectionInverse, viewPosition, viewDirection, normal, -sliceDirection * radius),
                 findMaximumHorizonAngle(depthTex, projectionInverse, viewPosition, viewDirection, normal,  sliceDirection * radius)
            );

            // Each slice covers PI radians, thus we clamp the angles to the [-PI/2; PI/2] range
            horizons = gamma + clamp(horizons - gamma, -HALF_PI, HALF_PI);

            // The bent normal angle is simply the average of the two horizon angles
            float bentAngle = dot(horizons, vec2(0.5));
    
            // Integrating the arc
            vec2 arc = cosGamma + 2.0 * horizons * sin(gamma) - cos(2.0 * horizons - gamma);

            visibility += dot(arc, vec2(0.25)) * rcp(invNormLen);

            bentNormal += viewDirection * cos(bentAngle) + orthoDirection * sin(bentAngle);
        }

        bentNormal = normalize(bentNormal) - 0.5 * viewDirection;

        float ao = 1.0 - saturate((1.0 - visibility * RCP_GTAO_SLICES) * AO_STRENGTH);

        return multiBounceApprox(ao);
    }

#elif AO == 2

    float SSAO(sampler2D depthTex, mat4 projection, mat4 projectionInverse, vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
        float occlusion        = 0.0;
        float visibilityWeight = 0.0;

        for (int i = 0; i < SSAO_SAMPLES; i++) {
            vec3 rayDirection = generateCosineVector(normal, rand2F());
            vec3 rayPosition  = viewPosition + rayDirection * SSAO_RADIUS;

            vec2 sampleCoords = viewToScreen(rayPosition, projection, true).xy;

            ivec2 coords = ivec2(sampleCoords * viewSize * RENDER_SCALE);

            float sampleDepth = texelFetch(depthTex, ivec2(coords), 0).r;

            float rayDepth = screenToView(vec3(sampleCoords, sampleDepth), projectionInverse, true).z;

            float contribution  = step(rayPosition.z + EPS, rayDepth);
                  contribution *= quinticStep(0.0, 1.0, SSAO_RADIUS / abs(viewPosition.z - rayDepth));
            
            occlusion += contribution;

            float visibility  = 1.0 - contribution;
            bentNormal       += rayDirection * visibility;
            visibilityWeight += visibility;
        }

        bentNormal = visibilityWeight > 0.0 ? bentNormal / visibilityWeight : normal;

        return saturate(1.0 - occlusion * rcp(SSAO_SAMPLES) * AO_STRENGTH);
    }

#elif AO == 3

    #include "/include/fragment/raytracer.glsl"

    float RTAO(sampler2D depthTex, mat4 projection, mat4 projectionInverse, vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
        float visibility = 1.0;

        vec3 hitPosition = vec3(0.0);
        float rayLength;

        for (int i = 0; i < RTAO_SAMPLES; i++) {
            vec3 rayDirection = generateCosineVector(normal, rand2F());

            float jitter = randF();

            bool hit = raytrace(
                depthTex,
                projection,
                projectionInverse,
                viewPosition,
                rayDirection,
                float(RTAO_STRIDE),
                jitter,
                RENDER_SCALE,
                hitPosition,
                rayLength
            );

            float h = float(hit);

            bentNormal += rayDirection * (1.0 - h);
            visibility -= rcp(RTAO_SAMPLES) * h * AO_STRENGTH;
        }

        return saturate(visibility);
    }

#endif
