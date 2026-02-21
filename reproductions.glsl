// reproduction.glsl
#version 430 core

uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform usampler2D ageTexture;
uniform vec2 worldSize;

layout(std430, binding = 3) coherent buffer BirthCounterBuffer {
    uint speciesBorn[];
};

layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;
layout(location = 2) out uint outAge;

const uint OP_REPRODUCE = 0x9u;
const uint REPRODUCTION_COST = 196u;
const uint START_ENERGY = 64u;

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

    uint dnaPosition = worldState.r & 0xFFu;
    uint direction = (worldState.r >> 8) & 0xFFu;
    uint energy = worldState.g & 0xFFu;
    uint parameters = (worldState.g >> 8) & 0xFFu;
    uint lastAction = worldState.b & 0xFFu;
    uint minerals = (worldState.b >> 8) & 0xFFu;
    uint directedActions = worldState.a & 0xFFFFu;

    uint opcode = lastAction & 0xFu;

    // Чтение возраста (для существующего существа)
    uint age = texelFetch(ageTexture, pos, 0).r;

    // Если есть существо и оно размножается
    if (speciesID != 0u && opcode == OP_REPRODUCE)
    {
        ivec2 forwardPos = pos + DIRECTIONS[direction];
        forwardPos.x = (forwardPos.x + int(worldSize.x)) % int(worldSize.x);

        // Проверяем, не пол/потолок ли впереди
        if (forwardPos.y != -1 && forwardPos.y != int(worldSize.y))
        {
            // Проверяем, помечены ли мы как размножающийся
            uvec4 forwardState = texelFetch(worldStateTexture, forwardPos, 0);
            uint forwardDirectedActions = forwardState.a & 0xFFFFu;

            bool isMarkedAsReproducer = (forwardDirectedActions & (0x1u << 8)) != 0u;

            // Проверяем, что впереди пусто
            uint forwardSpecies = texelFetch(speciesTexture, forwardPos, 0).r;

            if (isMarkedAsReproducer && forwardSpecies == 0u)
            {
                // Вычитаем энергию за размножение
                energy = (energy > REPRODUCTION_COST) ? (energy - REPRODUCTION_COST) : 0u;
            }
        }
    }

    // Если клетка пустая и кто-то хочет в нее размножиться
    if (speciesID == 0u)
    {
        bool hasReproducer = (directedActions & (0x1u << 8)) != 0u;

        if (hasReproducer)
        {
            // Получаем направление, откуда размножение
            uint reproducerDirection = (directedActions >> 9) & 0x3u;
            ivec2 reproducerPos = pos + DIRECTIONS[reproducerDirection];

            reproducerPos.x = (reproducerPos.x + int(worldSize.x)) % int(worldSize.x);

            // Проверяем, есть ли там существо
            uint reproducerSpecies = texelFetch(speciesTexture, reproducerPos, 0).r;

            if (reproducerSpecies != 0u)
            {
                uvec4 reproducerState = texelFetch(worldStateTexture, reproducerPos, 0);
                uint reproducerDirection = (reproducerState.r >> 8) & 0xFFu;

                // Создаем потомка
                atomicAdd(speciesBorn[reproducerSpecies], 1u);

                speciesID = reproducerSpecies;
                dnaPosition = 0u; // Начинаем с начала ДНК
                direction = reproducerDirection;
                energy = START_ENERGY;
                parameters = 0u; // Без органов
                lastAction = 0u;
                // minerals остаются как были
                age = 0u; // Потомок только что родился, возраст = 0
            }
        }
    }

    outWorldState.r = dnaPosition | (direction << 8);
    outWorldState.g = energy | (parameters << 8);
    outWorldState.b = lastAction | (minerals << 8);
    outWorldState.a = directedActions;

    outSpecies = speciesID;
    outAge = age;
}
