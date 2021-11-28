/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

/*
                        - CREDITS -
    Thanks Bálint#1673 and Jessie#7257 for their huge help!
*/

vec3 specularBRDF(float NdotL, vec3 fresnel, in float roughness) {
    float k = roughness + 1.0;
    return fresnel * geometrySchlickGGX(NdotL, (k * k) * 0.125);
}

vec3 directBRDF(vec3 N, vec3 V, vec3 L, material mat, vec3 shadowmap) {
    float NdotL = maxEps(dot(N, L));

    vec3 specular = cookTorranceSpecular(N, V, L, mat);
    vec3 diffuse  = mat.isMetal ? vec3(0.0) : hammonDiffuse(N, V, L, mat);

    return (diffuse + specular) * (NdotL * shadowmap);
}

vec3 pathTrace(in vec3 screenPos) {
    vec3 radiance        = vec3(0.0);
    vec3 viewPos         = screenToView(screenPos); 
    vec3 sunIlluminance  = atmosphereTransmittance(atmosRayPos, playerSunDir)  * SUN_ILLUMINANCE;
    vec3 moonIlluminance = atmosphereTransmittance(atmosRayPos, playerMoonDir) * MOON_ILLUMINANCE;

    uint rngState = 185730U * uint(frameCounter) + uint(gl_FragCoord.x + gl_FragCoord.y * viewResolution.x);

    for(int i = 0; i < GI_SAMPLES; i++) {
        vec3 hitPos = screenPos; 
        vec3 rayDir = normalize(viewPos);
        vec3 prevDir;

        vec3 throughput = vec3(1.0);
        for(int j = 0; j <= GI_BOUNCES; j++) {
            prevDir = rayDir;
            vec2 noise = uniformAnimatedNoise(vec2(randF(rngState), randF(rngState)));

            /* Russian Roulette */
            if(j > 3) {
                float roulette = clamp01(max(throughput.r, max(throughput.g, throughput.b)));
                if(roulette < randF(rngState)) { break; }
                throughput /= roulette;
            }
            float HdotV = maxEps(dot(normalize(-prevDir + rayDir), -prevDir));

            /* Material Parameters */
            material mat = getMaterial(hitPos.xy);
            mat3 TBN = constructViewTBN(mat.normal);

            /* Specular Bounce Probability */
            float fresnelLum = luminance(specularFresnel(HdotV, mat.F0, getSpecularColor(mat.F0, mat.albedo), mat.isMetal));
            float diffuseLum = fresnelLum / (fresnelLum + luminance(mat.albedo) * (1.0 - float(mat.isMetal)) * (1.0 - fresnelLum));
            float specularProbability = fresnelLum / maxEps(fresnelLum + diffuseLum);
            bool specularBounce = specularProbability > randF(rngState);

            vec3 microfacet = sampleGGXVNDF(-prevDir * TBN, noise, pow2(mat.rough));
            rayDir = specularBounce ? reflect(prevDir, TBN * microfacet) : normalize(mat.normal + generateUnitVector(noise));

            radiance += throughput * mat.emission * mat.albedo;
            radiance += throughput * directBRDF(mat.normal, -prevDir, shadowDir, mat, texture(colortex9, hitPos.xy).rgb) * (sunIlluminance + moonIlluminance);

            if(!raytrace(screenToView(hitPos), rayDir, GI_STEPS, uniformNoise(i, blueNoise).y, hitPos)) { break; }

            float NdotL = maxEps(dot(mat.normal, rayDir));
            float HdotL = maxEps(dot(normalize(-prevDir + rayDir), rayDir));
            vec3 specularFresnel = specularFresnel(HdotL, mat.F0, getSpecularColor(mat.F0, mat.albedo), mat.isMetal);

            if(specularBounce) {
                throughput *= specularBRDF(NdotL, specularFresnel, mat.rough) / specularProbability;
            } else {
                throughput *= (1.0 - fresnelDielectric(NdotL, F0toIOR(mat.F0))) / (1.0 - specularProbability);
                throughput *= hammonDiffuse(mat.normal, -prevDir, rayDir, mat) / (NdotL * INV_PI);
            }
        }
    }
    return max0(radiance / float(GI_SAMPLES));
}
