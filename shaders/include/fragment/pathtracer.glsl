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

/*
    [Credits]:
        Bálint (https://github.com/BalintCsala)
        Jessie (https://github.com/Jessie-LC)
        Thanks to them for helping me understand the basics of path tracing when I was beginning
*/

vec3 evaluateMicrosurfaceOpaque(vec2 hitPosition, vec3 wi, vec3 wo, Material material, vec3 directIlluminance) {
    ivec2 hitTexel = ivec2(hitPosition * viewSize * GI_SCALE * 0.01);

    vec4 shadowmap = hitTexel == ivec2(0) ? vec4(0.0) : texelFetch(SHADOWMAP_BUFFER, hitTexel, 0);
    vec3 diffuse   = hammonDiffuse(material, wi, wo);

    #if SUBSURFACE_SCATTERING == 1
        diffuse += subsurfaceScatteringApprox(material, wi, wo, shadowmap.a) * float(material.lightmap.y > EPS);
    #endif

    return clamp16(material.albedo * diffuse * shadowmap.rgb * directIlluminance);
}

vec3 sampleMicrosurfaceOpaquePhase(inout vec3 estimate, inout vec3 wr, Material material) {
    mat3 tbn        = calculateTBN(material.normal);
    vec3 microfacet = tbn * sampleGGXVNDF(-wr * tbn, rand2F(), material.roughness);
    vec3 fresnel    = fresnelDielectricConductor(dot(microfacet, -wr), material.N, material.K);

    wr = generateCosineVector(microfacet, rand2F());

    vec3 energyConservationFactor = 1.0 - hemisphericalAlbedo(material.N / vec3(airIOR));

    vec3 phase = vec3(0.0);
    phase     = 1.0 - fresnel;
    phase    /= energyConservationFactor;
    phase    *= material.albedo * material.ao;
    estimate += material.albedo * EMISSIVE_INTENSITY * 100.0 * material.emission;
    phase    *= fresnelDielectricDielectric_T(dot(microfacet, wr), vec3(airIOR), material.N);
    
    return phase;
}

void pathtrace(sampler2D depthTex, mat4 projection, mat4 projectionInverse, vec3 directIlluminance, bool isMetal, out vec3 irradiance, in vec3 screenPosition, out vec3 direct) {
    vec3 viewPosition = screenToView(screenPosition, projectionInverse, true);

    for(int i = 0; i < GI_SAMPLES; i++) {

        vec3 rayPosition  = screenPosition; 
        vec3 rayDirection = normalize(viewPosition);
        Material material;

        vec3 throughput = vec3(1.0);
        vec3 estimate   = vec3(0.0);

        for(int j = 0; j < MAX_GI_BOUNCES; j++) {

            /* Russian Roulette */
            if(j > MIN_ROULETTE_BOUNCES) {
                float roulette = saturate(maxOf(throughput));
                if(roulette < randF()) { throughput = vec3(0.0); break; }
                throughput /= roulette;
            }
                
            material = getMaterial(rayPosition.xy);

            vec3 brdf  = evaluateMicrosurfaceOpaque(rayPosition.xy, -rayDirection, shadowVec, material, directIlluminance);
            vec3 phase = sampleMicrosurfaceOpaquePhase(estimate, rayDirection, material);

            vec3 tracePosition = screenToView(rayPosition, projectionInverse, true) + material.normal * 1e-3;
             
            bool hit = raytrace(depthTex, projection, tracePosition, rayDirection, MAX_GI_STEPS, randF(), 1.0, rayPosition);

            if(j == 0) {
                direct = brdf;
            } else {
                estimate += throughput * brdf; 
            }

            throughput *= (isMetal ? material.albedo : phase);

            if(!hit) {
                #if defined WORLD_OVERWORLD && SKY_CONTRIBUTION == 1
                    estimate += throughput * texture(ATMOSPHERE_BUFFER, projectSphere(rayPosition)).rgb * getSkylightFalloff(material.lightmap.y);
                #endif
                break;
            }

            if(dot(material.normal, rayDirection) <= 0.0) break;
        }
        irradiance += max0(estimate) * rcp(GI_SAMPLES);
    }
}
