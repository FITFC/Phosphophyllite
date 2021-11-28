#version 330 core
// gpuinfo says this is supported, so im using it
#extension GL_ARB_separate_shader_objects : enable

#ifndef POSITION_LOCATION
#define POSITION_LOCATION 0
#define COLOR_LOCATION 2
#define TEX_COORD_LOCATION 2
#define LIGHTINFO_LOCATION 3
#endif

layout(location = POSITION_LOCATION) in vec3 position;
layout(location = COLOR_LOCATION) in int colorIn;
layout(location = TEX_COORD_LOCATION) in vec2 texCoordIn;
layout(location = LIGHTINFO_LOCATION) in uvec2 lightingInfo;

uniform ivec3 playerBlock;
uniform vec3 playerSubBlock;
uniform mat4 projectionMatrix;

uniform bool TEXTURE;
uniform bool LIGHTING;
uniform bool QUAD;

uniform int worldPositionIDOffset;
uniform isamplerBuffer worldPositions;

uniform int dynamicMatrixIDOffset;
uniform isamplerBuffer dynamicMatrixIDs;
uniform samplerBuffer dynamicMatrices;

uniform int staticMatrixBaseID;
uniform samplerBuffer staticMatrices;

uniform int lightIDOffset;
uniform isamplerBuffer lightIDs;
uniform usamplerBuffer lights;


layout(location = 0) out float vertexDistance;
layout(location = 1) out vec4 vertexColor;

layout(location = 2) out vec2 texCoordOut;

layout(location = 3) flat out vec3 vertexNormal;
#define LIGHTMAP_MULTIPLIER 0.015625 /* 1 / 64 (6 bit) */
layout(location = 4) out vec2 vertexLightmapCoord;
layout(location = 5) out vec2 lightmapCoords[4];// locations 5 6 7 8

layout(location = 9) out float diffuseMultiplier;
layout(location = 10) out vec3 vertexModelPos;
layout(location = 11) flat out vec3[8] cornerLightLevels;// locations 11-18


const vec3 lightDirections[6] = vec3[6](vec3(1, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1), vec3(-1, 0, 0), vec3(0, -1, 0), vec3(0, 0, -1));
//const vec3 lightPositions[8] = vec3[8](vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0), vec3(1, 1, 0), vec3(0, 0, 1), vec3(1, 0, 1), vec3(0, 1, 1), vec3(1, 1, 1));

float calcuateDiffuseMultiplier(vec3 normal);

int extractInt(uint packedint, uint pos, uint width);

uint extractUInt(uint packedint, uint pos, uint width);

