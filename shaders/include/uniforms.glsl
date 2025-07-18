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

uniform vec3 shadowVec;
uniform vec3 sunVector;
uniform vec3 moonVector;
uniform vec3 shadowLightVector;
uniform vec3 cameraPosition;

uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform vec2 viewSize;
uniform vec2 texelSize;
uniform ivec2 atlasSize;

uniform int isEyeInWater;
uniform int hideGUI;
uniform int worldTime;
uniform int framemod;
uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform float centerDepthSmooth;
uniform float rainStrength;
uniform float wetness;
uniform float sunAngle;
uniform int renderStage;

#if defined IS_IRIS
    uniform int biome_category;
    uniform int biome_precipitation;

    uniform float biome_arid;
    uniform float biome_may_rain;
    uniform float biome_may_sandstorm;
#endif

uniform sampler2D noisetex;

uniform sampler2D colortex0;
uniform usampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex10;
uniform sampler2D colortex12;
uniform sampler2D colortex14;
uniform sampler2D colortex15;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform float near;
uniform float far;

uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;

uniform float dhNearPlane;
uniform float dhFarPlane;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

uniform mat4 dhProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhPreviousProjection;

uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousModelViewInverse;
uniform mat4 gbufferPreviousProjection;

const int noiseTextureResolution = 256;

const float labPBRMetals = 229.5;

// Maximum values for x amount of bits and their inverses (2^x - 1)
const float maxFloat8     = 255.0;
const float maxFloat16    = 65535.0;
const float rcpMaxFloat8  = 1.0 / maxFloat8;
const float rcpMaxFloat12 = 1.0 / (pow(2.0, 12.0) - 1.0);
const float rcpMaxFloat13 = 1.0 / (pow(2.0, 13.0) - 1.0);
const float rcpMaxFloat16 = 1.0 / maxFloat16;

const float handDepth = MC_HAND_DEPTH * 0.5 + 0.5;
