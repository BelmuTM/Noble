/*
    Noble SSRT - 2021
    Made by Belmu
    https://github.com/BelmuTM/
*/

vec3 specularFresnelSchlick(vec3 specColor, float NdotL) {
    return specColor + (1.0 - specColor) * pow((1.0 - NdotL), 5.0);
}

vec3 phongBRDF(vec3 lightDir, vec3 rayDir, vec3 Normal, vec3 specColor, float specShininess) {
    vec3 reflectDir = reflect(-lightDir, Normal);
    float specAngle = max(dot(reflectDir, rayDir), 0.0);
    return pow(specAngle, specShininess) * specColor;
}

vec3 blinnPhongBRDF(vec3 lightDir, vec3 rayDir, vec3 Normal, vec3 specColor, float specShininess) {
    vec3 halfDir = normalize(lightDir + rayDir);
    float specAngle = max(dot(halfDir, Normal), 0.0);
    return pow(specAngle, specShininess) * specColor;
}
