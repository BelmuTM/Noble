/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
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
                    cloudLayer0 = cloudsScattering(layer0, cloudsRay);
                #endif

                #if SECONDARY_CLOUDS == 1
                    cloudLayer1 = cloudsScattering(layer1, cloudsRay);
                #endif

                float distanceToClouds = min(cloudLayer0.a, cloudLayer1.a);

                if(distanceToClouds > 1e-6) {
                    vec2 scattering = cloudLayer1.rg * cloudLayer0.z + cloudLayer0.rg;
                    clouds.rgb     += scattering.r   * directIlluminance;
                    clouds.rgb     += scattering.g   * skyIlluminance;
                    clouds.a        = cloudLayer0.b  * cloudLayer1.b;

                    /* Reprojection */
                    vec2 prevPos    = reprojectClouds(viewPos, distanceToClouds).xy;
                    vec4 prevClouds = textureCatmullRom(colortex0, prevPos);

                    float resolutionScale = CLOUDS_SCALE < 100 ? 1.0 + ((CLOUDS_SCALE * 0.01) * 0.2 + 0.3) : 1.0;

                    vec2 pixelCenterDist = 1.0 - abs(2.0 * fract(prevPos * viewSize) - 1.0);
                    float centerWeight   = sqrt(pixelCenterDist.x * pixelCenterDist.y) * 0.4 + 0.6;

                    vec2  velocity       = (texCoords - prevPos) * viewSize;
                    float velocityWeight = exp(-length(velocity)) * 0.8 + 0.2;

                    float weight = centerWeight * velocityWeight * resolutionScale * float(clamp01(prevPos) == prevPos);
                          clouds = mix(clouds, prevClouds, clamp01(weight));
                }
            #endif
        #endif
    }
#endif
