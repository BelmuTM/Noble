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

layout (location = 0) out uvec4 dataOut;

uniform usampler2D colortex1;

uniform sampler2D vxDepthTexOpaque;
uniform sampler2D vxDepthTexTrans;

#define modDepthTex0 vxDepthTexTrans
#define modDepthTex1 vxDepthTexOpaque

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/constants.glsl"

#include "/include/utility/math.glsl"
#include "/include/utility/color.glsl"

#include "/include/utility/transforms.glsl"

#include "/include/material/material.glsl"

#if RAIN_PUDDLES == 1
    #include "/include/material/rain_puddles.glsl"
#endif

void voxy_emitFragment(VoxyFragmentParameters voxyParameters) {
    uint blockId = max(0u, voxyParameters.customId - 1000u);
    
    vec3 albedo = voxyParameters.sampledColour.rgb * voxyParameters.tinting.rgb;

    #if WHITE_WORLD == 1
        albedo = vec3(1.0);
    #endif

    uint  axis = voxyParameters.face >> 1u;
    float sign = float((voxyParameters.face & 1u) * 2.0 - 1.0);

    vec3 normal = sign * vec3(
        bvec3(axis == 2u, axis == 0u, axis == 1u)
    );

    float F0 = 0.0;

    float roughness = saturate(hardcodedRoughness != 0.0 ? hardcodedRoughness : 1.0);

    // Rain puddles

    #if RAIN_PUDDLES == 1

        if (wetness > 0.0 && biome_may_rain > 0.0 && isEyeInWater == 0) {

            vec3 screenPosition = vec3(gl_FragCoord.xy * texelSize, gl_FragCoord.z);
            vec3 viewPosition   = screenToView(screenPosition, vxProjInv, false);
            vec3 scenePosition  = transform(vxModelViewInv, viewPosition);
            
            rainPuddles(scenePosition, normal, voxyParameters.lightMap, 0.0, albedo, normal, F0, roughness);

        }

    #endif

    // Hardcoded LabPBR values

    float emission = 0.0;

    #if HARDCODED_EMISSION == 1
    
        if (blockId >= LAVA_ID && blockId < SSS_ID && emission <= EPS) {
            emission = HARDCODED_EMISSION_VAL;
        }

    #endif

    float subsurface = 0.0;

    #if HARDCODED_SSS == 1

        if (blockId > NETHER_PORTAL_ID && blockId <= PLANTS_ID) {
            subsurface = 1.0;
        }

    #endif

    // Material encoding

    vec2 encodedNormal = encodeUnitVector(normalize(normal));

    dataOut = storeMaterial(
        F0,
        roughness,
        1.0,
        emission,
        subsurface,
        albedo,
        encodedNormal,
        voxyParameters.lightMap,
        1.0,
        blockId
    );
}
