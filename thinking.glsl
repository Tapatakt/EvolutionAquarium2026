#version 430 core

// Входные текстуры
uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform vec2 worldSize;
uniform uint stepNumber;

// SSBO
layout(std430, binding = 0) buffer DNABuffer {
    uint dna[];
};

layout(std430, binding = 1) buffer ColorsBuffer {
    uint colors[];
};

layout(std430, binding = 2) buffer EvolutionDistanceBuffer {
    uint evolutionDistance[];
};

layout(std430, binding = 5) buffer SpeciesCreatedBuffer {
    uint speciesCreated[];
};

// Выходные данные (две текстуры)
layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;

// Константы
const int MAX_COMMANDS = 20;
const int MAX_DNA_LEN = 256;
const int MAX_SPECIES = 20000;
const float PI = 3.14159265359;
const float SUN_SPEED = 0.02;

// Опкоды команд
const uint OP_RESET = 0x0u;
const uint OP_PHOTOSYNTHESIS = 0x1u;
const uint OP_CHEMOSYNTHESIS = 0x2u;
const uint OP_MOVE = 0x3u;
const uint OP_ATTACK = 0x4u;
const uint OP_GROW_TEETH = 0x5u;
const uint OP_GROW_ARMOR = 0x6u;
const uint OP_GROW_PHOTOSYNTHESIS = 0x7u;
const uint OP_GROW_CHEMOSYNTHESIS = 0x8u;
const uint OP_REPRODUCE = 0x9u;
const uint OP_ROTATE_CW = 0xAu;
const uint OP_ROTATE_CCW = 0xBu;
const uint OP_CHECK_ENERGY = 0xCu;
const uint OP_CHECK_LIGHT = 0xDu;
const uint OP_CHECK_MINERALS = 0xEu;
const uint OP_CHECK_FORWARD = 0xFu;

// Направления: 0=North, 1=East, 2=South, 3=West
const ivec2 DIRECTIONS[4] = ivec2[4](
    ivec2(0, 1),   // North
    ivec2(1, 0),   // East
    ivec2(0, -1),  // South
    ivec2(-1, 0)   // West
    );

// Вычисление уровня света для данной позиции
uint calculateLight(ivec2 pos)
{
    float x = float(pos.x);
    float y = float(pos.y);

    float phase = 2.0 * PI * (x / worldSize.x + float(stepNumber) * SUN_SPEED);
    float seasonBig = 1.0 + sin(float(stepNumber) / 1037) * 0.1;
    float seasonSmall = 1.0 + sin(float(stepNumber) / 11) * 0.1;
    float lightValue = clamp(0.5 + sin(phase), 0.0, 1.0) * seasonBig * seasonSmall * y / worldSize.y;

    // Нормализуем от [0, 1] в [0, 255]
    return uint(lightValue * 255.0);
}

