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

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#define MIN_RAIN_BRIGHTNESS 6.0

#if defined STAGE_VERTEX

    out vec2 textureCoords;
    out vec3 skyIlluminance;

    #if defined WORLD_OVERWORLD || defined WORLD_END
        #include "/include/utility/phase.glsl"

        #include "/include/atmospherics/constants.glsl"
        #include "/include/atmospherics/atmosphere.glsl"
    #endif

    void main() {
        textureCoords = gl_MultiTexCoord0.xy;

        // Boosted sky illuminance by 10x for stylization
        skyIlluminance = evaluateUniformSkyIrradianceApproximation() * 10.0;

        vec3 scenePosition = transform(gbufferModelViewInverse, transform(gl_ModelViewMatrix, gl_Vertex.xyz));

        #if WEATHER_TILT == 1
            const float weatherTiltAngleX = radians(WEATHER_TILT_ANGLE_X), weatherTiltAngleZ = radians(WEATHER_TILT_ANGLE_Z);

            vec2 weatherTiltRotation = vec2(cos(weatherTiltAngleX), sin(weatherTiltAngleZ));
            vec2 weatherTiltOffset   = weatherTiltRotation * (cos(length(scenePosition + cameraPosition) * 5.0) * 0.2 + 0.8);

            scenePosition.xz += weatherTiltOffset * scenePosition.y;
        #endif

        gl_Position    = project(gl_ProjectionMatrix, transform(gbufferModelView, scenePosition));
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0 */

    layout (location = 0) out vec4 color;

    in vec2 textureCoords;
    in vec3 skyIlluminance;

    uniform sampler2D gtexture;

    vec4 computeRainColor() {
        const float density               = 1.0;
        const float scatteringCoefficient = 0.1;
        const float alpha                 = 0.2;

        #if TONEMAP == ACES
            const vec3 attenuationCoefficients = vec3(0.338675, 0.0493852, 0.00218174) * SRGB_2_AP1_ALBEDO;
        #else
            const vec3 attenuationCoefficients = vec3(0.338675, 0.0493852, 0.00218174);
        #endif

        return vec4(exp(-attenuationCoefficients * density) * scatteringCoefficient, alpha);
    }

    void main() {
        color = vec4(0.0);

        vec2 fragCoords = gl_FragCoord.xy * texelSize / RENDER_SCALE;
        if (saturate(fragCoords) != fragCoords) { discard; return; }

        vec4 albedo = texture(gtexture, textureCoords);

        if (albedo.a < 0.102) { discard; return; }

        bool isRain = (abs(albedo.r - albedo.b) > EPS);

        if (isRain) {
            color = computeRainColor();
        } else {
            color = vec4(1.0, 1.0, 1.0, 0.3);
        }

        color.rgb *= skyIlluminance;

        color.rgb = max0(log2(color.rgb + 1.0));
    }
    
#endif
