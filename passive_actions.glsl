#version 430 core

// Входные текстуры
uniform usampler2D speciesTexture;
uniform usampler2D worldStateTexture;
uniform usampler2D ageTexture;
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

layout(std430, binding = 3) coherent buffer BirthCounterBuffer {
    uint speciesBorn[];
};

layout(std430, binding = 4) coherent buffer DeathCounterBuffer {
    uint speciesDied[];
};

// Выходные данные (три текстуры)
layout(location = 0) out uint outSpecies;
layout(location = 1) out uvec4 outWorldState;
layout(location = 2) out uint outAge;

// Константы
const float PI = 3.14159265359;
const float SUN_SPEED = 0.02;

const uint OP_PHOTOSYNTHESIS = 0x1u;
const uint OP_CHEMOSYNTHESIS = 0x2u;
const uint OP_GROW_TEETH = 0x5u;
const uint OP_GROW_ARMOR = 0x6u;
const uint OP_GROW_PHOTOSYNTHESIS = 0x7u;
const uint OP_GROW_CHEMOSYNTHESIS = 0x8u;

const uint PHOTOSYNTHESIS_DENOMINATOR = 32u;
const uint CHEMOSYNTHESIS_DENOMINATOR = 256u;
const uint CHEMOSYNTHESIS_ENERGY_MULTIPLIER = 2u;
const uint GROW_ENERGY_THRESHOLD = 40u;
const uint GROW_ENERGY_COST = 32u;
const uint MINERALS_ON_DEATH = 24u;

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
    uint age = texelFetch(ageTexture, pos, 0).r;

    // Если пустая клетка - ничего не делать
    if (speciesID == 0u)
    {
        outSpecies = 0u;
        outWorldState = worldState;
        outAge = 0u;
        return;
    }

    // Распаковка состояния мира
    // Byte 0: dnaPosition
    // Byte 1: direction
    // Byte 2: energy
    // Byte 3: parameters (4 органа по 2 бита)
    // Byte 4: opcode
    // Byte 5: mineralsData (сurrent/next)
    // Byte 6: reserved
    // Byte 7: reserved
    uint dnaPosition = worldState.r & 0xFFu;
    uint direction = (worldState.r >> 8) & 0xFFu;
    uint energy = worldState.g & 0xFFu;
    uint parameters = (worldState.g >> 8) & 0xFFu;
    uint opcode = worldState.b & 0xFFu;
    uint minerals = (worldState.b >> 8) & 0xFFu;

    // Фотосинтез
    if (opcode == OP_PHOTOSYNTHESIS)
    {
        uint light = calculateLight(pos);
        uint photosynthesisLevel = (parameters >> 4) & 0x3u; // Биты 4-5
        // Увеличение энергии, округление вверх
        uint energyGain = (light * photosynthesisLevel + PHOTOSYNTHESIS_DENOMINATOR - 1u) / PHOTOSYNTHESIS_DENOMINATOR;
        energy = min(energy + energyGain, 255u);
    }

    // Хемосинтез
    else if (opcode == OP_CHEMOSYNTHESIS)
    {
        uint chemosynthesisLevel = (parameters >> 6) & 0x3u; // Биты 6-7
        uint mineralsConsumed = (minerals * chemosynthesisLevel + CHEMOSYNTHESIS_DENOMINATOR - 1u) / CHEMOSYNTHESIS_DENOMINATOR;
        energy = min(energy + mineralsConsumed * CHEMOSYNTHESIS_ENERGY_MULTIPLIER, 255u);
        minerals -= mineralsConsumed;
    }

    // Рост органов
    else if (opcode >= OP_GROW_TEETH && opcode <= OP_GROW_CHEMOSYNTHESIS)
    {
        uint organIndex = opcode - OP_GROW_TEETH; // 0-3
        uint currentLevel = (parameters >> (organIndex * 2u)) & 0x3u;

        if (currentLevel < 3u && energy > GROW_ENERGY_THRESHOLD)
        {
            // Увеличиваем уровень органа
            uint newLevel = currentLevel + 1u;
            uint mask = ~(0x3u << (organIndex * 2u));
            parameters = (parameters & mask) | (newLevel << (organIndex * 2u));

            // Вычитаем энергию
            energy -= GROW_ENERGY_COST;
        }
    }

    // Пассивная потеря энергии (метаболизм)
    if (energy > 0u) // && stepNumber % 2 == 0)
        energy -= 1u;

    // Увеличение возраста
    age += 1u;

    // Смерть от голода или старости (макс 255)
    if (energy == 0u || age >= 255u)
    {
        atomicAdd(speciesDied[speciesID], 1u);
        speciesID = 0u;
        minerals = min(minerals + MINERALS_ON_DEATH, 255u);
        age = 0u;
    }

    // Упаковка обратно в worldState
    outWorldState.r = dnaPosition | (direction << 8);
    outWorldState.g = energy | (parameters << 8);
    outWorldState.b = opcode | (minerals << 8);
    outWorldState.a = worldState.a;

    outSpecies = speciesID;
    outAge = age;
}