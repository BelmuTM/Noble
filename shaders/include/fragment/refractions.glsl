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

// Kneemund's border attenuation (https://github.com/Kneemund)
float kneemundAttenuation(vec2 pos, float edgeFactor) {
    pos *= 1.0 - pos;
    return 1.0 - quinticStep(edgeFactor, 0.0, minOf(pos));
}

vec3 computeRefractions(bool dhFragment, mat4 projection, mat4 projectionInverse, vec3 viewPosition0, vec3 viewPosition1, Material material, inout vec3 refractedPosition) {
    vec3 n1 = vec3(airIOR), n2 = material.N;
    if (isEyeInWater == 1) {
        n1 = vec3(1.333);
        n2 = vec3(airIOR);
    }

    vec3 viewDirection      = normalize(viewPosition0);
    vec3 refractedDirection = refract(viewDirection, material.normal, n1.r / n2.r);

    bool hit = true;

    #if REFRACTIONS == 1

        float jitter = temporalBlueNoise(gl_FragCoord.xy);
        float rayLength;

        if (dhFragment) {
            hit = raytrace(dhDepthTex1, projection, projectionInverse, viewPosition0, refractedDirection, REFRACTIONS_STRIDE, jitter, RENDER_SCALE, refractedPosition, rayLength);
        } else {
            hit = raytrace(depthtex1, projection, projectionInverse, viewPosition0, refractedDirection, REFRACTIONS_STRIDE, jitter, RENDER_SCALE, refractedPosition, rayLength);
        }

    #elif REFRACTIONS == 2

        refractedDirection = mat3(gbufferModelViewInverse) * refractedDirection;

        vec3 scenePosition0 = viewToScene(viewPosition0);
        vec3 scenePosition1 = viewToScene(viewPosition1);

        float refractedDistance = distance(scenePosition0, scenePosition1);

        refractedPosition = viewToScreen(sceneToView(scenePosition0 + refractedDirection * refractedDistance), projection, true);

    #endif

    refractedPosition.xy  = mix(textureCoords, refractedPosition.xy, kneemundAttenuation(refractedPosition.xy, 0.03));
    refractedPosition.xy *= RENDER_SCALE;

    float depth0 = texture(depthtex0, refractedPosition.xy).r;
    float depth1 = texture(depthtex1, refractedPosition.xy).r;

    float nearPlane = near;
    float farPlane  = far;

    #if defined DISTANT_HORIZONS
        if (depth0 >= 1.0) {
            depth0 = texture(dhDepthTex0, refractedPosition.xy).r;
            depth1 = texture(dhDepthTex1, refractedPosition.xy).r;

            nearPlane = dhNearPlane;
            farPlane  = dhFarPlane;
        }
    #endif
        
    if (!hit || depth1 < material.depth0 || depth1 - depth0 < EPS || depth1 < handDepth) {
        refractedPosition.xy = vertexCoords;
    }

    #if defined WORLD_OVERWORLD && (CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1)
        if (depth1 == 1.0) {
            float distanceToClouds = texture(CLOUDMAP_BUFFER, vertexCoords).a;
            refractedPosition.xy   = viewToScreen(viewPosition0 + refractedDirection * distanceToClouds, projection, true).xy;
        }
    #endif

    vec3 fresnel = fresnelDielectricDielectric_T(dot(material.normal, -viewDirection), n1, n2);

    vec3 sampledColor = texture(MAIN_BUFFER, refractedPosition.xy).rgb;

    float density = 0.0;

    switch (material.id) {
        case WATER_ID:         return sampledColor * fresnel;
        case NETHER_PORTAL_ID: density = 3.0;
        default: {
            density = clamp(distance(linearizeDepth(depth1, nearPlane, farPlane), linearizeDepth(material.depth0, nearPlane, farPlane)), 0.0, 2.0);
            break;
        }
    }

    vec3 absorption = exp(-(1.0 - material.albedo) * density);

    vec3 blocklightColor = getBlockLightColor(material);
    vec3 emissiveness    = material.emission * blocklightColor;

    return sampledColor * fresnel * absorption + emissiveness * material.albedo;
}
