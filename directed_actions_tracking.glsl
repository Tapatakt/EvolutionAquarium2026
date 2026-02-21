// directed_actions_tracking.glsl
#version 430 core

// Входные текстуры
uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform usampler2D ageTexture;
uniform vec2 worldSize;

// SSBO
layout(std430, binding = 0) buffer DNABuffer {
    uint dna[];
};

// Выходные данные (три текстуры)
layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;
layout(location = 2) out uint outAge;

// Константы
const uint OP_MOVE = 0x3u;
const uint OP_ATTACK = 0x4u;
const uint OP_REPRODUCE = 0x9u;
const uint REPRODUCE_THRESHOLD = 128u;

// Направления: 0=North, 1=East, 2=South, 3=West
const ivec2 DIRECTIONS[4] = ivec2[4](
    ivec2(0, 1),   // North
    ivec2(1, 0),   // East
    ivec2(0, -1),  // South
    ivec2(-1, 0)   // West
    );

void main()
{
    ivec2 pos = ivec2(gl_FragCoord.xy);

    // Чтение текущего состояния
    uint speciesID = texelFetch(speciesTexture, pos, 0).r;
    uvec4 worldState = texelFetch(worldStateTexture, pos, 0);

    // Чтение возраста (существо не меняется)
    uint age = texelFetch(ageTexture, pos, 0).r;

    // Распаковка состояния
    uint dnaPosition = worldState.r & 0xFFu;
    uint direction = (worldState.r >> 8) & 0xFFu;
    uint energy = worldState.g & 0xFFu;
    uint parameters = (worldState.g >> 8) & 0xFFu;
    uint lastAction = worldState.b & 0xFFu;
    uint minerals = (worldState.b >> 8) & 0xFFu;

    // Обнуляем байты направленных действий (bytes 6-7)
    uint directedActions = 0u;

    // Если есть существо в клетке - ищем атакующего
    if (speciesID != 0u)
    {
        uint armorLevel = (parameters >> 2) & 0x3u; // Биты 2-3
        // Проверяем соседей на атаку
        for (int i = 0; i < 4; i++)
        {
            ivec2 neighborPos = pos + DIRECTIONS[i];

            // wrap по X
            neighborPos.x = (neighborPos.x + int(worldSize.x)) % int(worldSize.x);
            if (neighborPos.y == -1 || neighborPos.y == int(worldSize.y))
                continue;
            uint neighborSpecies = texelFetch(speciesTexture, neighborPos, 0).r;
            if (neighborSpecies == 0u)
                continue;

            uvec4 neighborState = texelFetch(worldStateTexture, neighborPos, 0);
            uint neighborDirection = (neighborState.r >> 8) & 0xFFu;
            uint neighborLastAction = neighborState.b & 0xFFu;
            uint neighborParameters = (neighborState.g >> 8) & 0xFFu;
            uint neighborOpcode = neighborLastAction & 0xFu;

            // Проверяем: атакует ли и смотрит ли на нас
            if (neighborOpcode == OP_ATTACK)
            {
                // Направление от соседа к нам должно совпадать с его направлением взгляда
                ivec2 directionVector = pos - neighborPos;
                
                // Нормализуем с учетом wrap по X
                if (directionVector.x > int(worldSize.x) / 2)
                    directionVector.x -= int(worldSize.x);
                else if (directionVector.x < -int(worldSize.x) / 2)
                    directionVector.x += int(worldSize.x);

                int directionToUs = -1;
                for (int j = 0; j < 4; j++)
                {
                    if (DIRECTIONS[j] == directionVector)
                    {
                        directionToUs = j;
                        break;
                    }
                }

                if (directionToUs != -1 && uint(directionToUs) == neighborDirection)
                {
                    uint neighborTeeth = neighborParameters & 0x3u; // Биты 0-1

                    // Если зубы пробивают броню
                    if (neighborTeeth >= armorLevel)
                    {
                        // Первый блок (биты 0-3): 1 бит флаг + 2 бита направление
                        directedActions |= 0x1u; // Флаг атаки
                        directedActions |= (uint(i) << 1); // Направление (откуда атака)
                        break;
                    }
                }
            }
        }
    }

    // Если клетка пустая - ищем того, кто хочет переместиться/размножиться
    if (speciesID == 0u)
    {
        // Проверяем соседей на перемещение
        for (int i = 0; i < 4; i++)
        {
            ivec2 neighborPos = pos + DIRECTIONS[i];

            neighborPos.x = (neighborPos.x + int(worldSize.x)) % int(worldSize.x);
            neighborPos.y = clamp(neighborPos.y, 0, int(worldSize.y) - 1);

            uint neighborSpecies = texelFetch(speciesTexture, neighborPos, 0).r;
            if (neighborSpecies == 0u)
                continue;

            uvec4 neighborState = texelFetch(worldStateTexture, neighborPos, 0);
            uint neighborDirection = (neighborState.r >> 8) & 0xFFu;
            uint neighborLastAction = neighborState.b & 0xFFu;
            uint neighborOpcode = neighborLastAction & 0xFu;

            // Проверяем движение
            if (neighborOpcode == OP_MOVE)
            {
                ivec2 directionVector = pos - neighborPos;

                // Нормализуем с учетом wrap по X
                if (directionVector.x > int(worldSize.x) / 2)
                    directionVector.x -= int(worldSize.x);
                else if (directionVector.x < -int(worldSize.x) / 2)
                    directionVector.x += int(worldSize.x);

                int directionToUs = -1;
                for (int j = 0; j < 4; j++)
                {
                    if (DIRECTIONS[j] == directionVector)
                    {
                        directionToUs = j;
                        break;
                    }
                }

                if (directionToUs != -1 && uint(directionToUs) == neighborDirection)
                {
                    // Второй блок (биты 4-7): 1 бит флаг + 2 бита направление
                    directedActions |= (0x1u << 4); // Флаг движения
                    directedActions |= (uint(i) << 5); // Направление
                    break;
                }
            }
        }
        
        // Проверяем соседей на размножение
        for (int i = 0; i < 4; i++)
        {
            ivec2 neighborPos = pos + DIRECTIONS[i];

            neighborPos.x = (neighborPos.x + int(worldSize.x)) % int(worldSize.x);
            neighborPos.y = clamp(neighborPos.y, 0, int(worldSize.y) - 1);

            uint neighborSpecies = texelFetch(speciesTexture, neighborPos, 0).r;
            if (neighborSpecies == 0u)
                continue;

            uvec4 neighborState = texelFetch(worldStateTexture, neighborPos, 0);
            uint neighborDirection = (neighborState.r >> 8) & 0xFFu;
            uint neighborEnergy = neighborState.g & 0xFFu;
            uint neighborLastAction = neighborState.b & 0xFFu;
            uint neighborOpcode = neighborLastAction & 0xFu;

            // Проверяем размножение
            if (neighborOpcode == OP_REPRODUCE && neighborEnergy > REPRODUCE_THRESHOLD)
            {
                ivec2 directionVector = pos - neighborPos;

                // Нормализуем с учетом wrap по X
                if (directionVector.x > int(worldSize.x) / 2)
                    directionVector.x -= int(worldSize.x);
                else if (directionVector.x < -int(worldSize.x) / 2)
                    directionVector.x += int(worldSize.x);

                int directionToUs = -1;
                for (int j = 0; j < 4; j++)
                {
                    if (DIRECTIONS[j] == directionVector)
                    {
                        directionToUs = j;
                        break;
                    }
                }

                if (directionToUs != -1 && uint(directionToUs) == neighborDirection)
                {
                    // Третий блок (биты 8-11): 1 бит флаг + 2 бита направление
                    directedActions |= (0x1u << 8); // Флаг размножения
                    directedActions |= (uint(i) << 9); // Направление
                    break;
                }
            }
        }
        
    }

    // Упаковка в worldState (bytes 6-7)
    outWorldState.r = dnaPosition | (direction << 8);
    outWorldState.g = energy | (parameters << 8);
    outWorldState.b = lastAction | (minerals << 8);
    outWorldState.a = directedActions; // Bytes 6-7

    outSpecies = speciesID;
    outAge = age;
}
