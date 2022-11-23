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
        directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;
    }

#elif defined STAGE_FRAGMENT

    #if GI == 1
        /* RENDERTARGETS: 0,6,12 */

        layout (location = 0) out vec4 sky;
        layout (location = 1) out vec3 skyIlluminance;
        layout (location = 2) out vec4 clouds;
    #else
        /* RENDERTARGETS: 0,6,10,12 */

        layout (location = 0) out vec4 sky;
        layout (location = 1) out vec3 skyIlluminance;
        layout (location = 2) out vec4 aoHistory;
        layout (location = 3) out vec4 clouds;
    #endif

    #if VOLUMETRIC_CLOUDS == 1 || PLANAR_CLOUDS == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    in mat3[2] skyIlluminanceMat;
    in vec3 skyMultiScatterIllum;
    in vec3 directIlluminance;

    void main() {
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);

        vec3 bentNormal = mat.normal;

        //////////////////////////////////////////////////////////
        /*-------- AMBIENT OCCLUSION / BENT NORMALS ------------*/
        //////////////////////////////////////////////////////////

        #if GI == 0 && AO == 1
            if(!isSky(texCoords)) {
                aoHistory = texture(colortex10, texCoords * AO_RESOLUTION);
                if(any(greaterThan(aoHistory.rgb, vec3(0.0)))) bentNormal = clamp01(aoHistory.rgb);
            }
        #endif

        #ifdef WORLD_OVERWORLD
            //////////////////////////////////////////////////////////
            /*------------- ATMOSPHERIC SCATTERING -----------------*/
            //////////////////////////////////////////////////////////

            if(ivec2(gl_FragCoord) != ivec2(0)) {
                skyIlluminance = mat.lightmap.y > EPS ? getSkyLight(viewToWorld(bentNormal), skyIlluminanceMat) : vec3(0.0);
            } else {
                skyIlluminance = directIlluminance;
            }

            if(clamp(texCoords, vec2(0.0), vec2(ATMOSPHERE_RESOLUTION)) == texCoords) {
                vec3 skyRay  = normalize(unprojectSphere(texCoords * rcp(ATMOSPHERE_RESOLUTION)));
                     sky.rgb = atmosphericScattering(skyRay, skyMultiScatterIllum);
            }

            //////////////////////////////////////////////////////////
            /*---------------- VOLUMETRIC VOLUMETRIC_CLOUDS -------------------*/
            //////////////////////////////////////////////////////////
            #if VOLUMETRIC_CLOUDS == 1 || PLANAR_CLOUDS == 1
                
                clouds = vec4(0.0, 0.0, 0.0, 1.0);

                if(clamp(texCoords, vec2(0.0), vec2(CLOUDS_RESOLUTION)) == texCoords) {
                    vec3 scaledViewDir = normalize(getViewPos1(texCoords * rcp(CLOUDS_RESOLUTION)));
                    vec3 cloudsRay     = mat3(gbufferModelViewInverse) * scaledViewDir;

                    vec4 cloudLayer0 = vec4(0.0, 0.0, 1.0, 1e6);
                    vec4 cloudLayer1 = vec4(0.0, 0.0, 1.0, 1e6);

                    #if VOLUMETRIC_CLOUDS == 1
                        CloudLayer layer0;
                        layer0.altitude  = CLOUDS_LAYER0_ALTITUDE;
                        layer0.thickness = CLOUDS_LAYER0_THICKNESS;
                        layer0.coverage  = CLOUDS_LAYER0_COVERAGE * 0.01;
                        layer0.swirl     = CLOUDS_LAYER0_SWIRL    * 0.01;
                        layer0.scale     = CLOUDS_LAYER0_SCALE;
                        layer0.frequency = CLOUDS_LAYER0_FREQUENCY;
                        layer0.density   = CLOUDS_LAYER0_DENSITY;
                        layer0.texDetail = CLOUDS_LAYER0_TEXDETAIL;
                        layer0.steps     = CLOUDS_SCATTERING_STEPS;
                        layer0.octaves   = CLOUDS_LAYER0_OCTAVES;

                        cloudLayer0 = cloudsScattering(layer0, cloudsRay);
                    #endif

                    #if PLANAR_CLOUDS == 1
                        CloudLayer layer1;
                        layer1.altitude  = CLOUDS_LAYER1_ALTITUDE;
                        layer1.thickness = CLOUDS_LAYER1_THICKNESS;
                        layer1.coverage  = CLOUDS_LAYER1_COVERAGE;
                        layer1.swirl     = CLOUDS_LAYER1_SWIRL;
                        layer1.scale     = CLOUDS_LAYER1_SCALE;
                        layer1.frequency = CLOUDS_LAYER1_FREQUENCY;
                        layer1.density   = CLOUDS_LAYER1_DENSITY;
                        layer1.texDetail = CLOUDS_LAYER1_TEXDETAIL;
                        layer1.steps     = 10;
                        layer1.octaves   = CLOUDS_LAYER1_OCTAVES;

                        cloudLayer1 = cloudsScattering(layer1, cloudsRay);
                    #endif

                    //sky.a = cloudsShadows(getCloudsShadowPos(gl_FragCoord.xy * rcp(cloudsShadowmapRes)), shadowLightVector, layer1, 64);

	                float distanceToClouds = min(cloudLayer0.a, cloudLayer1.a);

                    if(distanceToClouds > 0.0) {
                        vec2 scattering = cloudLayer1.rg * cloudLayer0.z + cloudLayer0.rg;
                        clouds.rgb     += scattering.r   * directIlluminance;
                        clouds.rgb     += scattering.g   * skyMultiScatterIllum;
                        clouds.a        = cloudLayer0.b  * cloudLayer1.b;

                        /* Reprojection */
                        vec2 prevPos    = reprojectClouds(viewPos, distanceToClouds).xy;
                        vec4 prevClouds = textureCatmullRom(colortex12, prevPos);

                        vec2  velocity       = (texCoords - prevPos) * viewSize;
                        float velocityWeight = clamp01(exp(-length(velocity)) * 0.9 + 0.1);

                        float weight = velocityWeight * float(clamp01(prevPos) == prevPos || any(greaterThan(prevClouds.rgb, vec3(0.0))));
                              weight = clamp01(0.98 * weight);

                        clouds = mix(clouds, prevClouds, weight);
                    }
                }
            #endif
        #endif
    }
#endif
