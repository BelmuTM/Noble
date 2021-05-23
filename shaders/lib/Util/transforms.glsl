/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

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

/*
vec3 extractNormalMap(vec4 normal, mat3 TBN) {
	vec3 normalMap = normal.xyz * 2.0 - 1.0;
	normalMap.z = sqrt(clamp(1.0 - dot(normalMap.xy, normalMap.xy), 0.0, 1.0));
	normalMap = TBN * normalMap;
	normalMap = mat3(gbufferModelViewInverse) * normalMap;
	return normalMap;
}
*/
