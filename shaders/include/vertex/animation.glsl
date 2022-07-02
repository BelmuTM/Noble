/***********************************************/
/*        Copyright (C) NobleRT - 2022         */
/*   Belmu | GNU General Public License V3.0   */
/*                                             */
/* By downloading this content you have agreed */
/*     to the license and its terms of use.    */
/***********************************************/

const float windSpeed = 1.5;
float wavingSpeed     = frameTimeCounter * windSpeed;
vec3 windDir          = wavingSpeed * vec3(0.8, 0.4, -1);

void wavingLeaves(inout vec3 worldPos) {
    worldPos += (sin(worldPos * vec3(1.0, 1.4, 1.05) + windDir * vec3(2.0, 3.2, 2.3)) * vec3(0.1, 0.06, 0.2)) * 0.3;
}

void animate(inout vec3 worldPos) {
	switch(blockId) {
		case 8: wavingLeaves(worldPos); break;
	}
}
