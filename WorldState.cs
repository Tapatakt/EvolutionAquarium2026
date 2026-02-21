namespace EvolutionAquarium2026;
class WorldState
{
    readonly Random _rnd = new();

    readonly int _worldX;
    readonly int _worldY;
    readonly int _maxSpecies;
    readonly int _maxDnaLen;

    public Flattened2dArray<byte> Dna { get; private set; }
    public uint[] Colors { get; private set; }
    public Flattened2dArray<byte> EvolutionDistance { get; private set; }
    public Flattened2dArray<uint> SpeciesMap { get; private set; }
    public uint[] SpeciesPopulation { get; private set; }
    public uint[] SpeciesBorn { get; private set; }
    public uint[] SpeciesDied { get; private set; }
    public uint[] SpeciesCreated { get; private set; }
    public List<int> MutatedSpecies { get; } = [];

    public WorldState(int worldX, int worldY, int maxSpecies, int maxDnaLen)
    {
        _worldX = worldX;
        _worldY = worldY;
        _maxSpecies = maxSpecies;
        _maxDnaLen = maxDnaLen;
        SpeciesMap = new(_worldX, _worldY);
        SpeciesPopulation = new uint[_maxSpecies];
        SpeciesBorn = new uint[_maxSpecies];
        SpeciesDied = new uint[_maxSpecies];
        SpeciesCreated = new uint[_maxSpecies];
        Dna = new(_maxDnaLen, _maxSpecies);
        Colors = new uint[_maxSpecies];
        EvolutionDistance = new(_maxSpecies, _maxSpecies);
    }

    public ushort[] Initialize()
    {

        InitializeDNA();
        CreateCreatures();
        RandomizeColors();
        InitializeEvolutionDistance();
        return InitializeCellStates();
    }

    private void InitializeEvolutionDistance()
    {
        for (int i = 0; i < _maxSpecies; i++)
            for (int j = 0; j < _maxSpecies; j++)
                EvolutionDistance[j, i] = (byte)(i == j ? 0 : 255);
    }

    private void RandomizeColors()
    {
        for (int i = 0; i < _maxSpecies; i++)
        {
            byte r = (byte)_rnd.Next(256);
            byte g = (byte)_rnd.Next(256);
            byte b = (byte)_rnd.Next(256);
            Colors[i] = (uint)(r | (g << 8) | (b << 16));
        }
    }

    private void CreateCreatures()
    {
        for (int k = 0; k < 1; k++)
            for (int i = 0; i < _maxSpecies; i++)
            {
                int x = _rnd.Next(0, _worldX);
                int y = _rnd.Next(0, _worldY);
                while (SpeciesMap[x, y] != 0)
                {
                    x = _rnd.Next(0, _worldX);
                    y = _rnd.Next(0, _worldY);
                }
                SpeciesMap[x, y] = (uint)i;
                SpeciesPopulation[i]++;
            }
    }

    private ushort[] InitializeCellStates()
    {
        
        ushort[] worldState = new ushort[_worldX * _worldY * 4];
        for (int x = 0; x < _worldX; x++)
            for (int y = 0; y < _worldY; y++)
            {
                ushort[] cellData = PackCellState(0, (byte)_rnd.Next(0, 4), 255, 0, 0, 0, 0, 0, 255);
                for (int i = 0; i < 4; i++)
                    worldState[y * _worldX * 4 + x * 4 + i] = cellData[i];
            }
        return worldState;
    }

    private void InitializeDNA()
    {
        for (int species = 1; species < _maxSpecies; species++)
            for (int pos = 0; pos < _maxDnaLen; pos++)
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

    public void Mutations(uint stepNumber)
    {
        int newSpecies = 0;
        int FindUnusedSpeciesId()
        {
            for (int i = newSpecies + 1; i < _maxSpecies; i++)
                if (SpeciesPopulation[i] == 0)
                    return i;
            return 0;
        }

        for (int m = 0; m < 100; m++)
        {
            int x = _rnd.Next(0, _worldX);
            int y = _rnd.Next(0, _worldY);
            if (SpeciesMap[x, y] == 0) continue;
            newSpecies = FindUnusedSpeciesId();
            if (newSpecies == 0) return;
            int oldSpecies = (int)SpeciesMap[x, y];
            SpeciesMap[x, y] = (uint)newSpecies;
            SpeciesPopulation[oldSpecies]--;
            SpeciesPopulation[newSpecies]++;
            for (int i = 0; i < _maxDnaLen; i++)
                Dna[i, newSpecies] = Dna[i, oldSpecies];

            int mutations = _rnd.Next(1, 5);
            for (int i = 0; i < mutations; i++)
                Dna[_rnd.Next(_maxDnaLen), newSpecies] = (byte)_rnd.Next(0, 256);

            byte r = (byte)Math.Clamp((Colors[oldSpecies] & 0xFF) + _rnd.Next(0, 31) - 15, 0, 255);
            byte g = (byte)Math.Clamp(((Colors[oldSpecies] >> 8) & 0xFF) + _rnd.Next(0, 31) - 15, 0, 255);
            byte b = (byte)Math.Clamp(((Colors[oldSpecies] >> 16) & 0xFF) + _rnd.Next(0, 31) - 15, 0, 255);
            Colors[newSpecies] = (uint)(r | (g << 8) | (b << 16));
            SpeciesCreated[newSpecies] = stepNumber;

            for (int i = 0; i < _maxSpecies; i++)
            {
                if (EvolutionDistance[oldSpecies, i] == 255)
                    EvolutionDistance[newSpecies, i] = 255;
                else EvolutionDistance[newSpecies, i] = (byte)(EvolutionDistance[oldSpecies, i] + 1);
                if (i == newSpecies) EvolutionDistance[newSpecies, i] = 0;
                if (i == oldSpecies) EvolutionDistance[newSpecies, i] = 1;
                EvolutionDistance[i, newSpecies] = EvolutionDistance[newSpecies, i];
            }

            MutatedSpecies.Add(newSpecies);
        }
    }

    public void UpdatePopulations()
    {
        for (int i = 1; i < _maxSpecies; i++)
        {
            SpeciesPopulation[i] += SpeciesBorn[i];
            SpeciesPopulation[i] -= SpeciesDied[i];
            SpeciesBorn[i] = 0;
            SpeciesDied[i] = 0;
        }
    }
}
