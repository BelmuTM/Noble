/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 computePTGI(in vec3 screenPos) {
    vec3 radiance = vec3(0.0);
    vec3 throughput = vec3(1.0);

    vec3 hitPos = screenPos;
    vec3 viewPos = screenToView(screenPos);
    vec3 viewDir = -normalize(viewPos);

    for(int i = 0; i < GI_BOUNCES; i++) {
        vec2 noise = uniformAnimatedNoise(hash22(gl_FragCoord.xy + fract(frameTime)));

        /* Updating our position for the next bounce */
        vec3 normal = normalize(decodeNormal(texture(colortex1, hitPos.xy).xy));
        hitPos = screenToView(hitPos) + normal * EPS;

        /* Tangent Bitangent Normal */
        vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
        mat3 TBN = mat3(tangent, cross(normal, tangent), normal);
        
        /* Sampling a random direction in an hemisphere using noise and raytracing in that direction */
        vec3 sampleDir = TBN * randomHemisphereDirection(noise);
        if(!raytrace(hitPos, sampleDir, GI_STEPS, uniformNoise(i, blueNoise).r, hitPos)) continue;

        /* Calculating the BRDF & applying it */
        float F0 = texture(colortex2, hitPos.xy).g;
        bool isMetal = F0 * 255.0 > 229.5;
        float roughness = texture(colortex2, hitPos.xy).r;

        vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, roughness);
        vec3 reflected = reflect(viewDir, TBN * microfacet);

        vec3 H = normalize(viewDir + reflected);
        float NdotD = max(EPS, dot(normal, sampleDir));
        float NdotL = max(EPS, dot(normal, reflected)); 
        float NdotV = max(EPS, dot(normal, viewDir));
        float NdotH = max(EPS, dot(normal, H));
        float HdotL = max(EPS, dot(H, reflected));

        vec3 albedo = texture(colortex4, hitPos.xy).rgb;
        vec3 specular = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, roughness, F0, albedo, isMetal);
        // vec3 diffuse = orenNayarDiffuse(normal, viewDir, sampleDir, NdotD, NdotV, roughness * roughness, albedo) / (NdotD * INV_PI);

        vec3 fresnel = cookTorranceFresnel(NdotD, F0, albedo, isMetal);
        albedo *= 1.0 - fresnel;

        /* Thanks to Bálint#1673 and Jessie#7257 for helping with PTGI! */
        radiance += throughput * albedo * (texture(colortex1, hitPos.xy).z * EMISSION_INTENSITY);
        throughput *= albedo + specular;
        radiance += throughput * SUN_INTENSITY * viewPosSkyColor(viewPos) * texture(colortex9, hitPos.xy).rgb;
    }
    return radiance;
}
