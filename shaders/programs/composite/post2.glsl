/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

/* RENDERTARGETS: 4 */

layout (location = 0) out vec3 color;

#if BLOOM == 1
    #include "/include/utility/sampling.glsl"
    #include "/include/post/bloom.glsl"
#endif

// Rod response coefficients & blending method provided by Jessie#7257
// SOURCE: http://www.diva-portal.org/smash/get/diva2:24136/FULLTEXT01.pdf
#if PURKINJE == 1
    vec3 rodResponse = vec3(7.15e-5, 4.81e-1, 3.28e-1);

    void purkinje(inout vec3 color) {
        #if TONEMAP == 0
            mat3 toXYZ = SRGB_2_XYZ_MAT, fromXYZ = XYZ_2_SRGB_MAT;
        #else
            rodResponse *= SRGB_2_AP1_ALBEDO;
            mat3 toXYZ   = AP1_2_XYZ_MAT, fromXYZ = XYZ_2_AP1_MAT;
        #endif
        vec3 xyzColor = color * toXYZ;

        vec3 scotopicLum = xyzColor * (1.33 * (1.0 + (xyzColor.y + xyzColor.z) / xyzColor.x) - 1.68);
        float purkinje   = dot(rodResponse, scotopicLum * fromXYZ);

        color = mix(color, purkinje * vec3(0.56, 0.67, 1.0), exp2(-purkinje * 20.0));
    }
#endif

#if TONEMAP == 0
    #include "/include/post/aces/lib/splines.glsl"
    #include "/include/post/aces/lib/transforms.glsl"

    #include "/include/post/aces/rrt.glsl"
    #include "/include/post/aces/odt.glsl"
#endif

#if TONEMAP >= 0
    void tonemap(inout vec3 color) {
        #if TONEMAP == 0           // ACES
            rrt(color);
            odt(color);
        #elif TONEMAP == 1         // Burgess
            burgess(color);
        #elif TONEMAP == 2         // Reinhard-Jodie
            reinhardJodie(color);
        #elif TONEMAP == 3         // Lottes
            lottes(color);
        #elif TONEMAP == 4         // Uchimura
            uchimura(color);
        #elif TONEMAP == 5         // Uncharted 2
            uncharted2(color);
        #endif
    }
#endif

void main() {
    vec4 tmp = texture(colortex4, texCoords);
    color    = tmp.rgb / tmp.a;

    #if BLOOM == 1
        // https://google.github.io/filament/Filament.md.html#imagingpipeline/physicallybasedcamera/bloom
        color += readBloom() * exp2(tmp.a + BLOOM_STRENGTH - 8.0);
    #endif

    #if PURKINJE == 1
        purkinje(color);
    #endif

    color *= tmp.a;
    
    // Tonemapping & Color Grading
    whiteBalance(color);
    vibrance(color,   1.0 + VIBRANCE);
    saturation(color, 1.0 + SATURATION);
    contrast(color,   1.0 + CONTRAST);
    liftGammaGain(color, LIFT * 0.1, 1.0 + GAMMA, 1.0 + GAIN);

    #if TONEMAP >= 0
        tonemap(color);
    #endif

    #if TONEMAP != 0 && TONEMAP != 1
        color = linearToSrgb(color);
    #endif
    color = clamp01(color);
}
