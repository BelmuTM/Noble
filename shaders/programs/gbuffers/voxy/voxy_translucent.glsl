/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2026  Belmu                                                 */
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

uniform usampler2D colortex1;
uniform sampler2D colortex3;

uniform sampler2D vxDepthTexOpaque;
uniform sampler2D vxDepthTexTrans;

#define modDepthTex0 vxDepthTexTrans
#define modDepthTex1 vxDepthTexOpaque

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/constants.glsl"

#include "/include/utility/math.glsl"
#include "/include/utility/color.glsl"
#include "/include/utility/rng.glsl"
#include "/include/utility/transforms.glsl"

#include "/include/atmospherics/atmosphere_header.glsl"
#include "/include/atmospherics/illuminance_fetch.glsl"

#include "/include/material/material.glsl"
#include "/include/material/brdf.glsl"

#include "/include/fragment/water.glsl"

#include "/include/post/exposure.glsl"

layout (location = 0) out uvec4 dataOut;
layout (location = 1) out vec4 translucentsOut;

void voxy_emitFragment(VoxyFragmentParameters voxyParameters) {
    uint blockId = max(0u, voxyParameters.customId - 1000u);

    vec3 albedo = voxyParameters.sampledColour.rgb * voxyParameters.tinting.rgb;

    Material material;

    translucentsOut = vec4(0.0);

    material.lightmap = saturate(voxyParameters.lightMap);

    uint  axis = voxyParameters.face >> 1u;
    float sign = float((voxyParameters.face & 1) * 2.0 - 1.0);

    material.normal = sign * vec3(
        bvec3(axis == 2u, axis == 0u, axis == 1u)
    );

    material.ao         = 1.0;
    material.subsurface = 0.0;

    vec3 screenPosition = vec3(gl_FragCoord.xy * texelSize, gl_FragCoord.z);
    vec3 viewPosition   = screenToView(screenPosition, vxProjInv, false);
    vec3 scenePosition  = transform(vxModelViewInv, viewPosition);

    // WOTAH
    if (blockId == WATER_ID) {

        material.F0        = waterF0;
        material.alpha     = 0.0;
        material.emission  = 0.0;
        albedo             = vec3(0.0);

        const mat3 tbn = mat3(
            vec3(1.0, 0.0, 0.0),
            vec3(0.0, 0.0, 1.0),
            vec3(0.0, 1.0, 0.0)
        );

        material.normal = getWaterNormal(scenePosition + cameraPosition, material.normal, WATER_OCTAVES);

    } else {

        // Forward diffuse lighting

        material.F0 = 0.0;

        material.alpha = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 0.0);

        #if HARDCODED_EMISSION == 1
            if (blockId >= LAVA_ID && blockId < SSS_ID) {
                material.emission = HARDCODED_EMISSION_VAL;
            }
        #endif

        #if WHITE_WORLD == 1
            material.albedo = vec3(1.0);
        #endif

        #if TONEMAP == ACES
            material.albedo = srgbToAP1Albedo(albedo);
        #else
            material.albedo = srgbToLinear(albedo);
        #endif

        material.N = vec3(f0ToIOR(material.F0));
        material.K = vec3(0.0);

        const vec4 shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

        vec3 directIlluminance = vec3(0.0);
        vec3 skyIlluminance    = vec3(0.0);

        #if defined WORLD_OVERWORLD || defined WORLD_END

            directIlluminance = DIRECT_ILLUMINANCE();
            skyIlluminance    = UNIFORM_SKY_ILLUMINANCE();
            
        #endif

        translucentsOut.rgb = computeDiffuse(
            scenePosition,
            shadowLightVectorWorld,
            material,
            false,
            shadowmap,
            directIlluminance,
            skyIlluminance,
            1.0,
            1.0
        );

        translucentsOut.rgb *= CURRENT_EXPOSURE();

        translucentsOut.a = voxyParameters.sampledColour.a;

    }

    // Material encoding
    
    vec2 encodedNormal = encodeUnitVector(normalize(material.normal));

    dataOut = storeMaterial(
        material.F0,
        material.alpha,
        material.ao,
        material.emission,
        material.subsurface,
        albedo,
        encodedNormal,
        material.lightmap,
        1.0,
        blockId
    );
}
