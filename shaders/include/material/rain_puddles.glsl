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

float calculatePuddleRipples(vec2 position) {
    const mat4x2 rippleOffsets = mat4x2(vec2(0.08, 0.13), vec2(0.1, -0.2), vec2(-0.25, 0.12), vec2(-0.13, -0.23));

    float time = frameTimeCounter * 1.1;

    float ripple  = texture(noisetex, position + time * rippleOffsets[0]).a * 0.25;
          ripple += texture(noisetex, position + time * rippleOffsets[1]).a * 0.25;
          ripple += texture(noisetex, position + time * rippleOffsets[2]).a * 0.25;
          ripple += texture(noisetex, position + time * rippleOffsets[3]).a * 0.25;

    return ripple;
}

vec3 getPuddleNormals(vec2 position, float strength) {
    const float dStep = 1e-3;

    vec2 steps;
    steps.x = calculatePuddleRipples(position + vec2( dStep, -dStep));
    steps.y = calculatePuddleRipples(position + vec2(-dStep,  dStep));
    steps  -= calculatePuddleRipples(position + vec2(-dStep, -dStep));
    steps  *= strength;

    return normalize(vec3(-steps.x, dStep * 2.0, -steps.y));
}

void rainPuddles(
    vec3 scenePosition,
    vec3 geometricNormal,
    vec2 lightmapCoords,
    float porosity,
    inout vec3 albedo,
    inout vec3 normal,
    inout float F0,
    inout float roughness
) {
    const float puddleScalingFactor = 1.0 - RAIN_PUDDLES_SIZE * 0.01; // 100% - X%
    
    vec2 puddleCoords = ((scenePosition + cameraPosition).xz * 0.5 + 0.5) * puddleScalingFactor;

    float puddle  = saturate(texture(noisetex, puddleCoords * 0.1).a * 0.6 + 0.4);
          puddle *= pow2(quinticStep(0.0, 1.0, lightmapCoords.y));
          puddle *= linearStep(0.89, 0.99, geometricNormal.y);
          puddle *= (1.0 - porosity);
          puddle *= wetness * biome_may_rain;
          puddle  = saturate(puddle);

    albedo *= 1.0 - puddle * RAIN_PUDDLES_ABSORPTION;

    vec3 surfaceNormal = mix(geometricNormal, getPuddleNormals(puddleCoords, 0.1), rainStrength * 0.1);

    F0        = max(F0, mix(F0, waterF0, puddle));
    roughness = mix(roughness, 0.0, puddle);
    normal    = mix(normal, surfaceNormal, puddle * puddle);
}
