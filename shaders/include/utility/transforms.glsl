/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

//////////////////////////////////////////////////////////
/*--------------- MATRICES OPERATIONS ------------------*/
//////////////////////////////////////////////////////////

vec2 diag2(mat4 mat) { return vec2(mat[0].x, mat[1].y); 		   }
vec3 diag3(mat4 mat) { return vec3(mat[0].x, mat[1].y, mat[2].z);  }
vec4 diag4(mat4 mat) { return vec4(mat[0].x, mat[1].y, mat[2].zw); }

vec2 projOrthoMAD(mat4 mat, vec2 v) { return diag2(mat) * v + mat[3].xy;  }
vec3 projOrthoMAD(mat4 mat, vec3 v) { return diag3(mat) * v + mat[3].xyz; }
vec3 transMAD(mat4 mat, vec3 v)     { return mat3(mat)  * v + mat[3].xyz; }

//////////////////////////////////////////////////////////
/*------------------ ACCUMULATION ----------------------*/
//////////////////////////////////////////////////////////

vec3 reprojection(vec3 screenPos) {
    screenPos = screenPos * 2.0 - 1.0;

    vec4 position = gbufferProjectionInverse * vec4(screenPos, 1.0);
         position = gbufferModelViewInverse * (position / position.w);

    vec3 cameraOffset = (cameraPosition - previousCameraPosition) * float(screenPos.z >= MC_HAND_DEPTH);
    
    position += vec4(cameraOffset, 0.0);
    position  = gbufferPreviousModelView  * position;
    position  = gbufferPreviousProjection * position;

    return (position.xyz / position.w) * 0.5 + 0.5;
}

bool hasMoved() {
    return gbufferModelView != gbufferPreviousModelView
		|| cameraPosition   != previousCameraPosition;
}

//////////////////////////////////////////////////////////
/*--------------------- SHADOWS ------------------------*/
//////////////////////////////////////////////////////////

float getDistortionFactor(vec2 coords) {
	return cubeLength(coords) * SHADOW_DISTORTION + (1.0 - SHADOW_DISTORTION);
}

vec2 distortShadowSpace(vec2 position) {
	return position / getDistortionFactor(position.xy);
}

vec3 distortShadowSpace(vec3 position) {
	position.xy = distortShadowSpace(position.xy);
	position.z *= SHADOW_DEPTH_STRETCH;
	return position;
}

//////////////////////////////////////////////////////////
/*--------------- SPACE CONVERSIONS --------------------*/
//////////////////////////////////////////////////////////

vec3 screenToView(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	return projOrthoMAD(gbufferProjectionInverse, screenPos) / (gbufferProjectionInverse[2].w * screenPos.z + gbufferProjectionInverse[3].w);
}

vec3 viewToScreen(vec3 viewPos) {
	return (projOrthoMAD(gbufferProjection, viewPos) / -viewPos.z) * 0.5 + 0.5;
}

vec3 viewToScene(vec3 viewPos) {
	return transMAD(gbufferModelViewInverse, viewPos);
}

vec3 worldToView(vec3 worldPos) {
	return mat3(gbufferModelView) * (worldPos - cameraPosition);
}

vec3 viewToWorld(vec3 viewPos) {
	return viewToScene(viewPos) + cameraPosition;
}

mat3 constructViewTBN(vec3 viewNormal) {
	vec3 tangent = normalize(cross(gbufferModelViewInverse[1].xyz, viewNormal));
	return mat3(tangent, cross(tangent, viewNormal), viewNormal);
}

vec3 getViewPos0(vec2 coords) {
    return screenToView(vec3(coords, texture(depthtex0, coords).r));
}

vec3 getViewPos1(vec2 coords) {
    return screenToView(vec3(coords, texture(depthtex1, coords).r));
}

// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
float linearizeDepth(float depth) {
    depth = depth * 2.0 - 1.0;
    return 2.0 * far * near / (far + near - depth * (far - near));
}

float linearizeDepthFast(float depth) {
	return (near * far) / (depth * (near - far) + far);
}

//////////////////////////////////////////////////////////
/*---------------- MATERIAL CONVERSIONS ----------------*/
//////////////////////////////////////////////////////////

float F0ToIOR(float F0) {
	F0 = sqrt(F0) * 0.99999;
	return (1.0 + F0) / (1.0 - F0);
}

vec3 F0ToIOR(vec3 F0) {
	F0 = sqrt(F0) * 0.99999;
	return (1.0 + F0) / (1.0 - F0);
}

float IORToF0(float ior) {
	float a = (ior - airIOR) / (ior + airIOR);
	return a * a;
}
