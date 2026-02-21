// moves_to.glsl
#version 430 core

uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform usampler2D ageTexture;
uniform vec2 worldSize;

layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;
layout(location = 2) out uint outAge;

const ivec2 DIRECTIONS[4] = ivec2[4](
    ivec2(0, 1),   // North
    ivec2(1, 0),   // East
    ivec2(0, -1),  // South
    ivec2(-1, 0)   // West
    );

void main()
{
    ivec2 pos = ivec2(gl_FragCoord.xy);

    uint speciesID = texelFetch(speciesTexture, pos, 0).r;
    uvec4 worldState = texelFetch(worldStateTexture, pos, 0);

    // Если клетка занята - ничего не делать
    if (speciesID != 0u)
    {
        uint age = texelFetch(ageTexture, pos, 0).r;
        outSpecies = speciesID;
        outWorldState = worldState;
        outAge = age;
        return;
    }

    uint directedActions = worldState.a & 0xFFFFu;

    // Проверяем, хочет ли кто-то переместиться в эту клетку
    bool hasMover = (directedActions & (0x1u << 4)) != 0u;

    if (!hasMover)
    {
        outSpecies = 0u;
        outWorldState = worldState;
        outAge = 0u;
        return;
    }

    // Получаем направление, откуда идет перемещение
    uint moveFrom = (directedActions >> 5) & 0x3u;
    ivec2 moverPos = pos + DIRECTIONS[moveFrom];

    moverPos.x = (moverPos.x + int(worldSize.x)) % int(worldSize.x);
    moverPos.y = clamp(moverPos.y, 0, int(worldSize.y) - 1);

    // Проверяем, есть ли там еще существо (могло быть съедено)
    uint moverSpecies = texelFetch(speciesTexture, moverPos, 0).r;

    if (moverSpecies == 0u)
    {
        outSpecies = 0u;
        outWorldState = worldState;
        outAge = 0u;
        return;
    }

    // Копируем данные существа
    uvec4 moverState = texelFetch(worldStateTexture, moverPos, 0);

    uint moverDnaPosition = moverState.r & 0xFFu;
    uint moverDirection = (moverState.r >> 8) & 0xFFu;
    uint moverEnergy = moverState.g & 0xFFu;
    uint moverParameters = (moverState.g >> 8) & 0xFFu;

    // Получаем возраст от перемещающегося существа
    uint moverAge = texelFetch(ageTexture, moverPos, 0).r;

    // Сохраняем минералы текущей клетки
    uint minerals = (worldState.b >> 8) & 0xFFu;

    outWorldState.r = moverDnaPosition | (moverDirection << 8);
    outWorldState.g = moverEnergy | (moverParameters << 8);
    outWorldState.b = 0u | (minerals << 8); // lastAction сбрасываем
    outWorldState.a = directedActions;

    outSpecies = moverSpecies;
    outAge = moverAge;
}
