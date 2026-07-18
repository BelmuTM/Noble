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

#include "/include/utility/rng.glsl"

#if defined STAGE_VERTEX

    #define attribute in
    attribute vec4 at_tangent;
    attribute vec3 at_midBlock;
    attribute vec3 mc_Entity;
    attribute vec2 mc_midTexCoord;

    flat out int blockId;
    out vec2 textureCoords;
    out vec3 worldPosition;
    out vec4 vertexColor;

    #if ANIMATIONS_ENABLED
        uniform float rcp240;
    #endif

    #include "/include/vertex/animation.glsl"

    void main() {
        textureCoords = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
        vertexColor   = gl_Color;
        blockId       = int((mc_Entity.x - 1000.0) + 0.25);

        worldPosition = transform(shadowModelViewInverse, (gl_ModelViewMatrix * gl_Vertex).xyz);

        #if ANIMATIONS_ENABLED

            animate(worldPosition, textureCoords.y < mc_midTexCoord.y, getSkylightFalloff(gl_MultiTexCoord1.y * rcp240));
            gl_Position = project(gl_ProjectionMatrix, transform(shadowModelView, worldPosition));

        #else

            gl_Position = ftransform();
            
        #endif

        worldPosition  += cameraPosition;
        gl_Position.xyz = distortShadowSpace(gl_Position.xyz);
    }
    
#elif defined STAGE_FRAGMENT

    /* RENDERTARGETS: 0,1 */

    layout (location = 0) out vec4 shadowmap;
    layout (location = 1) out float caustics;

    flat in int blockId;
    in vec2 textureCoords;
    in vec3 worldPosition;
    in vec4 vertexColor;

    uniform sampler2D gtexture;

    #if WATER_CAUSTICS == 1

        #include "/include/fragment/water.glsl"

        // https://medium.com/@evanwallace/rendering-realtime-caustics-in-webgl-2a99a29a0b2c
        float waterCaustics(vec3 oldPosition, vec3 normal) {
            vec3 newPosition = oldPosition + refract(shadowLightVectorWorld, normal, airIOR / 1.333);

            float oldArea = length(dFdx(oldPosition)) * length(dFdy(oldPosition));
            float newArea = length(dFdx(newPosition)) * length(dFdy(newPosition));
            
            return max0(fastInvSqrtN1(oldArea / newArea) * 0.2);
        }

    #endif

    void main() {
        vec4 albedoTexture = texture(gtexture, textureCoords);
        albedoTexture.rgb *= vertexColor.rgb;

        if (albedoTexture.a < alphaTestThreshold) { discard; return; }

        #if WHITE_WORLD == 1
            albedoTexture.rgb = vec3(1.0);
        #endif

        shadowmap = albedoTexture;

        caustics = 0.0;

        if (blockId == WATER_ID) {

            shadowmap = vec4(1.0, 1.0, 1.0, 0.0);

            #if WATER_CAUSTICS == 1

                caustics = waterCaustics(
                    worldPosition,
                    getWaterNormal(worldPosition, vec3(0.0, 1.0, 0.0), WATER_OCTAVES, 2.0 * WATER_NORMALS_STRENGTH_MULTIPLIER)
                ) * WATER_CAUSTICS_STRENGTH;

            #endif
            
        }
    }
    
#endif
