/***********************************************/
/*       Copyright (C) Noble RT - 2021         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 diag3(mat4 mat) {
	return vec3(mat[0].x, mat[1].y, mat[2].z);
}

vec2 diag2(mat4 mat) {
	return vec2(mat[0].x, mat[1].y);
}

vec3 projMAD3(mat4 mat, vec3 v) {
	return diag3(mat) * v + mat[3].xyz;
}

vec2 projMAD2(mat4 mat, vec2 v) {
	return diag2(mat) * v + mat[3].xy;
}

vec3 transMAD3(mat4 mat, vec3 v) {
	return mat3(mat) * v + mat[3].xyz;
}

vec3 viewToClip(vec3 viewPos) {
	return diag3(gbufferProjection) * viewPos + gbufferProjection[3].xyz;
}

vec3 screenToView(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	vec3 viewPos = vec3(projMAD2(gbufferProjectionInverse, screenPos.xy), gbufferProjectionInverse[3].z);
	return viewPos / (gbufferProjectionInverse[2].w * screenPos.z + gbufferProjectionInverse[3].w);
}

vec3 viewToScreen(vec3 viewPos) {
	return (projMAD3(gbufferProjection, viewPos) / -viewPos.z) * 0.5 + 0.5;
}

vec3 worldToView(vec3 worldPos) {
	return mat3(gbufferModelView) * worldPos;
}

vec3 viewToWorld(vec3 viewPos) {
	return mat3(gbufferModelViewInverse) * viewPos;
}

vec3 tangentToWorld(vec3 normal, vec3 H) {
    vec3 tangent = normalize(cross(gbufferModelView[1].xyz, normal));
    return vec3((tangent * H.x) + (cross(normal, tangent) * H.y) + (normal * H.z));
}

// https://wiki.shaderlabs.org/wiki/Shader_tricks#Linearizing_depth
float linearizeDepth(float depth) {
	return (near * far) / (depth * (near - far) + far);
}

float F0toIOR(float F0) {
	return (1.0 + sqrt(F0)) / (1.0 - sqrt(F0));
}

float IORtoF0(float ior) {
	float a = (ior - 1.0) / (ior + 1.0);
	return a * a;
}
