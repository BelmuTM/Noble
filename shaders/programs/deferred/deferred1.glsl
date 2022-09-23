/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#include "/include/atmospherics/atmosphere.glsl"

#ifdef STAGE_VERTEX

    out mat3[2] skyIlluminanceMat;
    out vec3 skyMultiScatterIllum;
    out vec3 directIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminanceMat = sampleSkyIlluminance(skyMultiScatterIllum);
        directIlluminance = texture(colortex15, texCoords).rgb;
    }

#elif defined STAGE_FRAGMENT

    #if GI == 1
        /* RENDERTARGETS: 3,0,6,12 */

        layout (location = 0) out vec4 shadowmap;
        layout (location = 1) out vec3 sky;
        layout (location = 2) out vec3 skyIlluminance;
        layout (location = 3) out vec4 clouds;
    #else
        /* RENDERTARGETS: 3,0,6,10,12 */

        layout (location = 0) out vec4 shadowmap;
        layout (location = 1) out vec3 sky;
        layout (location = 2) out vec3 skyIlluminance;
        layout (location = 3) out vec4 aoHistory;
        layout (location = 4) out vec4 clouds;
    #endif

    #if CLOUDS == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif
    
    #include "/include/fragment/shadows.glsl"

    in mat3[2] skyIlluminanceMat;
    in vec3 skyMultiScatterIllum;
    in vec3 directIlluminance;

    #if GI == 0 && AO == 1 && AO_FILTER == 1
        float filterAO(sampler2D tex, vec2 coords, Material mat, float scale, float radius, float sigma, int steps) {
            float ao = 0.0, totalWeight = 0.0;

            for(int x = -steps; x <= steps; x++) {
                for(int y = -steps; y <= steps; y++) {
                    vec2 offset         = vec2(x, y) * radius * pixelSize;
                    vec2 sampleCoords   = (coords * scale) + offset;
                    if(clamp01(sampleCoords) != sampleCoords) continue;

                    Material sampleMat = getMaterial(coords + offset);

                    float weight  = gaussianDistrib2D(vec2(x, y), sigma);
                          weight *= getDepthWeight(mat.depth0, sampleMat.depth0,  2.0);
                          weight *= getNormalWeight(mat.normal, sampleMat.normal, 8.0);
                          weight  = clamp01(weight);

                    ao          += texture(tex, sampleCoords).a * weight;
                    totalWeight += weight;
                }
            }
            return clamp01(ao * (1.0 / totalWeight));
        }
    #endif

    void main() {
        vec3 viewPos  = getViewPos0(texCoords);
        Material mat  = getMaterial(texCoords);
        bool skyCheck = isSky(texCoords);

        vec3 bentNormal = mat.normal;

        //////////////////////////////////////////////////////////
        /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0 && AO == 1
            if(!skyCheck) {
                vec4 ao = texture(colortex10, texCoords * AO_RESOLUTION);
                if(any(greaterThan(ao.rgb, vec3(0.0)))) bentNormal = clamp01(ao.rgb);

                aoHistory = ao;

                #if AO_FILTER == 1
                    aoHistory.a = filterAO(colortex10, texCoords, mat, AO_RESOLUTION, 0.3, 2.0, 2);
                #endif
            }
        #endif

        #ifdef WORLD_OVERWORLD
            //////////////////////////////////////////////////////////
            /*------------- ATMOSPHERIC SCATTERING -----------------*/
            //////////////////////////////////////////////////////////
            skyIlluminance = mat.lightmap.y > EPS ? getSkyLight(bentNormal, skyIlluminanceMat) : vec3(0.0);

            if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION)) == texCoords) {
                vec3 skyRay = normalize(unprojectSphere(texCoords * rcp(ATMOSPHERE_RESOLUTION)));
                     sky    = atmosphericScattering(skyRay, skyMultiScatterIllum);
            }

            //////////////////////////////////////////////////////////
            /*----------------- SHADOW MAPPING ---------------------*/
            //////////////////////////////////////////////////////////
            vec4 tmp = texture(colortex2, texCoords);

            shadowmap.a    = 0.0;
            shadowmap.rgb  = !skyCheck ? shadowMap(viewToScene(viewPos), tmp.rgb, shadowmap.a) : vec3(1.0);
            shadowmap.rgb *= tmp.a;

            //////////////////////////////////////////////////////////
            /*---------------- VOLUMETRIC CLOUDS -------------------*/
            //////////////////////////////////////////////////////////
            #if CLOUDS == 1
                
                clouds = vec4(0.0, 0.0, 0.0, 1.0);

                if(clamp(texCoords, vec2(0.0), vec2(CLOUDS_RESOLUTION)) == texCoords) {
                    vec3 scaledViewDir = normalize(getViewPos1(texCoords * rcp(CLOUDS_RESOLUTION)));
                    vec3 cloudsRay     = mat3(gbufferModelViewInverse) * scaledViewDir;

                    CloudLayer layer0;
                    layer0.altitude  = CLOUDS_LAYER0_ALTITUDE;
                    layer0.thickness = CLOUDS_LAYER0_THICKNESS;
                    layer0.coverage  = CLOUDS_LAYER0_COVERAGE;
                    layer0.swirl     = CLOUDS_LAYER0_SWIRL;
                    layer0.scale     = CLOUDS_LAYER0_SCALE;
                    layer0.frequency = CLOUDS_LAYER0_FREQUENCY;
                    layer0.density   = CLOUDS_LAYER0_DENSITY;
                    layer0.steps     = CLOUDS_SCATTERING_STEPS;

                    CloudLayer layer1;
                    layer1.altitude  = CLOUDS_LAYER1_ALTITUDE;
                    layer1.thickness = CLOUDS_LAYER1_THICKNESS;
                    layer1.coverage  = CLOUDS_LAYER1_COVERAGE;
                    layer1.swirl     = CLOUDS_LAYER1_SWIRL;
                    layer1.scale     = CLOUDS_LAYER1_SCALE;
                    layer1.frequency = CLOUDS_LAYER1_FREQUENCY;
                    layer1.density   = CLOUDS_LAYER1_DENSITY;
                    layer1.steps     = 10;
                    
                    vec4 cloudLayer0 = cloudsScattering(layer0, cloudsRay);
                    vec4 cloudLayer1 = cloudsScattering(layer1, cloudsRay);

                    vec2 scattering   = cloudLayer1.rg * cloudLayer0.z + cloudLayer0.rg;
	                float distToCloud = min(cloudLayer0.a, cloudLayer1.a);

                    clouds.rgb += scattering.r  * directIlluminance;
                    clouds.rgb += scattering.g  * skyMultiScatterIllum;
                    clouds.a    = cloudLayer0.b * cloudLayer1.b;

                    /* Aerial Perspective */
                    clouds = mix(vec4(0.0, 0.0, 0.0, 1.0), clouds, exp(-1e-4 * distToCloud));

                    /* Reprojection */
                    vec3 prevPos    = reprojectClouds(viewPos, 1e8 * distToCloud);
                    vec4 prevClouds = texture(colortex12, prevPos.xy);

                    // Offcenter rejection from Zombye#7365 (Spectrum - https://github.com/zombye/spectrum)
                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPos.xy * viewSize) - 1.0);
                    float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.5 + 0.5;

                    vec2  velocity       = (texCoords - prevPos.xy) * viewSize;
                    float velocityWeight = exp(-length(velocity)) * 0.65 + 0.35;

                    float weight = clamp01(centerWeight * velocityWeight * float(clamp01(prevPos.xy) == prevPos.xy));

                    clouds = mix(clouds, prevClouds, 0.9 * weight);
                }
            #endif
        #endif
    }
#endif
