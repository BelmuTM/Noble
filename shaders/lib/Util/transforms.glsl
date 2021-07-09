/***********************************************/
/*       Copyright (C) Noble SSRT - 2021       */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

vec3 diag3(mat4 mat) {
	return vec3(mat[0].x, mat[1].y, mat[2].z);
}

vec3 projMAD(mat4 mat, vec3 v) {
	return (diag3(mat) * v + mat[3].xyz);
}

vec3 viewToClip(vec3 viewPos) {
	return diag3(gbufferProjection) * viewPos + gbufferProjection[3].xyz;
}

vec3 screenToView(vec3 screenPos) {
	screenPos = screenPos * 2.0 - 1.0;
	return projMAD(gbufferProjectionInverse, screenPos) / (screenPos.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 viewToScreen(vec3 viewPos) {
	return (diag3(gbufferProjection) * viewPos + gbufferProjection[3].xyz) / -viewPos.z * 0.5 + 0.5;
}

vec3 worldToView(vec3 worldPos) {
	return mat3(gbufferModelView) * (worldPos - cameraPosition);
}

vec3 viewToWorld(vec3 viewPos) {
	return mat3(gbufferModelViewInverse) * viewPos;
}

// Written by n_r4h33m#7259
vec3 tangentToWorld(vec3 N, vec3 H) {
    vec3 upVector = abs(N.z) < 0.999 ? vec3(vec2(0.0), 1.0) : vec3(1.0, vec2(0.0));
    vec3 T = normalize(cross(upVector, N));
    vec3 B = cross(N, T);
    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}

float linearizeDepth(float depth) {
	return (2.0f * near * far) / (far + near - (depth * 2.0 - 1.0) * (far - near));
}

float F0toIOR(float F0) {
	F0 *= 0.99999999;
	return -(F0 + 1.0 + 2.0 * sqrt(F0)) / (F0 - 1.0);
}

float IORtoF0(float ior) {
	float a = (ior - 1.0) / (ior + 1.0);
	return a * a;
}