void main() {
    int staticMatrixID = staticMatrixBaseID + gl_InstanceID;
    int dynamicMatrixID = texelFetch(dynamicMatrixIDs, dynamicMatrixIDOffset + gl_InstanceID).x;

    mat4 staticModelMatrix = mat4(0);
    staticModelMatrix[0] = texelFetch(staticMatrices, staticMatrixID * 8 + 0);
    staticModelMatrix[1] = texelFetch(staticMatrices, staticMatrixID * 8 + 1);
    staticModelMatrix[2] = texelFetch(staticMatrices, staticMatrixID * 8 + 2);
    staticModelMatrix[3] = texelFetch(staticMatrices, staticMatrixID * 8 + 3);

    mat4 dynamicModelMatrix = mat4(0);
    dynamicModelMatrix[0] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 0);
    dynamicModelMatrix[1] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 1);
    dynamicModelMatrix[2] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 2);
    dynamicModelMatrix[3] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 3);

    ivec3 worldPosition = texelFetch(worldPositions, worldPositionIDOffset + gl_InstanceID).xyz;
    worldPosition -= playerBlock;
    vec3 floatWorldPosition = worldPosition;
    floatWorldPosition -= playerSubBlock;

    mat4 modelMatrix = dynamicModelMatrix * staticModelMatrix;

    vec4 vertexPosition = modelMatrix * vec4(position, 1.0);
    vertexModelPos = vertexPosition.xyz;
    vertexPosition += vec4(floatWorldPosition, 0);
    vertexDistance = length(vertexPosition.xyz);
    gl_Position = projectionMatrix * vertexPosition;

    int r = (colorIn >> 24) & 0xFF;
    int g = (colorIn >> 16) & 0xFF;
    int b = (colorIn >> 8) & 0xFF;
    int a = (colorIn >> 0) & 0xFF;

    vertexColor = vec4(r, g, b, a) / 255;

    if (TEXTURE) {
        texCoordOut = texCoordIn;
    }

    if (LIGHTING){
        if (!QUAD) {
            vertexNormal = normalize(vec3(extractInt(lightingInfo.x, 0u, 16u), extractInt(lightingInfo.y, 16u, 16u), extractInt(lightingInfo.y, 0u, 16u)));
            vertexLightmapCoord = vec2((lightingInfo.x >> 24) & 0xFFu, (lightingInfo.x >> 16) & 0xFFu) * LIGHTMAP_MULTIPLIER;
        } else {
            vertexNormal = normalize(vec3(extractInt(lightingInfo.x, 24u, 4u), extractInt(lightingInfo.x, 28u, 4u), extractInt(lightingInfo.y, 24u, 4u)));
            vertexLightmapCoord = vec2((lightingInfo.y >> 28) & 0x1u, (lightingInfo.y >> 29) & 0x1u);
            lightmapCoords[0] = vec2((lightingInfo.x >> 00) & 0x3Fu, (lightingInfo.x >> 06) & 0x3Fu) * LIGHTMAP_MULTIPLIER;
            lightmapCoords[1] = vec2((lightingInfo.x >> 12) & 0x3Fu, (lightingInfo.x >> 18) & 0x3Fu) * LIGHTMAP_MULTIPLIER;
            lightmapCoords[2] = vec2((lightingInfo.y >> 00) & 0x3Fu, (lightingInfo.y >> 06) & 0x3Fu) * LIGHTMAP_MULTIPLIER;
            lightmapCoords[3] = vec2((lightingInfo.y >> 12) & 0x3Fu, (lightingInfo.y >> 18) & 0x3Fu) * LIGHTMAP_MULTIPLIER;
        }

        mat3 staticNormalMatrix = mat3(0);
        staticNormalMatrix[0] = texelFetch(staticMatrices, staticMatrixID * 8 + 4).xyz;
        staticNormalMatrix[1] = texelFetch(staticMatrices, staticMatrixID * 8 + 5).xyz;
        staticNormalMatrix[2] = texelFetch(staticMatrices, staticMatrixID * 8 + 6).xyz;
        mat3 dynamicNormalMatrix = mat3(0);
        dynamicNormalMatrix[0] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 4).xyz;
        dynamicNormalMatrix[1] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 5).xyz;
        dynamicNormalMatrix[2] = texelFetch(dynamicMatrices, dynamicMatrixID * 8 + 6).xyz;
        mat3 normalMatrix = dynamicNormalMatrix * staticNormalMatrix;

        vertexNormal = normalize(normalMatrix * vertexNormal);
        diffuseMultiplier = calcuateDiffuseMultiplier(vertexNormal);

        int lightID = texelFetch(lightIDs, lightIDOffset + gl_InstanceID).x;
        //            vec3 clampedPosition = clamp(position, vec3(0), vec3(1)); // maybe clamp it? its extrapolating right now instead
        for (int i = 0; i < 8; i++) {
            cornerLightLevels[i] = vec3(0);
            for (int j = 0; j < 6; j++){
                vec3 lightDirection = lightDirections[j];
                float multiplier = dot(lightDirection, vertexNormal);
                multiplier *= float(multiplier > 0);
                multiplier *= multiplier;

                uvec2 udirectionLight = texelFetch(lights, lightID * 64 + i * 6 + j).rg;
                vec2 directionLight = udirectionLight & 0x3Fu;
                float AO = udirectionLight.x >> 6 & 0x3u;
                cornerLightLevels[i] += vec3(directionLight * LIGHTMAP_MULTIPLIER, AO) * multiplier;
            }
        }
    }
}

float calcuateDiffuseMultiplier(vec3 normal) {
    vec3 n2 = normal * normal * vec3(.6, .25, .8);
    return min(n2.x + n2.y * (3. + normal.y) + n2.z, 1.);
}

int extractInt(uint packedint, uint pos, uint width) {
    packedint >>= pos;
    uint signBitMask = 1u << (width - 1u);
    uint bitMask = signBitMask - 1u;
    int val = int(~bitMask *  uint((signBitMask & packedint) != 0u));
    val |= int(packedint & bitMask);
    return val;
}

uint extractUInt(uint packedint, uint pos, uint width) {
    packedint >>= pos;
    uint signBitMask = 1u << (width - 1u);
    uint bitMask = signBitMask - 1u;
    return packedint & bitMask;
}