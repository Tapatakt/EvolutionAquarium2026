namespace EvolutionAquarium2026;

class WorldState
{
    readonly Random _rnd = new();
    readonly Config _config;
    int _unusedSpecies = 1;
    public Flattened2dArray<byte> Dna { get; private set; }
    public uint[] Colors { get; private set; }
    public Flattened2dArray<byte> EvolutionDistance { get; private set; }
    public Flattened2dArray<uint> SpeciesMap { get; private set; }
    public uint[] SpeciesPopulation { get; private set; }
    public uint[] SpeciesBorn { get; private set; }
    public uint[] SpeciesDied { get; private set; }
    public uint[] SpeciesCreated { get; private set; }
    public Flattened2dArray<byte> Ages { get; private set; }
    public List<int> MutatedSpecies { get; } = [];

    public WorldState(Config config)
    {
        _config = config;
        SpeciesMap = new(_config.WorldWidth, _config.WorldHeight);
        SpeciesPopulation = new uint[_config.MaxSpecies];
        SpeciesBorn = new uint[_config.MaxSpecies];
        SpeciesDied = new uint[_config.MaxSpecies];
        SpeciesCreated = new uint[_config.MaxSpecies];
        Ages = new(_config.WorldWidth, _config.WorldHeight);
        Dna = new(_config.MaxDnaLength, _config.MaxSpecies);
        Colors = new uint[_config.MaxSpecies];
        EvolutionDistance = new(_config.MaxSpecies, _config.MaxSpecies);
    }

    public ushort[] Initialize()
    {

        InitializeDNA();
        //CreateCreatures();
        RandomizeColors();
        InitializeEvolutionDistance();
        return InitializeCellStates();
    }

    private void InitializeEvolutionDistance()
    {
        for (int i = 0; i < _config.MaxSpecies; i++)
            for (int j = 0; j < _config.MaxSpecies; j++)
                EvolutionDistance[j, i] = (byte)(i == j ? 0 : 255);
    }

    private void RandomizeColors()
    {
        for (int i = 0; i < _config.MaxSpecies; i++)
        {
            byte r = (byte)_rnd.Next(256);
            byte g = (byte)_rnd.Next(256);
            byte b = (byte)_rnd.Next(256);
            Colors[i] = (uint)(r | (g << 8) | (b << 16));
        }
    }

    private void CreateCreatures()
    {
        for (int i = 0; i < _config.MaxSpecies; i++)
        {
            int x = _rnd.Next(0, _config.WorldWidth);
            int y = _rnd.Next(0, _config.WorldHeight);
            while (SpeciesMap[x, y] != 0)
            {
                x = _rnd.Next(0, _config.WorldWidth);
                y = _rnd.Next(0, _config.WorldHeight);
            }
            SpeciesMap[x, y] = (uint)i;
            SpeciesPopulation[i]++;
        }
        _unusedSpecies = -1;
    }

    private ushort[] InitializeCellStates()
    {

        ushort[] worldState = new ushort[_config.WorldWidth * _config.WorldHeight * 4];
        for (int x = 0; x < _config.WorldWidth; x++)
            for (int y = 0; y < _config.WorldHeight; y++)
            {
                ushort[] cellData = PackCellState(0, (byte)_rnd.Next(0, 4), 255, 0, 0, 0, 0, 0, 255);
                for (int i = 0; i < 4; i++)
                    worldState[y * _config.WorldWidth * 4 + x * 4 + i] = cellData[i];
            }
        return worldState;
    }

    private void InitializeDNA()
    {
        for (int species = 1; species < _config.MaxSpecies; species++)
            for (int pos = 0; pos < _config.MaxDnaLength; pos++)
                Dna[pos, species] = (byte)_rnd.Next(0, 256);
    }

