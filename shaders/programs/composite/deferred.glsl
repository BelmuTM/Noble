/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if defined STAGE_VERTEX

    out vec3 skyIlluminance;
    #include "/include/atmospherics/atmosphere.glsl"

    void main() {
        gl_Position = gl_ModelViewProjectionMatrix * gl_Vertex;
        texCoords   = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        skyIlluminance = sampleSkyIlluminance();
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 3,0,6,15,2 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out vec3 sky;
    layout (location = 2) out vec3 skyIllum;
    layout (location = 3) out vec4 clouds;
    layout (location = 4) out vec3 cloudsShadowmap;

    #include "/include/atmospherics/atmosphere.glsl"
    #include "/include/atmospherics/clouds.glsl"
    
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/ao.glsl"
    #include "/include/fragment/shadows.glsl"
    #include "/include/post/taa.glsl"

    in vec3 skyIlluminance;

    void main() {
        vec3 viewPos = getViewPos0(texCoords);
        Material mat = getMaterial(texCoords);

        #ifdef WORLD_OVERWORLD
            /*    ------- SHADOW MAPPING -------    */
            shadowmap.rgb = shadowMap(viewPos, viewToScene(mat.normal));

            /*    ------- ATMOSPHERIC SCATTERING -------    */
            vec3 skyRay   = normalize(unprojectSphere(texCoords * (1.0 / ATMOSPHERE_RESOLUTION)));
                 sky      = atmosphericScattering(skyRay, skyIlluminance);
                 skyIllum = skyIlluminance;

            #if CLOUDS == 1
                vec2 cloudsCoords = texCoords * (1.0 / CLOUDS_RESOLUTION);

                if(clamp01(cloudsCoords) == cloudsCoords) {
                    vec3 cloudsRay = normalize(unprojectSphere(cloudsCoords));
                         clouds    = cloudsScattering(cloudsRay);

                    vec3 prevPos    = reprojection(vec3(texCoords, texture(depthtex0, texCoords).r));
                    vec4 prevClouds = texture(colortex15, prevPos.xy);

                    float weight = float(getAtmosphereCoordinates(prevPos.xy, CLOUDS_RESOLUTION) == prevPos.xy);

                    vec2  velocity       = abs(texCoords - prevPos.xy) * viewSize;
                    float velocityWeight = exp(-length(velocity)) * 0.4 + 0.4;

                    weight *= clamp01(velocity) == velocity ? velocityWeight : 0.0;
                    clouds  = mix(clouds, prevClouds, weight);
                }

                //cloudsShadowmap = vec3(cloudsShadows(texCoords, sceneShadowDir, 8));
            #endif
        #endif
        
        #if AO == 1
            if(!isSky(texCoords)) {
                #if AO_TYPE == 0
                    shadowmap.a = computeSSAO(viewPos, mat.normal);
                #else
                    shadowmap.a = computeRTAO(viewPos, mat.normal);
                #endif
            }
        #else
            shadowmap.a = 1.0;
        #endif
    }
#endif
