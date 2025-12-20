/********************************************************************************/
/*                                                                              */
/*    Noble Shaders                                                             */
/*    Copyright (C) 2025  Belmu                                                 */
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

uniform vec3 upPosition;

float computeStarfield(vec3 viewPosition, vec3 lightVector) {
    vec3 sceneDirection = normalize(viewToScene(viewPosition));
         sceneDirection = rotate(sceneDirection, lightVector, vec3(0.0, 0.0, 1.0));

    vec3  position = sceneDirection * STARS_SCALE;
    vec3  index    = floor(position);
    float radius   = lengthSqr(position - index - 0.5);

    float VdotU = dot(normalize(viewPosition), upPosition);

    #if defined WORLD_END
        VdotU = abs(VdotU);
    #else
        VdotU = saturate(VdotU);
    #endif

    float factor = max0(sqrt(sqrt(VdotU)));

    float falloff = pow2(quinticStep(0.5, 0.0, radius));

    float rng = hash13(index);

    float star = 1.0;
    if (VdotU > 0.0) {
        star *= rng;
        star *= hash13(-index + 0.1);
    }
    star = saturate(star - (1.0 - STARS_AMOUNT * 0.0025));

    float luminosity = STARS_LUMINANCE * luminance(blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rng)));

    return star * factor * falloff * luminosity;
}

vec3 physicalSun(vec3 sceneDirection) {
    return dot(sceneDirection, sunVector) < cos(sunAngularRadius) ? vec3(0.0) : sunRadiance * RCP_PI;
}

vec3 physicalMoon(vec3 sceneDirection) {
    vec2 sphere = intersectSphere(-moonVector, sceneDirection, moonAngularRadius);

    Material moonMaterial;
    moonMaterial.normal    = normalize(sceneDirection * sphere.x - moonVector);
    moonMaterial.albedo    = vec3(moonAlbedo);
    moonMaterial.roughness = moonRoughness;
    moonMaterial.F0		   = 0.0;

    return sphere.y < 0.0 ? vec3(0.0) : moonMaterial.albedo * hammonDiffuse(moonMaterial, -sceneDirection, sunVector) * sunIrradiance;
}

vec3 physicalStar(vec3 sceneDirection) {
    return dot(sceneDirection, starVector) < cos(starAngularRadius) ? vec3(0.0) : starRadiance * RCP_PI;
}

vec3 sampleAtmosphere(vec3 direction, bool jitter, bool interpolate) {
    vec2 coords = projectSphere(direction);

    if (jitter) {
        float jitter = interleavedGradientNoise(gl_FragCoord.xy);
        coords += jitter * texelSize;
    }

    if (interpolate) {
        return textureBicubic(ATMOSPHERE_BUFFER, saturate(coords)).rgb;
    } else {
        return texture(ATMOSPHERE_BUFFER, saturate(coords)).rgb;
    }
}

vec3 renderAtmosphere(vec2 coords, vec3 viewPosition, vec3 directIlluminance, vec3 skyIlluminance) {
    #if defined WORLD_OVERWORLD || defined WORLD_END
        float jitter = interleavedGradientNoise(gl_FragCoord.xy);

        vec3 sceneDirection = normalize(viewToScene(viewPosition));
        vec3 sky            = sampleAtmosphere(sceneDirection, true, true);

        vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);
        #if defined WORLD_OVERWORLD
            #if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1
                vec3 cloudsBuffer = texture(CLOUDS_BUFFER, coords * rcp(RENDER_SCALE)).rgb;

                clouds.rgb = cloudsBuffer.r * directIlluminance + cloudsBuffer.g * skyIlluminance;
                clouds.a   = cloudsBuffer.b;
            #endif
            
        #elif defined WORLD_END
            sky += physicalStar(sceneDirection);
        #endif

        #if defined WORLD_OVERWORLD
            sky += computeStarfield(viewPosition, sunVector);
        #elif defined WORLD_END
            sky += computeStarfield(viewPosition, starVector) * 4.0;
        #endif

        return sky * clouds.a + clouds.rgb;
    #else
        return vec3(0.0);
    #endif
}

vec3 renderCelestialBodies(vec2 coords, vec3 viewPosition) {
    vec3 sceneDirection = normalize(viewToScene(viewPosition));

    float cloudsTransmittance = 0.0;

    #if defined WORLD_OVERWORLD && (CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1)
        cloudsTransmittance = texture(CLOUDS_BUFFER, coords * rcp(RENDER_SCALE)).b;
    #endif

    return (physicalSun(sceneDirection) + physicalMoon(sceneDirection)) * cloudsTransmittance;
}
