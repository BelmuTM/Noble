/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

vec3 computeRefractions(vec3 viewPosition, Material material, inout vec3 hitPosition) {
    vec3 n1 = vec3(airIOR), n2 = material.N;
    if(isEyeInWater == 1) {
        n1 = vec3(1.333);
        n2 = vec3(airIOR);
    }

    vec3 viewDirection = normalize(viewPosition);
    vec3 refracted     = refract(viewDirection, material.normal, n1.r / n2.r);
    bool hit           = raytrace(depthtex1, viewPosition, refracted, REFRACTIONS_STEPS, randF(), RENDER_SCALE, hitPosition);
        
    if(!hit && material.depth1 < 1.0 || saturate(hitPosition.xy) != hitPosition.xy || isHand(hitPosition.xy * RENDER_SCALE)) {
        hitPosition.xy = textureCoords;
    }

    hitPosition.xy *= RENDER_SCALE;

    vec3 fresnel      = fresnelDielectricDielectric_T(dot(material.normal, -viewDirection), n1, n2);
    vec3 sampledColor = texture(LIGHTING_BUFFER, hitPosition.xy).rgb;

    float density = 0.0;

    switch(material.blockId) {
        case WATER_ID:         return sampledColor * fresnel;
        case NETHER_PORTAL_ID: density = 3.0;
        default: {
            density = clamp(distance(linearizeDepth(texture(depthtex1, hitPosition.xy).r), linearizeDepth(material.depth0)), 0.0, 5.0);
            break;
        }
    }

    vec3 attenuation = exp(-(1.0 - material.albedo) * density);

    vec3 blocklightColor = getBlockLightColor(material);
    vec3 emissiveness    = material.emission * blocklightColor;

    return sampledColor * fresnel * attenuation + emissiveness * material.albedo;
}
