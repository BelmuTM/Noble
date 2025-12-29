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

// Perspective uniforms for chunk loader mods support (Distant Horizons, Voxy)

#if defined DISTANT_HORIZONS

    uniform float dhNearPlane;
    uniform float dhFarPlane;

    uniform sampler2D dhDepthTex0;
    uniform sampler2D dhDepthTex1;

    uniform mat4 dhProjection;
    uniform mat4 dhProjectionInverse;
    uniform mat4 dhProjectionPrevious;

    #define modNearPlane dhNearPlane
    #define modFarPlane  dhFarPlane

    #define modDepthTex0 dhDepthTex0
    #define modDepthTex1 dhDepthTex1

    #define modProjection         dhProjection
    #define modProjectionInverse  dhProjectionInverse
    #define modProjectionPrevious gbufferPreviousProjection

#elif defined VOXY

    uniform sampler2D vxDepthTexOpaque;
    uniform sampler2D vxDepthTexTrans;

    uniform mat4 vxProj;
    uniform mat4 vxProjInv;
    uniform mat4 vxProjPrev;

    #define modNearPlane near
    #define modFarPlane  far

    #define modDepthTex0 vxDepthTexTrans
    #define modDepthTex1 vxDepthTexOpaque

    #define modProjection         vxProj
    #define modProjectionInverse  vxProjInv
    #define modProjectionPrevious vxProjPrev

#else

    #define modNearPlane near
    #define modFarPlane  far

    #define modDepthTex0 depthtex0
    #define modDepthTex1 depthtex1

    #define modProjection         gbufferProjection
    #define modProjectionInverse  gbufferProjectionInverse
    #define modProjectionPrevious gbufferPreviousProjection

#endif
