// diffusion.glsl
#version 430 core

uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform vec2 worldSize;
uniform uint stepNumber;

layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;

void main()
{
    ivec2 pos = ivec2(gl_FragCoord.xy);

    uint speciesID = texelFetch(speciesTexture, pos, 0).r;
    uvec4 worldState = texelFetch(worldStateTexture, pos, 0);

    uint lastAction = worldState.b & 0xFFu;
    uint minerals;
    // Если это дно (y=0) - устанавливаем максимум минералов
    if (pos.y == 0)
    {
        minerals = 255u;
    }
    else
    {
        // Берем минералы из клетки снизу (y-1)
        ivec2 belowPos = ivec2(pos.x, pos.y - 1);
        ivec2 belowLeftPos = ivec2(pos.x - 1, pos.y - 1);
        ivec2 belowRightPos = ivec2(pos.x + 1, pos.y - 1);

        // Wrap по X
        belowPos.x = (belowPos.x + int(worldSize.x)) % int(worldSize.x);
        belowLeftPos.x = (belowLeftPos.x + int(worldSize.x)) % int(worldSize.x);
        belowRightPos.x = (belowRightPos.x + int(worldSize.x)) % int(worldSize.x);

        uvec4 belowState = texelFetch(worldStateTexture, belowPos, 0);
        uvec4 belowLeftState = texelFetch(worldStateTexture, belowLeftPos, 0);
        uvec4 belowRightState = texelFetch(worldStateTexture, belowRightPos, 0);

        float belowMinerals = (belowState.b >> 8) & 0xFFu;
        float belowLeftMinerals = (belowLeftState.b >> 8) & 0xFFu;
        float belowRightMinerals = (belowRightState.b >> 8) & 0xFFu;

        minerals = int(belowMinerals * 0.6 + belowLeftMinerals * 0.2 + belowRightMinerals * 0.2 + 0.499);
    }

    outWorldState.r = worldState.r;
    outWorldState.g = worldState.g;
    outWorldState.b = lastAction | (minerals << 8);
    outWorldState.a = worldState.a;

    outSpecies = speciesID;
}