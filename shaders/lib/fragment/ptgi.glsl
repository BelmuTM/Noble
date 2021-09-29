/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 PTGIBRDF(in vec3 viewDir, in vec2 screenPos, in vec3 sampleDir, in mat3 TBN, in vec3 normal, in vec2 noise, out vec3 albedo) {
    float F0 = texture(colortex2, screenPos).g;
    bool isMetal = F0 * 255.0 > 229.5;
    float roughness = texture(colortex2, screenPos).r;

    vec3 microfacet = sampleGGXVNDF(-viewDir * TBN, noise, roughness);
    vec3 reflected = reflect(viewDir, TBN * microfacet);

    vec3 H = normalize(viewDir + reflected);
    float NdotD = max(EPS, dot(normal, sampleDir));
    float NdotL = max(EPS, dot(normal, reflected)); 
    float NdotV = max(EPS, dot(normal, viewDir));
    float NdotH = max(EPS, dot(normal, H));
    float HdotL = max(EPS, dot(H, reflected));

    albedo = texture(colortex4, screenPos).rgb;
    vec3 specular = cookTorranceSpecular(NdotH, HdotL, NdotV, NdotL, roughness, F0, albedo, isMetal);
    // vec3 diffuse = orenNayarDiffuse(normal, viewDir, sampleDir, NdotD, NdotV, roughness * roughness, albedo) / (NdotD * INV_PI);

    vec3 fresnel = cookTorranceFresnel(NdotD, F0, albedo, isMetal);
    albedo *= 1.0 - fresnel;
    return albedo + specular;
}

vec3 computePTGI(in vec3 screenPos) {
    vec2 noise = hash22(gl_FragCoord.xy);
    vec3 hitPos = screenPos; vec3 viewPos = screenToView(screenPos); vec3 viewDir = -normalize(viewPos);

    vec3 normal = normalize(decodeNormal(texture(colortex1, hitPos.xy).xy));
    mat3 TBN = getTBN(normal);
    vec3 sampleDir = TBN * randomHemisphereDirection(noise);

    vec3 albedo;
    vec3 BRDF = PTGIBRDF(viewDir, hitPos.xy, sampleDir, TBN, normal, noise, albedo);

    vec3 throughput = GI_VISUALIZATION == 0 ? BRDF : vec3(1.0);
    vec3 radiance = vec3(0.0);

    for(int i = 0; i < GI_SAMPLES; i++) {
        for(int j = 0; j < GI_BOUNCES; j++) {
            noise = uniformAnimatedNoise(hash22(gl_FragCoord.xy + fract(frameTime)));

            /* Updating our position for the next bounce */
            normal = normalize(decodeNormal(texture(colortex1, hitPos.xy).xy));
            hitPos = screenToView(hitPos) + normal * EPS;
            TBN = getTBN(normal);
        
            /* Sampling a random direction in an hemisphere and raytracing in that direction */
            sampleDir = TBN * randomHemisphereDirection(noise);
            if(!raytrace(hitPos, sampleDir, GI_STEPS, uniformNoise(j, blueNoise).r, hitPos)) continue;

            /* Calculating the BRDF & applying it */
            BRDF = PTGIBRDF(viewDir, hitPos.xy, sampleDir, TBN, normal, noise, albedo);

            /* Thanks to BÃ¡lint#1673 and Jessie#7257 for helping with PTGI! */
            radiance += throughput * albedo * (texture(colortex1, hitPos.xy).z * EMISSION_INTENSITY);
            throughput *= BRDF;
            radiance += throughput * SUN_INTENSITY * viewPosSkyColor(viewPos) * texture(colortex9, hitPos.xy).rgb;
        }
    }
    radiance /= GI_SAMPLES;
    return radiance;
}