    public static ushort[] PackCellState(
        byte dnaPosition,
        byte direction,
        byte energy,
        byte teeth,
        byte armor,
        byte photosynthesis,
        byte chemosynthesis,
        byte lastAction,
        byte minerals)
    {
        byte parameters = (byte)(
            (teeth & 0x3) |
            ((armor & 0x3) << 2) |
            ((photosynthesis & 0x3) << 4) |
            ((chemosynthesis & 0x3) << 6)
        );

        return
        [
            (ushort)(dnaPosition | (direction << 8)),
            (ushort)(energy | (parameters << 8)),
            (ushort)(lastAction | (minerals << 8)),
            0
        ];
    }
    private void FindNextUnusedSpecies()
    {
        int speciesID = _unusedSpecies;
        for (int i = 0; i < _config.MaxSpecies - 1; i++)
        {
            speciesID = (speciesID + 1) % _config.MaxSpecies;
            if (speciesID == 0) speciesID++;
            if (SpeciesPopulation[speciesID] == 0)
            {
                _unusedSpecies = speciesID;
                return;
            }
        }
        _unusedSpecies = -1;
    }
    public void Mutations(uint stepNumber)
    {
        for (int m = 0; m < _config.MutationRate; m++)
        {
            if (_unusedSpecies == -1) return;
            int x = _rnd.Next(0, _config.WorldWidth);
            int y = _rnd.Next(0, _config.WorldHeight);
            if (SpeciesMap[x, y] == 0) continue;
            int oldSpecies = (int)SpeciesMap[x, y];
            SpeciesMap[x, y] = (uint)_unusedSpecies;
            SpeciesPopulation[oldSpecies]--;
            SpeciesPopulation[_unusedSpecies]++;
            for (int i = 0; i < _config.MaxDnaLength; i++)
                Dna[i, _unusedSpecies] = Dna[i, oldSpecies];

            int mutations = _rnd.Next(1, 5);
            for (int i = 0; i < mutations; i++)
                Dna[_rnd.Next(_config.MaxDnaLength), _unusedSpecies] = (byte)_rnd.Next(0, 256);

            byte r = (byte)Math.Clamp((Colors[oldSpecies] & 0xFF) + _rnd.Next(0, 31) - 15, 0, 255);
            byte g = (byte)Math.Clamp(((Colors[oldSpecies] >> 8) & 0xFF) + _rnd.Next(0, 31) - 15, 0, 255);
            byte b = (byte)Math.Clamp(((Colors[oldSpecies] >> 16) & 0xFF) + _rnd.Next(0, 31) - 15, 0, 255);
            Colors[_unusedSpecies] = (uint)(r | (g << 8) | (b << 16));
            SpeciesCreated[_unusedSpecies] = stepNumber;

            for (int i = 0; i < _config.MaxSpecies; i++)
            {
                if (EvolutionDistance[oldSpecies, i] == 255)
                    EvolutionDistance[_unusedSpecies, i] = 255;
                else EvolutionDistance[_unusedSpecies, i] = (byte)(EvolutionDistance[oldSpecies, i] + 1);
                if (i == _unusedSpecies) EvolutionDistance[_unusedSpecies, i] = 0;
                if (i == oldSpecies) EvolutionDistance[_unusedSpecies, i] = 1;
                EvolutionDistance[i, _unusedSpecies] = EvolutionDistance[_unusedSpecies, i];
            }

            MutatedSpecies.Add(_unusedSpecies);
            FindNextUnusedSpecies();
        }
    }

    public void UpdatePopulations(uint stepNumber)
    {
        for (int i = 1; i < _config.MaxSpecies; i++)
        {
            SpeciesPopulation[i] += SpeciesBorn[i];
            SpeciesPopulation[i] -= SpeciesDied[i];
            if (SpeciesPopulation[i] == 0 && _unusedSpecies == -1)
                _unusedSpecies = i;
            SpeciesBorn[i] = 0;
            SpeciesDied[i] = 0;
        }

        EnsureMinCreatures(stepNumber);
    }

    void EnsureMinCreatures(uint stepNumber)
    {
        uint totalPopulation = 0;
        for (int i = 1; i < _config.MaxSpecies; i++)
            totalPopulation += SpeciesPopulation[i];

        while (totalPopulation < _config.MinCreatures)
        {
            if (_unusedSpecies == -1) return;
            // Find empty cell
            int x = _rnd.Next(0, _config.WorldWidth);
            int y = _rnd.Next(0, _config.WorldHeight);
            if (SpeciesMap[x, y] != 0) continue;
            
            int newSpecies = _unusedSpecies;
            
            // Create creature with random DNA
            SpeciesMap[x, y] = (uint)newSpecies;
            SpeciesPopulation[newSpecies] = 1;
            SpeciesCreated[newSpecies] = stepNumber;
            
            for (int pos = 0; pos < _config.MaxDnaLength; pos++)
                Dna[pos, newSpecies] = (byte)_rnd.Next(0, 256);

            // Random color
            byte r = (byte)_rnd.Next(256);
            byte g = (byte)_rnd.Next(256);
            byte b = (byte)_rnd.Next(256);
            Colors[newSpecies] = (uint)(r | (g << 8) | (b << 16));

            // Init evolutionDistance: unrelated to all others (255), 0 to self
            for (int i = 0; i < _config.MaxSpecies; i++)
            {
                EvolutionDistance[newSpecies, i] = 255;
                EvolutionDistance[i, newSpecies] = 255;
            }
            EvolutionDistance[newSpecies, newSpecies] = 0;

            // Mark as mutated so DNA/color/evolutionDistance gets uploaded
            if (!MutatedSpecies.Contains(newSpecies))
                MutatedSpecies.Add(newSpecies);

            totalPopulation++;
            FindNextUnusedSpecies();
        }
    }
}
