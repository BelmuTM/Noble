#define diag3(mat) vec3((mat)[0].x, (mat)[1].y, mat[2].z)
#define  projMAD(mat, v) (diag3(mat) * (v) + (mat)[3].xyz)

vec3 screenToView(vec3 screenPos) {
		screenPos = screenPos * 2.0f - 1.0f;
		return projMAD(gbufferProjectionInverse, screenPos) / (screenPos.z * gbufferProjectionInverse[2].w + gbufferProjectionInverse[3].w);
}

vec3 viewToScreen(vec3 viewPos) {
		return (diag3(gbufferProjection) * viewPos + gbufferProjection[3].xyz) / -viewPos.z * 0.5f + 0.5f;
}

vec3 worldToView(vec3 worldPos) {
		return mat3(gbufferModelView) * (worldPos - cameraPosition);
}

float linearizeDepth(float depth) {
		return (2.0f * near * far) / (far + near - depth * (far - near));
}
