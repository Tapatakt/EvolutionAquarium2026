// attacks.glsl
#version 430 core

uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform usampler2D ageTexture;
uniform vec2 worldSize;

layout(std430, binding = 4) coherent buffer DeathCounterBuffer {
    uint speciesDied[];
};

layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;
layout(location = 2) out uint outAge;

const uint OP_ATTACK = 0x4u;
const uint BASE_EATING_ENERGY = 64u;
const uint EATING_ENERGY_DENOMINATOR = 2u;

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

    uint dnaPosition = worldState.r & 0xFFu;
    uint direction = (worldState.r >> 8) & 0xFFu;
    uint energy = worldState.g & 0xFFu;
    uint parameters = (worldState.g >> 8) & 0xFFu;
    uint lastAction = worldState.b & 0xFFu;
    uint minerals = (worldState.b >> 8) & 0xFFu;
    uint directedActions = worldState.a & 0xFFFFu;

    uint opcode = lastAction & 0xFu;

    // Чтение возраста
    uint age = texelFetch(ageTexture, pos, 0).r;

    // Если мы атакуем, проверяем успешность
    if (opcode == OP_ATTACK)
    {
        ivec2 forwardPos = pos + DIRECTIONS[direction];
        forwardPos.x = (forwardPos.x + int(worldSize.x)) % int(worldSize.x);
        if (forwardPos.y >= 0 && forwardPos.y < int(worldSize.y))
        {
            // Читаем состояние цели
            uvec4 targetState = texelFetch(worldStateTexture, forwardPos, 0);
            uint targetDirectedActions = targetState.a & 0xFFFFu;

            // Проверяем, помечены ли мы как атакующий для этой клетки
            bool isMarkedAsAttacker = (targetDirectedActions & 0x1u) != 0u;

            if (isMarkedAsAttacker)
            {
                uint targetEnergy = targetState.g & 0xFFu;
                // Получаем энергию от поедания
                energy = min(energy + BASE_EATING_ENERGY + targetEnergy / EATING_ENERGY_DENOMINATOR, 255u);
            }
        }
    }

    // Проверяем, атакуют ли нас
    bool isUnderAttack = (directedActions & 0x1u) != 0u;

    if (isUnderAttack)
    {
        // Убиваем существо
        atomicAdd(speciesDied[speciesID], 1u);
        speciesID = 0u;
        energy = 0u;
        age = 0u; // Сбрасываем возраст при смерти
    }

    outWorldState.r = dnaPosition | (direction << 8);
    outWorldState.g = energy | (parameters << 8);
    outWorldState.b = lastAction | (minerals << 8);
    outWorldState.a = directedActions;

    outSpecies = speciesID;
    outAge = age;
}
