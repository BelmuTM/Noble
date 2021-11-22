/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#if STAGE == STAGE_VERTEX

    out vec3 skyIlluminance;

    #include "/include/utility/math.glsl"

    void main() {
        gl_Position = ftransform();
        texCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;

        ivec2 samples = ivec2(8);
        skyIlluminance = vec3(0.0);

        for(int x = 0; x < samples.x; x++) {
            for(int y = 0; y < samples.y; y++) {
                vec3 dir = generateUnitVector(vec2(x, y));
                skyIlluminance += texture(colortex7, projectSphere(dir) * ATMOSPHERE_RESOLUTION).rgb;
            }
        }
        skyIlluminance *= 1.0 / (samples.x + samples.y);
    }
#elif STAGE == STAGE_FRAGMENT

    in vec3 skyIlluminance;

    #include "/include/fragment/brdf.glsl"
    #include "/include/fragment/raytracer.glsl"
    #include "/include/fragment/shadows.glsl"
    #include "/include/atmospherics/fog.glsl"

    void main() {
        vec3 viewPos = getViewPos(texCoords);
        material mat = getMaterial(texCoords);

        #if WHITE_WORLD == 1
	        mat.albedo = vec3(1.0);
        #endif

        vec3 volumetricLighting = VL == 0 ? vec3(0.0) : volumetricLighting(viewPos);
        vec3 Lighting = mat.albedo;
    
        #if GI == 0
            if(!isSky(texCoords)) {
                vec3 shadowmap = texture(colortex9, texCoords).rgb;

                vec3 sunIlluminance  = atmosphereTransmittance(atmosRayPos, playerSunDir)  * SUN_ILLUMINANCE;
                vec3 moonIlluminance = atmosphereTransmittance(atmosRayPos, playerMoonDir) * MOON_ILLUMINANCE;
            
                Lighting = cookTorrance(viewPos, mat.normal, shadowDir, mat, shadowmap, sunIlluminance + moonIlluminance, skyIlluminance);
            }
        #endif

        /*DRAWBUFFERS:048*/
        gl_FragData[0] = vec4(Lighting,           1.0);
        gl_FragData[1] = vec4(mat.albedo,         1.0);
        gl_FragData[2] = vec4(volumetricLighting, 1.0);
    }
#endif
