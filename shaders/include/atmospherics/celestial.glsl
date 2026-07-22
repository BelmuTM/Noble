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

uniform vec3 upPosition;

float starfield(vec3 viewPosition, vec3 lightVector) {
    vec3 sceneDirection = normalize(viewToWorld(viewPosition));
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

    float angularFactor = max0(sqrt(sqrt(VdotU)));

    float falloff = pow2(quinticStep(0.5, 0.0, radius));

    float rng = hash13(index);

    float star = 1.0;
    
    if (VdotU > 0.0) {
        star *= rng;
        star *= hash13(-index + 0.1);
    }

    star = saturate(star - (1.0 - STARS_AMOUNT * 0.0025));

    float luminosity = STARS_LUMINANCE * luminance(blackbody(mix(STARS_MIN_TEMP, STARS_MAX_TEMP, rng)));

    return star * angularFactor * falloff * luminosity;
}

vec3 physicalSun(vec3 sceneDirection) {
    return dot(sceneDirection, sunVector) < cos(sunAngularRadius) ? vec3(0.0) : sunRadiance * RCP_PI;
}

vec3 physicalMoon(vec3 sceneDirection) {
    vec2 sphere = intersectSphere(-moonVector, sceneDirection, moonAngularRadius);

    if (sphere.y >= 0.0) {
        vec3 moonNormal = normalize(sceneDirection * sphere.x - moonVector);

        const vec3  moonAlbedo = vec3(moonAlbedo);
        const float moonAlpha  = moonRoughness * moonRoughness;
        const float moonF0     = 0.02;

        vec3 moonN = vec3(f0ToIOR(moonF0));

        return moonAlbedo * hammonDiffuse(-sceneDirection, sunVector, moonAlbedo, moonNormal, moonN, moonF0, moonAlpha) * sunIrradiance;
    } else {
        return vec3(0.0);
    }
}

vec3 physicalStar(vec3 sceneDirection) {
    return dot(sceneDirection, starVector) < cos(starAngularRadius) ? vec3(0.0) : starRadiance * RCP_PI;
}

vec3 renderAtmosphere(vec2 coords, vec3 viewPosition, vec3 directIlluminance, vec3 skyIlluminance) {
    vec3 sceneDirection = normalize(viewToWorld(viewPosition));

    vec3 atmosphere = textureBicubic(ATMOSPHERE_BUFFER, saturate(projectSphere(sceneDirection))).rgb;

    vec4 clouds = vec4(0.0, 0.0, 0.0, 1.0);

    #if defined WORLD_OVERWORLD && (CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1)

        vec4 cloudsBuffer = texture(CLOUDS_BUFFER, coords * rcp(RENDER_SCALE));

        // Clouds aerial perspective
        float distanceFalloff = pow5(1.0 - quinticStep(0.0, 1.0, exp(-4e-5 * cloudsBuffer.a)));

        cloudsBuffer.rgb = mix(cloudsBuffer.rgb, vec3(0.0, 0.0, 1.0), distanceFalloff);

        clouds.rgb = cloudsBuffer.r * directIlluminance + cloudsBuffer.g * skyIlluminance;
        clouds.a   = cloudsBuffer.b;
        
    #endif

    return atmosphere * clouds.a + clouds.rgb;
}

vec3 renderCelestialBodies(vec2 coords, vec3 viewPosition) {
    vec3 sceneDirection = normalize(viewToWorld(viewPosition));

    vec3 celestialBodies = vec3(0.0);

    float cloudsTransmittance = 1.0;

    float stars = starfield(viewPosition, sunVector);

    #if defined WORLD_OVERWORLD

        vec3 viewTransmittance = evaluateAtmosphereTransmittance(atmosphereRayPosition, sceneDirection, atmosphereAttenuationCoefficients);
        
        celestialBodies += (physicalSun(sceneDirection) + physicalMoon(sceneDirection)) * viewTransmittance;
        celestialBodies += stars;

        #if CLOUDS_LAYER0_ENABLED == 1 || CLOUDS_LAYER1_ENABLED == 1

            cloudsTransmittance = texture(CLOUDS_BUFFER, coords * rcp(RENDER_SCALE)).b;

        #endif

    #elif defined WORLD_END

        celestialBodies += physicalStar(sceneDirection);
        celestialBodies += stars * 4.0;

    #endif

    return clamp16(celestialBodies * pow5(cloudsTransmittance));
}
