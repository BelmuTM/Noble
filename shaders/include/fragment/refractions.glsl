/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

// Kneemund's Border Attenuation
float kneemundAttenuation(vec2 pos, float edgeFactor) {
    pos *= 1.0 - pos;
    return 1.0 - quinticStep(edgeFactor, 0.0, minOf(pos));
}

vec3 computeRefractions(sampler2D depthTex, mat4 projection, vec3 viewPosition0, vec3 viewPosition1, Material material, inout vec3 refractedPosition) {
    vec3 n1 = vec3(airIOR), n2 = material.N;
    if(isEyeInWater == 1) {
        n1 = vec3(1.333);
        n2 = vec3(airIOR);
    }

    vec3 scenePosition0 = viewToScene(viewPosition0);
    vec3 scenePosition1 = viewToScene(viewPosition1);

    vec3  refractedDirection = mat3(gbufferModelViewInverse) * refract(normalize(viewPosition0), material.normal, n1.r / n2.r);
    float refractedDistance  = distance(scenePosition0, scenePosition1);

    refractedPosition = viewToScreen(sceneToView(scenePosition0 + refractedDirection * refractedDistance), projection, true);
    
    if (refractedPosition.z < material.depth0 || saturate(refractedPosition.xy) != refractedPosition.xy) {
        refractedPosition = vec3(textureCoords, material.depth1);
    }

    refractedPosition.xy = mix(textureCoords, refractedPosition.xy, kneemundAttenuation(refractedPosition.xy, 0.03));

    refractedPosition.xy *= RENDER_SCALE;

    float depth0 = texture(depthtex0, refractedPosition.xy).r;
    float depth1 = texture(depthtex1, refractedPosition.xy).r;

    float nearPlane = near;
    float farPlane  = far;

    #if defined DISTANT_HORIZONS
        if(depth0 >= 1.0) {
            depth0 = texture(dhDepthTex0, refractedPosition.xy).r;
            depth1 = texture(dhDepthTex1, refractedPosition.xy).r;

            nearPlane = dhNearPlane;
            farPlane  = dhFarPlane;
        }
    #endif
        
    if(depth1 - depth0 < EPS || depth1 < handDepth) {
        refractedPosition.xy = vertexCoords;
    }

    vec3 fresnel = fresnelDielectricDielectric_T(dot(material.normal, -normalize(viewPosition0)), n1, n2);

    #if GI == 1
        vec3 sampledColor = texture(DEFERRED_BUFFER, refractedPosition.xy).rgb;
    #else
        vec3 sampledColor = texture(ACCUMULATION_BUFFER, refractedPosition.xy).rgb;
    #endif

    float density = 0.0;

    switch(material.id) {
        case WATER_ID:         return sampledColor * fresnel;
        case NETHER_PORTAL_ID: density = 3.0;
        default: {
            density = clamp(distance(linearizeDepth(depth1, nearPlane, farPlane), linearizeDepth(material.depth0, nearPlane, farPlane)), 0.0, 5.0);
            break;
        }
    }

    vec3 absorption = exp(-(1.0 - material.albedo) * density);

    vec3 blocklightColor = getBlockLightColor(material);
    vec3 emissiveness    = material.emission * blocklightColor;

    return sampledColor * fresnel * absorption + emissiveness * material.albedo;
}
