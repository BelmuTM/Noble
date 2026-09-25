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
    [Credits]:
        Kneemund - providing the border attenuation function (https://github.com/Kneemund)
        jbritain - suggesting the Newton method for refraction (https://github.com/jbritain)

    [References]:
        Mayer, C., Assarsson, U., Sintorn, E. (2026). Ultrafast Screen-Space Refractions and Caustics via Newton’s Method. https://jcgt.org/published/0015/01/03/
*/

float kneemundAttenuation(vec2 pos, float edgeFactor) {
    if (edgeFactor < EPS) return 1.0;

    pos *= 1.0 - pos;
    return 1.0 - quinticStep(edgeFactor, 0.0, minOf(pos));
}

#if REFRACTIONS == 1

    bool newtonRefraction(
        vec3 viewPosition0,
        vec3 viewPosition1,
        vec3 rayDirection,
        vec3 normal,
        inout vec3 refractedPosition
    ) {

        const float distanceThreshold = 0.1;

        for (int i = 0; i < REFRACTIONS_NEWTON_ITERATIONS; i++) {

            float NdotL = dot(normal, rayDirection);
            
            if (abs(NdotL) < EPS) { break; }

            // Intersecting a point along the tangent plane defined by viewPosition1
            float tangentPlaneDist = dot(normal, viewPosition1 - viewPosition0) / NdotL;
            vec3  tangentPointView = viewPosition0 + rayDirection * tangentPlaneDist;

            // Projecting the tangent point to screen space from the depth buffer
            vec3 tangentPointScreen = viewToScreen(tangentPointView, projectionMatrix, true);

            if (insideScreenBounds(tangentPointScreen.xy, 1.0)) {

                ivec2 tangentPointCoords = ivec2(tangentPointScreen.xy * viewSize * RENDER_SCALE);
                vec3  rayPositionScreen  = vec3(tangentPointScreen.xy, texelFetch(depthBuffer1, tangentPointCoords, 0).r);

                viewPosition1 = screenToView(rayPositionScreen, projectionInverseMatrix, true);
                normal        = unpackNormal(texelFetch(GBUFFERS_DATA_BUFFER, tangentPointCoords, 0).w);

                // If the ray's position is close enough, success
                if (distance(tangentPointView, viewPosition1) < distanceThreshold) {
                    refractedPosition = rayPositionScreen;
                    return true;
                }
                
            }

        }

        return false;
    }

#endif

vec3 computeRefractions(
    vec3 screenPosition,
    vec3 viewPosition0,
    vec3 viewPosition1,
    vec3 albedo,
    vec3 normal,
    float emission,
    vec3 N,
    uint id,
    float invExposure,
    inout vec3 refractedPosition
) {
    vec3 n1 = vec3(airIOR), n2 = N;
    
    if (isEyeInWater == 1) {
        n1 = vec3(1.333);
        n2 = vec3(airIOR);
    }

    vec3 viewDirection      = normalize(viewPosition0);
    vec3 refractedDirection = refract(viewDirection, normal, n1.r / n2.r);

    bool hit = true;

    #if REFRACTIONS == 1

        hit = newtonRefraction(
            viewPosition0,
            viewPosition1,
            refractedDirection,
            normal,
            refractedPosition
        );        

    #elif REFRACTIONS == 2

        float jitter = temporalBlueNoise(SCREEN_COORDS);

        float rayLength = 0.0;

        hit = raytrace(
            depthBuffer1,
            projectionMatrix,
            projectionInverseMatrix,
            viewPosition0,
            refractedDirection,
            float(REFRACTIONS_STRIDE),
            jitter,
            RENDER_SCALE,
            refractedPosition,
            rayLength
        );

    #endif

    refractedPosition.xy = mix(
        screenPosition.xy,
        refractedPosition.xy,
        kneemundAttenuation(refractedPosition.xy, REFRACTIONS_BORDER_FADE)
        * float(hit && insideScreenBounds(refractedPosition.xy, 1.0) && refractedPosition.z > handDepth)
    );

    refractedPosition.xy *= RENDER_SCALE;

    vec3 fresnel = fresnelDielectricDielectric_T(abs(dot(normal, -viewDirection)), n1, n2);

    vec3 refractedColor = texture(MAIN_BUFFER, refractedPosition.xy).rgb * invExposure;

    // Water absorption is handled individually
    if (isWater(id)) {
        return refractedColor * fresnel;
    }

    // Approximate absorption for other materials
    float density = 3.0;

    if (id != NETHER_PORTAL_ID) {

        density = abs(
            screenToViewDepth(screenPosition.z, projectionInverseMatrix)
          - screenToViewDepth(refractedPosition.z, projectionInverseMatrix)
        );

        density = clamp(density, 0.0, 2.0);
    }

    vec3 absorption   = exp(-(1.0 - albedo) * density);
    vec3 emissiveness = emission * blockLightColor;

    return refractedColor * fresnel * absorption + emissiveness * albedo;
}
