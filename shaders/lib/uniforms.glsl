/***********************************************/
/*       Copyright (C) Noble RT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 cameraPosition;
uniform vec3 skyColor;

uniform float rainStrength;
uniform float frameTimeCounter;
uniform float aspectRatio;
uniform float centerDepthSmooth;
uniform float near;
uniform float far;
uniform float viewWidth;
uniform float viewHeight;
uniform int worldTime;
uniform int isEyeInWater;
uniform int fogMode;

uniform sampler2D texture;
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

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D noisetex;

uniform sampler2D shadowtex0, shadowtex1;
uniform sampler2D shadowcolor0;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowModelView, shadowProjection;

vec2 viewSize = vec2(viewWidth, viewHeight);
vec2 pixelSize = 1.0 / viewSize;
