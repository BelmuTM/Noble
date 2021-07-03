/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

#version 400 compatibility

varying vec2 texCoords;

#include "/settings.glsl"
#include "/lib/composite_uniforms.glsl"
#include "/lib/util/distort.glsl"
#include "/lib/frag/dither.glsl"
#include "/lib/frag/noise.glsl"
#include "/lib/util/math.glsl"
#include "/lib/util/transforms.glsl"
#include "/lib/util/utils.glsl"
#include "/lib/util/color.glsl"
#include "/lib/util/worldTime.glsl"
#include "/lib/material.glsl"
#include "/lib/lighting/brdf.glsl"
#include "/lib/lighting/shadows.glsl"
#include "/lib/lighting/ssao.glsl"
#include "/lib/atmospherics/volumetric.glsl"

/*
const int colortex0Format = RGBA16F;
*/

const float rainMinAmbientBrightness = 0.2;

/*------------------ LIGHTMAP ------------------*/
vec3 getLightmapColor(vec2 lightmap) {
    lightmap.x = TORCHLIGHT_MULTIPLIER * pow(lightmap.x, 5.06);
    
    vec3 TorchLight = lightmap.x * TORCH_COLOR;
    vec3 SkyLight = lightmap.y * skyColor;
    return vec3(TorchLight + clamp(SkyLight - rainStrength, 0.0, 1.0));
}

void main() {
    vec4 Result = vec4(0.0);

    vec3 viewPos = getViewPos();
    vec3 viewDir = normalize(-viewPos);
    vec3 lightPos = worldTime >= 12750 ? moonPosition : sunPosition;
    vec3 lightDir = normalize(lightPos);

    vec4 tex0 = texture2D(colortex0, texCoords);
    vec4 tex1 = texture2D(colortex1, texCoords);
    vec4 tex2 = texture2D(colortex2, texCoords);
    vec4 tex3 = texture2D(colortex3, texCoords);
    tex0.rgb = toLinear(tex0.rgb);

    if(texture2D(colortex8, texCoords).r == 0.0) {
        gl_FragData[0] = tex0;
        return;
    }
    material data = getMaterial(tex0, tex1, tex2, tex3);
    vec3 Normal = normalize(data.normal.xyz);
    float Depth = texture2D(depthtex0, texCoords).r;
    
    vec4 VolumetricLighting = vec4(0.0);
    #if VL == 1
        VolumetricLighting = vec4(clamp((getDayTimeSunColor() * computeVL(viewPos) * VL_BRIGHTNESS)
                             - rainStrength, 0.0, 1.0), 1.0);
    #endif

    if(Depth == 1.0) {
        /*DRAWBUFFERS:04*/
        gl_FragData[0] = tex0;
        gl_FragData[1] = VolumetricLighting;
        return;
    }

    #if WHITE_WORLD == 1
	    data.albedo = vec3(1.0);
    #endif
    vec3 outAlbedo = data.albedo;

    vec3 Shadow = vec3(1.0);
    #if SHADOWS == 1
        Shadow = shadowMap(shadowMapResolution);
    #endif

    vec3 AmbientOcclusion = vec3(1.0);
    #if SSAO == 1
        #if SSGI == 0
            AmbientOcclusion = computeSSAO(viewPos, Normal);
        #endif
    #endif

    vec3 ambient = AMBIENT;
    #if SSGI == 0
        vec2 lightmap = texture2D(colortex2, texCoords).zw;
        ambient = getLightmapColor(lightmap);
    #endif

    vec3 Lighting = Cook_Torrance(Normal, viewDir, lightDir, data, ambient, Shadow);
    Result.rgb += Lighting;

    if(getBlockId(texCoords) == 6) {
        float depthDist = distance(
		    linearizeDepth(texture2D(depthtex0, texCoords).r),
		    linearizeDepth(texture2D(depthtex1, texCoords).r)
	    );

        // Absorption
        depthDist = max(0.0, depthDist);
        float density = depthDist * 6.5e-1;

	    vec3 absorption = exp2(-(density / log(2.0)) * WATER_ABSORPTION_COEFFICIENTS);
        Result.rgb *= absorption;
        outAlbedo = data.albedo * absorption;

        // Foam
        #if WATER_FOAM == 1
            vec4 falloffColor = vec4(absorption, FOAM_BRIGHTNESS);

            if(depthDist < FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF && isEyeInWater == 0) {
                float falloff = (depthDist / FOAM_FALLOFF_DISTANCE) + FOAM_FALLOFF_BIAS;
                vec3 edge = falloffColor.rgb * falloff * falloffColor.a;

                float leading = depthDist / (FOAM_FALLOFF_DISTANCE * FOAM_EDGE_FALLOFF);
	            Result.rgb = mix(Result.rgb, Result.rgb + edge * Shadow, leading);
            }
        #endif
    }

    Result.a = data.alpha;

    /*DRAWBUFFERS:054*/
    gl_FragData[0] = Result;
    gl_FragData[1] = vec4(outAlbedo, AmbientOcclusion.r);
    gl_FragData[2] = VolumetricLighting;
}
