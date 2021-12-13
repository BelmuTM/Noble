/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 upPosition;
uniform vec3 skyColor;

uniform vec2 viewResolution;
uniform vec2 pixelSize;

uniform float rainStrength;
uniform int framemod;
uniform int frameCounter;
uniform float frameTime;
uniform float frameTimeCounter;
uniform float centerDepthSmooth;
uniform float near;
uniform float far;
uniform float aspectRatio;
uniform float viewWidth;
uniform float viewHeight;
uniform int worldTime;
uniform int isEyeInWater;

uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D noisetex;

uniform sampler2D shadowtex0;
uniform sampler2D shadowtex1;
uniform sampler2D shadowcolor0;
uniform sampler2D shadowcolor1;

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 previousCameraPosition;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;

const int noiseRes    = 128;
const int causticsRes = (256 - 1);
const float airIOR    = 1.00029;

const float bits16 = 65535.0;
<<<<<<< HEAD
=======
const float bits32 = 16777215.0;
>>>>>>> 70cbfafac088457970cf9ef9c064a4a3c48f10c8

vec3 shadowDir     = normalize(shadowLightPosition);
vec3 playerSunDir  = normalize(mat3(gbufferModelViewInverse) * sunPosition);
vec3 playerMoonDir = normalize(mat3(gbufferModelViewInverse) * moonPosition);
