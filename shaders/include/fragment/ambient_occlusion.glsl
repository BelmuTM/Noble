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

#if AO == 1

    float multiBounceApprox(float visibility) { 
        const float albedo = 0.2; 
        return visibility / (albedo * visibility + (1.0 - albedo)); 
    }

    float findMaximumHorizon(
        sampler2D depthTex,
        mat4 projectionInverse,
        vec3 viewPosition,
        vec3 viewDirection,
        vec3 normal,
        vec3 sliceDir,
        float radius
    ) {
        float horizonCosTheta = -1.0;

        const float cosThetaThreshold = 0.95; // We can stop searching once cosTheta approaches 1

        vec2 increment   = sliceDir.xy * radius * rcp(GTAO_HORIZON_STEPS);
        vec2 rayPosition = textureCoords + rand2F() * increment;

        for (int i = 0; i < GTAO_HORIZON_STEPS && horizonCosTheta < cosThetaThreshold; i++) {

            ivec2 coords = ivec2(rayPosition * viewSize * RENDER_SCALE);
            float depth  = texelFetch(depthTex, coords, 0).r;

            if (insideScreenBounds(rayPosition, RENDER_SCALE) && depth < 1.0) {

                vec3 horizonVec = screenToView(vec3(rayPosition, depth), projectionInverse, true) - viewPosition;

                float cosTheta = mix(dot(horizonVec, viewDirection) * fastRcpLength(horizonVec), -1.0, linearStep(1.0, 2.0, lengthSqr(horizonVec)));
    
                horizonCosTheta = max(horizonCosTheta, cosTheta);

                rayPosition += increment;
            }

        }

        return fastAcos(horizonCosTheta);
    }

    float GTAO(sampler2D depthTex, mat4 projectionInverse, vec3 viewPosition, vec3 normal, out vec3 bentNormal) {
        float visibility = 0.0;

        float radius  	    = gbufferProjection[1][1] * GTAO_RADIUS / -viewPosition.z;
        vec3  viewDirection = viewPosition * -fastRcpLength(viewPosition);

        float dither = temporalBlueNoise(gl_FragCoord.xy);

        for (int i = 0; i < GTAO_SLICES; i++) {
            float sliceAngle = PI * rcp(GTAO_SLICES) * (i + dither);
            vec3  sliceDir   = vec3(cos(sliceAngle), sin(sliceAngle), 0.0);

            vec3 axis       = normalize(cross(sliceDir, viewDirection));
            vec3 orthoDir   = cross(viewDirection, axis);
            vec3 projNormal = normal - axis * dot(normal, axis);

            float invNormLen = fastRcpLength(projNormal);
            float cosGamma   = saturate(dot(projNormal, viewDirection) * invNormLen);
            float gamma      = sign(dot(projNormal, orthoDir)) * fastAcos(cosGamma);

            vec2 horizons = vec2(
                -findMaximumHorizon(depthTex, projectionInverse, viewPosition, viewDirection, normal,-sliceDir, radius),
                 findMaximumHorizon(depthTex, projectionInverse, viewPosition, viewDirection, normal, sliceDir, radius)
            );

            horizons = gamma + clamp(horizons - gamma, -HALF_PI, HALF_PI);
    
            vec2 arc = cosGamma + 2.0 * horizons * sin(gamma) - cos(2.0 * horizons - gamma);

            visibility += dot(arc, vec2(0.25)) * rcp(invNormLen);

            float bentAngle = dot(horizons, vec2(0.5));

            bentNormal += viewDirection * cos(bentAngle) + orthoDir * sin(bentAngle);
        }

        bentNormal = normalize(bentNormal) - 0.5 * viewDirection;

        float ao = visibility * rcp(GTAO_SLICES);

        ao = 1.0 - saturate((1.0 - ao) * AO_STRENGTH);

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