void main()
{
    ivec2 pos = ivec2(gl_FragCoord.xy);

    // Чтение текущего состояния
    uint speciesID = texelFetch(speciesTexture, pos, 0).r;
    uvec4 worldState = texelFetch(worldStateTexture, pos, 0);

    // Если пустая клетка - ничего не делать
    if (speciesID == 0u)
    {
        outSpecies = 0u;
        outWorldState = worldState;
        return;
    }

    // Распаковка состояния мира
    // Byte 0: dnaPosition
    // Byte 1: direction
    // Byte 2: energy
    // Byte 3: parameters (4 органа по 2 бита)
    // Byte 4: lastAction
    // Byte 5: minerals
    // Byte 6: action directions at the target
    // Byte 7: action directions at the target
    uint dnaPosition = worldState.r & 0xFFu;
    uint direction = (worldState.r >> 8) & 0xFFu;
    uint energy = worldState.g & 0xFFu;
    uint parameters = (worldState.g >> 8) & 0xFFu;
    uint lastAction = worldState.b & 0xFFu;
    uint minerals = (worldState.b >> 8) & 0xFFu;

    // Вычисляем уровень света
    uint light = calculateLight(pos);

    // Выполнение ДНК
    int commandsExecuted = 0;
    bool actionPerformed = false;

    while (commandsExecuted < MAX_COMMANDS && !actionPerformed)
    {
        // Чтение команды из ДНК
        int dnaIndex = int(speciesID) * MAX_DNA_LEN + int(dnaPosition);
        int dnaByteIndex = int(speciesID) * MAX_DNA_LEN + int(dnaPosition);
        int dnaWordIndex = dnaByteIndex / 4;
        int dnaByteOffset = dnaByteIndex % 4;
        uint dnaWord = dna[dnaWordIndex];
        uint command = (dnaWord >> (dnaByteOffset * 8u)) & 0xFFu;

        uint opcode = command & 0xFu;           // Биты 0-3
        uint param56 = (command >> 4) & 0x3u;   // Биты 5-6
        uint param78 = (command >> 6) & 0x3u;   // Биты 7-8

        commandsExecuted++;
        dnaPosition = (dnaPosition + 1u) % uint(MAX_DNA_LEN);

        if (opcode == OP_RESET)
        {
            dnaPosition = 0;
        }
        else if (opcode >= OP_PHOTOSYNTHESIS && opcode < OP_ROTATE_CW) // Команды действий - только записываем lastAction
        {
            lastAction = opcode; // Сохраняем как команду
            actionPerformed = true;
        }
        else if (opcode == OP_ROTATE_CW)
        {
            // Поворот выполняется сразу, т.к. не влияет на другие клетки
            direction = (direction + 1u) & 0x3u;
        }
        else if (opcode == OP_ROTATE_CCW)
        {
            // Поворот выполняется сразу
            direction = (direction + 3u) & 0x3u; // +3 = -1 mod 4
        }
        else if (opcode == OP_CHECK_ENERGY)
        {
            // Проверка уровня энергии
            uint energyQuarter = energy / 64u; // 0-3
            if (energyQuarter == param56)
            {
                // Успешная проверка - прыжок
                uint jump = (param78 + 1u) * 16u;
                dnaPosition = (dnaPosition + jump) % uint(MAX_DNA_LEN);
            }
        }
        else if (opcode == OP_CHECK_LIGHT)
        {
            // Проверка уровня света
            uint lightQuarter = light / 64u; // 0-3
            if (lightQuarter == param56)
            {
                uint jump = (param78 + 1u) * 16u;
                dnaPosition = (dnaPosition + jump) % uint(MAX_DNA_LEN);
            }
        }
        else if (opcode == OP_CHECK_MINERALS)
        {         
            uint mineralsQuarter = minerals / 64u; // 0-3
            if (mineralsQuarter == param56)
            {
                uint jump = (param78 + 1u) * 16u;
                dnaPosition = (dnaPosition + jump) % uint(MAX_DNA_LEN);
            }
        }
        else if (opcode == OP_CHECK_FORWARD)
        {
            // Проверка того, что впереди
            ivec2 forwardPos = pos + DIRECTIONS[direction];

            // wrap по X
            forwardPos.x = (forwardPos.x + int(worldSize.x)) % int(worldSize.x);

            uint forwardSpecies;
            if (forwardPos.y == -1 || forwardPos.y == worldSize.y)
                forwardSpecies = 0u;
            else
                forwardSpecies = texelFetch(speciesTexture, forwardPos, 0).r;

            bool checkPassed = false;

            if (param56 == 0u)
            {
                checkPassed = forwardSpecies == 0u;
            }
            else
            {
                // Use row of more recently created species for up-to-date distance
                uint speciesACreated = speciesCreated[speciesID];
                uint speciesBCreated = speciesCreated[forwardSpecies];
                uint rowSpecies = (speciesACreated >= speciesBCreated) ? speciesID : forwardSpecies;
                uint colSpecies = (speciesACreated >= speciesBCreated) ? forwardSpecies : speciesID;
                
                int distByteIndex = int(rowSpecies) * MAX_SPECIES + int(colSpecies);
                int distWordIndex = distByteIndex / 4;
                int distByteOffset = distByteIndex % 4;
                uint distWord = evolutionDistance[distWordIndex];
                uint distance = (distWord >> (distByteOffset * 8u)) & 0xFFu;
                if (param56 == 1u)
                {
                    // Тот же или почти тот же вид
                    checkPassed = (distance <= 2u);
                }
                else if (param56 == 2u)
                {
                    // Довольно близкий родственник
                    if (forwardSpecies > 0u && forwardSpecies != speciesID)
                    {
                        checkPassed = (distance <= 5u);
                    }
                }
                else if (param56 == 3u)
                {
                    // Не близкий родственник
                    checkPassed = (distance >= 6u);
                }
            }

            if (checkPassed)
            {
                uint jump = (param78 + 1u) * 32u;
                dnaPosition = (dnaPosition + jump) % uint(MAX_DNA_LEN);
            }
        }
    }
    // Упаковка обратно в worldState
    outWorldState.r = dnaPosition | (direction << 8);
    outWorldState.g = energy | (parameters << 8);
    outWorldState.b = lastAction | (minerals << 8);
    outWorldState.a = 0u;

    outSpecies = speciesID;
}