/***********************************************/
/*          Copyright (C) 2023 Belmu           */
/*       GNU General Public License V3.0       */
/***********************************************/

vec3 windDir = frameTimeCounter * vec3(-0.2, 0.35, -1.0);

void wavingLeaves(inout vec3 worldPos) {
    worldPos += (sin(worldPos * vec3(1.0, 1.4, 1.05) + windDir * vec3(2.0, 3.2, 2.3)) * vec3(0.1, 0.06, 0.2)) * 0.15;
}

void wavingPlants(inout vec3 worldPos, bool isTopVertex, bool isTopBlock) {
	vec2 offset  = (sin(worldPos.xz * vec2(1.62, 1.82) + windDir.xz * vec2(2.0)) * vec2(0.1, 0.2)) * 0.35;
		 offset *= (isTopBlock ? 1.5 : float(isTopVertex));

	worldPos.xz += offset;
}

void animate(inout vec3 worldPos, bool isTopVertex) {
	worldPos += cameraPosition;
	
	switch(blockId) {
		case 9:  wavingLeaves(worldPos); 					 break;
		case 10: wavingPlants(worldPos, isTopVertex, false); break;
		case 11: wavingPlants(worldPos, isTopVertex, true);  break;
		case 12: wavingPlants(worldPos, isTopVertex, false); break;
	}
	worldPos -= cameraPosition;
}
