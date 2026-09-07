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

#include "/settings.glsl"
#include "/include/taau_scale.glsl"

#include "/include/common.glsl"

#define MIN_RAIN_BRIGHTNESS 6.0

#if defined STAGE_VERTEX

    out vec2 textureCoords;

    #if defined OVERWORLD_OR_END

        #include "/include/atmospherics/illuminance_fetch.glsl"

        flat out vec3 skyIlluminance;

    #endif

    void main() {
        textureCoords = gl_MultiTexCoord0.xy;

        #if defined OVERWORLD_OR_END

            skyIlluminance = UNIFORM_SKY_ILLUMINANCE();

        #endif

        vec3 scenePosition = transform(gbufferModelViewInverse, transform(gl_ModelViewMatrix, gl_Vertex.xyz));

        const float weatherTiltAngleX = radians(90.0 - float(WEATHER_TILT_ANGLE_X));
        const float weatherTiltAngleZ = radians(WEATHER_TILT_ANGLE_Z);

        vec2 weatherTiltRotation = vec2(cos(weatherTiltAngleX), sin(weatherTiltAngleZ));
        vec2 weatherTiltOffset   = weatherTiltRotation * (cos(length(scenePosition + cameraPosition) * 5.0) * 0.2 + 0.8);

        scenePosition.xz += weatherTiltOffset * scenePosition.y;

        gl_Position    = project(gl_ProjectionMatrix, transform(gbufferModelView, scenePosition));
        gl_Position.xy = gl_Position.xy * RENDER_SCALE + (RENDER_SCALE - 1.0) * gl_Position.w;

        TAA_JITTER(gl_Position);
    }

#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 15 */

    layout (location = 0) out vec4 color;

    in vec2 textureCoords;

    #if defined OVERWORLD_OR_END

        flat in vec3 skyIlluminance;

    #endif

    uniform sampler2D gtexture;

    const vec3 rainColor = vec3(1.0, 1.0, 1.0);

    const vec3 snowColor = vec3(1.0, 1.0, 1.0);

    void main() {

        color = vec4(0.0);

        #if defined OVERWORLD_OR_END
        
            #if DOWNSCALED_RENDERING == 1
                vec2 fragCoords = gl_FragCoord.xy * texelSize;
                if (!insideScreenBounds(fragCoords, RENDER_SCALE)) { return; }
            #endif

            vec4 albedo = texture(gtexture, textureCoords);

            if (albedo.a < alphaTestThreshold) { discard; return; }

            bool isRain = abs(albedo.r - albedo.b) > EPS;

            color = isRain
                  ? vec4(rainColor, RAIN_OPACITY)
                  : vec4(snowColor, SNOW_OPACITY);
            
            color.rgb *= saturate(skyIlluminance * 1e-5);

            color.rgb *= color.a;
            
        #endif
    }
    
#endif
