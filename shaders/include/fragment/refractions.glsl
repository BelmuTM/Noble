/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

vec3 computeRefractions(sampler2D depthTex, mat4 projection, vec3 viewPosition, Material material, inout vec3 hitPosition) {
    vec3 n1 = vec3(airIOR), n2 = material.N;
    if(isEyeInWater == 1) {
        n1 = vec3(1.333);
        n2 = vec3(airIOR);
    }

    vec3 viewDirection = normalize(viewPosition);
    vec3 refracted     = refract(viewDirection, material.normal, n1.r / n2.r);
    bool hit           = raytrace(depthTex, projection, viewPosition, refracted, REFRACTIONS_STEPS, randF(), RENDER_SCALE, hitPosition);

    hitPosition.xy *= RENDER_SCALE;

    float depth0 = texture(depthtex0, hitPosition.xy).r;
    float depth1 = texture(depthtex1, hitPosition.xy).r;

    float nearPlane = near;
    float farPlane  = far;

    #if defined DISTANT_HORIZONS
        if(depth0 >= 1.0) {
            depth0 = texture(dhDepthTex0, hitPosition.xy).r;
            depth1 = texture(dhDepthTex1, hitPosition.xy).r;

            nearPlane = dhNearPlane;
            farPlane  = dhFarPlane;
        }
    #endif
        
    if(saturate(hitPosition.xy) != hitPosition.xy || depth1 - depth0 < EPS || depth1 < handDepth) {
        hitPosition.xy = vertexCoords;
    }

    vec3 fresnel = fresnelDielectricDielectric_T(dot(material.normal, -viewDirection), n1, n2);

    #if GI == 1
        vec3 sampledColor = texture(DEFERRED_BUFFER, hitPosition.xy).rgb;
    #else
        vec3 sampledColor = texture(ACCUMULATION_BUFFER, hitPosition.xy).rgb;
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
