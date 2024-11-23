/***********************************************/
/*          Copyright (C) 2024 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

void rainPuddles(vec3 scenePosition, vec3 geometricNormal, vec2 lightmapCoords, float porosity, inout float F0, inout float roughness, inout vec3 normal) {
    vec2 puddleCoords = ((scenePosition + cameraPosition).xz * 0.5 + 0.5) * (1.0 - RAIN_PUDDLES_SIZE * 0.01);

    float puddle  = saturate(FBM(puddleCoords, 3, 1.0) * 0.5 + 0.5);
          puddle *= pow2(quinticStep(0.0, 1.0, lightmapCoords.y));
          puddle *= quinticStep(0.89, 0.99, geometricNormal.y);
          puddle *= (1.0 - porosity);
          puddle *= wetness;
          puddle  = saturate(puddle);
          
    #if defined IS_IRIS
        puddle *= biome_may_rain;
    #endif

    F0        = clamp(F0 + waterF0 * puddle, 0.0, mix(1.0, 229.5 * rcpMaxFloat8, float(F0 * maxFloat8 <= 229.5)));
    roughness = mix(roughness, 0.0, puddle);
    normal    = mix(normal, geometricNormal, puddle);
}
