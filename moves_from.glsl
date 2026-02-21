// moves_from.glsl
#version 430 core

uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform usampler2D ageTexture;
uniform vec2 worldSize;

layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;
layout(location = 2) out uint outAge;

const uint OP_MOVE = 0x3u;

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

    // Если пустая клетка - ничего не делать
    if (speciesID == 0u)
    {
        outSpecies = 0u;
        outWorldState = worldState;
        outAge = 0u;
        return;
    }

    uint direction = (worldState.r >> 8) & 0xFFu;
    uint lastAction = worldState.b & 0xFFu;
    uint opcode = lastAction & 0xFu;

    // Если последнее действие не move - ничего не делать
    if (opcode != OP_MOVE)
    {
        uint age = texelFetch(ageTexture, pos, 0).r;
        outSpecies = speciesID;
        outWorldState = worldState;
        outAge = age;
        return;
    }

    // Проверяем клетку впереди
    ivec2 forwardPos = pos + DIRECTIONS[direction];
    forwardPos.x = (forwardPos.x + int(worldSize.x)) % int(worldSize.x);

    // Проверяем, не пол/потолок ли впереди
    if (forwardPos.y == -1 || forwardPos.y == int(worldSize.y))
    {
        uint age = texelFetch(ageTexture, pos, 0).r;
        outSpecies = speciesID;
        outWorldState = worldState;
        outAge = age;
        return;
    }

    // Проверяем, помечены ли мы как перемещающийся в ту клетку
    uvec4 forwardState = texelFetch(worldStateTexture, forwardPos, 0);
    uint forwardDirectedActions = forwardState.a & 0xFFFFu;

    bool isMarkedAsMover = (forwardDirectedActions & (0x1u << 4)) != 0u;

    if (!isMarkedAsMover)
    {
        uint age = texelFetch(ageTexture, pos, 0).r;
        outSpecies = speciesID;
        outWorldState = worldState;
        outAge = age;
        return;
    }

    // Проверяем, что направление в флаге указывает именно на нас (защита от гонки)
    uint moveDirectionFrom = (forwardDirectedActions >> 5) & 0x3u;
    ivec2 expectedSourcePos = forwardPos + DIRECTIONS[moveDirectionFrom];
    expectedSourcePos.x = (expectedSourcePos.x + int(worldSize.x)) % int(worldSize.x);
    
    if (expectedSourcePos != pos)
    {
        // Флаг установлен другим существом, мы проиграли гонку за эту клетку
        uint age = texelFetch(ageTexture, pos, 0).r;
        outSpecies = speciesID;
        outWorldState = worldState;
        outAge = age;
        return;
    }

    // Удаляем существо из этой клетки
    uint minerals = (worldState.b >> 8) & 0xFFu;

    outWorldState.r = 0u;
    outWorldState.g = 0u;
    outWorldState.b = 0u | (minerals << 8); // Сохраняем минералы
    outWorldState.a = 0u;

    outSpecies = 0u;
    outAge = 0u; // Сбрасываем возраст при уходе
}
