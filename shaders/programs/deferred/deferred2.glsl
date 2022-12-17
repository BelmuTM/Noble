/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX

    #include "/include/atmospherics/atmosphere.glsl"

    out vec3 skyIlluminance;
    out vec3 directIlluminance;

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminance    = sampleSkyIlluminanceSimple();
        directIlluminance = texelFetch(colortex6, ivec2(0), 0).rgb;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 clouds;

    #if PRIMARY_CLOUDS == 1 || SECONDARY_CLOUDS == 1
        #include "/include/atmospherics/clouds.glsl"
    #endif

    in vec3 skyIlluminance;
    in vec3 directIlluminance;

    void main() {
        #ifdef WORLD_OVERWORLD
            #if PRIMARY_CLOUDS == 1 || SECONDARY_CLOUDS == 1

                vec3 viewPos = getViewPos1(texCoords);
                clouds = vec4(0.0, 0.0, 0.0, 1.0);

                vec3 cloudsRay   = mat3(gbufferModelViewInverse) * normalize(viewPos);
                vec4 cloudLayer0 = vec4(0.0, 0.0, 1.0, 1e6);
                vec4 cloudLayer1 = vec4(0.0, 0.0, 1.0, 1e6);

                #if PRIMARY_CLOUDS == 1
                    CloudLayer layer0;
                    layer0.altitude   = CLOUDS_LAYER0_ALTITUDE;
                    layer0.thickness  = CLOUDS_LAYER0_THICKNESS;
                    layer0.coverage   = CLOUDS_LAYER0_COVERAGE * 0.01;
                    layer0.swirl      = CLOUDS_LAYER0_SWIRL    * 0.01;
                    layer0.scale      = CLOUDS_LAYER0_SCALE;
                    layer0.shapeScale = CLOUDS_LAYER0_SHAPESCALE;
                    layer0.frequency  = CLOUDS_LAYER0_FREQUENCY;
                    layer0.density    = CLOUDS_LAYER0_DENSITY;
                    layer0.steps      = CLOUDS_SCATTERING_STEPS;
                    layer0.octaves    = CLOUDS_LAYER0_OCTAVES;

                    cloudLayer0 = cloudsScattering(layer0, cloudsRay);
                #endif

                #if SECONDARY_CLOUDS == 1
                    CloudLayer layer1;
                    layer1.altitude   = CLOUDS_LAYER1_ALTITUDE;
                    layer1.thickness  = CLOUDS_LAYER1_THICKNESS;
                    layer1.coverage   = CLOUDS_LAYER1_COVERAGE;
                    layer1.swirl      = CLOUDS_LAYER1_SWIRL;
                    layer1.scale      = CLOUDS_LAYER1_SCALE;
                    layer1.shapeScale = CLOUDS_LAYER1_SHAPESCALE;
                    layer1.frequency  = CLOUDS_LAYER1_FREQUENCY;
                    layer1.density    = CLOUDS_LAYER1_DENSITY;
                    layer1.steps      = 10;
                    layer1.octaves    = CLOUDS_LAYER1_OCTAVES;

                    cloudLayer1 = cloudsScattering(layer1, cloudsRay);
                #endif

                //sky.a = cloudsShadows(getCloudsShadowPos(gl_FragCoord.xy * rcp(cloudsShadowmapRes)), shadowLightVector, layer1, 64);

                float distanceToClouds = min(cloudLayer0.a, cloudLayer1.a);

                if(distanceToClouds > 1e-6) {
                    vec2 scattering = cloudLayer1.rg * cloudLayer0.z + cloudLayer0.rg;
                    clouds.rgb     += scattering.r   * directIlluminance;
                    clouds.rgb     += scattering.g   * skyIlluminance;
                    clouds.a        = cloudLayer0.b  * cloudLayer1.b;

                    /* Reprojection */
                    vec2 prevPos    = reprojectClouds(viewPos, distanceToClouds).xy;
                    vec4 prevClouds = textureCatmullRom(colortex0, prevPos);

                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPos * viewSize) - 1.0);
                    float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.1 + 0.9;

                    vec2  velocity       = (texCoords - prevPos) * viewSize;
                    float velocityWeight = clamp01(exp(-length(velocity)) * 0.8 + 0.2);

                    float weight = centerWeight * velocityWeight * float(clamp01(prevPos) == prevPos);
                          clouds = mix(clouds, prevClouds, clamp01(weight));
                }
            #endif
        #endif
    }
#endif
