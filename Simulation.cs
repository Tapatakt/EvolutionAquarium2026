namespace EvolutionAquarium2026;
class Simulation
{
    const string VERTEX_SHADER_PATH = "vertex.glsl";
    const string THINKING_SHADER_PATH = "thinking.glsl";
    const string PASSIVE_ACTIONS_SHADER_PATH = "passive_actions.glsl";
    const string DIRECTED_ACTIONS_TRACKING_SHADER_PATH = "directed_actions_tracking.glsl";
    const string ATTACKS_SHADER_PATH = "attacks.glsl";
    const string MOVES_TO_SHADER_PATH = "moves_to.glsl";
    const string MOVES_FROM_SHADER_PATH = "moves_from.glsl";
    const string REPRODUCTIONS_SHADER_PATH = "reproductions.glsl";
    const string DIFFUSION_SHADER_PATH = "diffusion.glsl";
    const string VISUALIZE_SHADER_PATH = "visualize.glsl";
    const string DISPLAY_SHADER_PATH = "display.glsl";

    readonly Random _rnd = new();
    readonly GlHelper _glHelper;
    readonly Config _config;

    readonly int _screenX;
    readonly int _screenY;

    int _vertexShader;
    int _thinkingProgram;
    int _passiveActionsProgram;
    int _directedActionsTrackingProgram;
    int _attacksProgram;
    int _movesToProgram;
    int _movesFromProgram;
    int _reproductionProgram;
    int _diffusionProgram;
    int _visualizeProgram;
    int _displayProgram;
    int _renderTexture;
    int _renderFramebuffer;

    // Camera state
    float _cameraX = 0.5f;  // Center position (0-1 range)
    float _cameraY = 0.5f;
    float _cameraZoom = 1.0f;  // 1.0 = fit to screen, >1 = zoomed in

    int[] _speciesTextures = new int[2];
    int[] _worldStateTextures = new int[2];
    int[] _ageTextures = new int[2];
    int _currentBuffer = 0;
    int _dnaBuffer;
    int _colorsBuffer;
    int _relatednessBuffer;
    int _birthCounterBuffer;
    int _deathCounterBuffer;
    int _createdBuffer;

    int _quadVao;
    int _quadVbo;
    int _simulationFbo;

    readonly uint[] _zeroCounters;
    readonly WorldState _worldState;
    int _stepNumber = 0;
    uint _visualizationMode = 1;

    public object BuffersLock { get; } = new();
    public Simulation(Config config, int screenX, int screenY)
    {
        _config = config;
        _screenX = screenX;
        _screenY = screenY;
        _worldState = new(_config);
        _zeroCounters = new uint[_config.MaxSpecies];
        _glHelper = new(_config.WorldWidth, _config.WorldHeight);

        CompileAllShaders();
        CreateBuffersAndTextures();
        CreateQuad();
        UploadInitialData();
    }
    public void ChangeVisualizationMode(uint mode)
    {
        lock (BuffersLock)
        {
            _visualizationMode = mode;
        }
    }
    void CompileAllShaders()
    {
        _vertexShader = _glHelper.CompileShader(VERTEX_SHADER_PATH, ShaderType.VertexShader);
        _glHelper.SetVertexShader(_vertexShader);

        _thinkingProgram = _glHelper.CreateFragmentProgram(THINKING_SHADER_PATH, "thinking");
        _passiveActionsProgram = _glHelper.CreateFragmentProgram(PASSIVE_ACTIONS_SHADER_PATH, "passive_actions");
        _directedActionsTrackingProgram = _glHelper.CreateFragmentProgram(DIRECTED_ACTIONS_TRACKING_SHADER_PATH, "directed_actions_tracking");
        _attacksProgram = _glHelper.CreateFragmentProgram(ATTACKS_SHADER_PATH, "attacks");
        _movesToProgram = _glHelper.CreateFragmentProgram(MOVES_TO_SHADER_PATH, "moves_to");
        _movesFromProgram = _glHelper.CreateFragmentProgram(MOVES_FROM_SHADER_PATH, "moves_from");
        _reproductionProgram = _glHelper.CreateFragmentProgram(REPRODUCTIONS_SHADER_PATH, "reproduction");
        _diffusionProgram = _glHelper.CreateFragmentProgram(DIFFUSION_SHADER_PATH, "diffusion");
        _visualizeProgram = _glHelper.CreateFragmentProgram(VISUALIZE_SHADER_PATH, "visualize");
        _displayProgram = _glHelper.CreateFragmentProgram(DISPLAY_SHADER_PATH, "display");
    }


    void CreateBuffersAndTextures()
    {
        // Создание текстур видов (только speciesID, нужна для readback)
        for (int i = 0; i < 2; i++)
            _speciesTextures[i] = _glHelper.CreateTexture(
                InternalFormat.R32ui,
                PixelFormat.RedInteger,
                PixelType.UnsignedInt);

        for (int i = 0; i < 2; i++)
            _worldStateTextures[i] = _glHelper.CreateTexture(
                InternalFormat.Rgba16ui,
                PixelFormat.RgbaInteger,
                PixelType.UnsignedShort);

        for (int i = 0; i < 2; i++)
            _ageTextures[i] = _glHelper.CreateTexture(
                InternalFormat.R8ui,
                PixelFormat.RedInteger,
                PixelType.UnsignedByte);

        _dnaBuffer = _glHelper.CreateSSBO(_config.MaxSpecies * _config.MaxDnaLength, BufferUsage.StaticDraw);
        _colorsBuffer = _glHelper.CreateSSBO(_config.MaxSpecies * sizeof(uint), BufferUsage.StaticDraw);
        _relatednessBuffer = _glHelper.CreateSSBO(_config.MaxSpecies * _config.MaxSpecies, BufferUsage.StaticDraw);
        _birthCounterBuffer = _glHelper.CreateSSBO(_config.MaxSpecies * sizeof(uint), BufferUsage.DynamicRead);
        _deathCounterBuffer = _glHelper.CreateSSBO(_config.MaxSpecies * sizeof(uint), BufferUsage.DynamicRead);
        _createdBuffer = _glHelper.CreateSSBO(_config.MaxSpecies * sizeof(uint), BufferUsage.StaticDraw);

        _renderTexture = _glHelper.CreateTexture(
            InternalFormat.Rgba8,
            PixelFormat.Rgba,
            PixelType.UnsignedByte);

        // Create framebuffer for rendering
        _renderFramebuffer = GL.GenFramebuffer();

        // Create reusable FBO for simulation shaders
        _simulationFbo = GL.GenFramebuffer();
        GL.BindFramebuffer(FramebufferTarget.Framebuffer, _renderFramebuffer);
        GL.FramebufferTexture2D(FramebufferTarget.Framebuffer,
            FramebufferAttachment.ColorAttachment0,
            TextureTarget.Texture2d, _renderTexture, 0);
        GL.BindFramebuffer(FramebufferTarget.Framebuffer, 0);
    }

    void CreateQuad()
    {
        // Полноэкранный квад для рендеринга
        float[] quadVertices =
        {
            -1f, -1f,
             1f, -1f,
            -1f,  1f,
             1f,  1f
        };

        _quadVao = GL.GenVertexArray();
        _quadVbo = GL.GenBuffer();

        GL.BindVertexArray(_quadVao);
        GL.BindBuffer(BufferTarget.ArrayBuffer, _quadVbo);
        GL.BufferData(BufferTarget.ArrayBuffer, quadVertices.Length * sizeof(float), quadVertices, BufferUsage.StaticDraw);

        GL.EnableVertexAttribArray(0);
        GL.VertexAttribPointer(0, 2, VertexAttribPointerType.Float, false, 2 * sizeof(float), 0);
    }


    void UploadInitialData()
    {
        ushort[] initialWorldState = _worldState.Initialize();

        // Upload to buffer [0] only - first simulation step will write to [1]
        _glHelper.UploadTexture(_speciesTextures[0], PixelFormat.RedInteger, PixelType.UnsignedInt, _worldState.SpeciesMap.Data);
        _glHelper.UploadTexture(_worldStateTextures[0], PixelFormat.RgbaInteger, PixelType.UnsignedShort, initialWorldState);
        _glHelper.UploadTexture(_ageTextures[0], PixelFormat.RedInteger, PixelType.UnsignedByte, _worldState.Ages.Data);

        _glHelper.UploadBuffer(_dnaBuffer, _config.MaxSpecies * _config.MaxDnaLength, _worldState.Dna.Data);
        _glHelper.UploadBuffer(_colorsBuffer, _config.MaxSpecies * sizeof(uint), _worldState.Colors);
        _glHelper.UploadBuffer(_relatednessBuffer, _config.MaxSpecies * _config.MaxSpecies, _worldState.EvolutionDistance.Data);
        _glHelper.UploadBuffer(_birthCounterBuffer, _config.MaxSpecies * sizeof(uint), _worldState.SpeciesBorn);
        _glHelper.UploadBuffer(_deathCounterBuffer, _config.MaxSpecies * sizeof(uint), _worldState.SpeciesDied);
        _glHelper.UploadBuffer(_createdBuffer, _config.MaxSpecies * sizeof(uint), _worldState.SpeciesCreated);
    }

    public void Step()
    {
        _stepNumber++;
        lock (BuffersLock)
        {
            UploadDataToGPU();

            // Шаг 1: Мышление существ
            RunShaderToTextures(_thinkingProgram);

            // Шаг 2: Обновление мира
            RunShaderToTextures(_passiveActionsProgram);
            GL.MemoryBarrier(MemoryBarrierMask.ShaderStorageBarrierBit);
            RunShaderToTextures(_directedActionsTrackingProgram);
            RunShaderToTextures(_attacksProgram);
            GL.MemoryBarrier(MemoryBarrierMask.ShaderStorageBarrierBit);
            RunShaderToTextures(_movesToProgram);
            RunShaderToTextures(_movesFromProgram);
            RunShaderToTextures(_reproductionProgram);
            GL.MemoryBarrier(MemoryBarrierMask.ShaderStorageBarrierBit);
            RunShaderToTextures(_diffusionProgram);

            // Шаг 3: Чтение данных обратно с GPU
            ReadbackFromGPU();
        }
        // Шаг 4: Подсчет популяций и мутации
        _worldState.UpdatePopulations((uint)_stepNumber);
        _worldState.Mutations((uint)_stepNumber);

        // Шаг 5: Визуализация
        RunShaderToRenderTexture(_visualizeProgram);
        DisplayRenderTexture();
    }



    void UploadDataToGPU()
    {
        _glHelper.UploadTexture(_speciesTextures[_currentBuffer], PixelFormat.RedInteger, PixelType.UnsignedInt, _worldState.SpeciesMap.Data);
        
        // Upload DNA, Colors and EvolutionDistance for mutated species
        foreach (int species in _worldState.MutatedSpecies)
        {
            int dnaOffset = species * _config.MaxDnaLength;
            _glHelper.UploadBuffer(_dnaBuffer, _config.MaxDnaLength, _worldState.Dna.Data, bufferOffset: dnaOffset, dataOffset: dnaOffset);
            _glHelper.UploadBuffer(_colorsBuffer, sizeof(uint), _worldState.Colors, bufferOffset: species * sizeof(uint), dataOffset: species);
            
            int evoOffset = species * _config.MaxSpecies;
            _glHelper.UploadBuffer(_relatednessBuffer, _config.MaxSpecies, _worldState.EvolutionDistance.Data, bufferOffset: evoOffset, dataOffset: evoOffset);
        }
        _worldState.MutatedSpecies.Clear();

        // Note: Birth/Death counters are NOT uploaded - they start at 0 on GPU each frame
        // Shaders atomically increment, we read back, then reset GPU counters to 0
    }

    void ReadbackFromGPU()
    {
        // Чтение текстуры видов
        GL.BindTexture(TextureTarget.Texture2d, _speciesTextures[_currentBuffer]);
        GL.GetTexImage(TextureTarget.Texture2d, 0,
            PixelFormat.RedInteger, PixelType.UnsignedInt, _worldState.SpeciesMap.Data);

        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, _birthCounterBuffer);
        GL.GetBufferSubData(BufferTarget.ShaderStorageBuffer, IntPtr.Zero, _config.MaxSpecies * sizeof(uint), _worldState.SpeciesBorn);

        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, _deathCounterBuffer);
        GL.GetBufferSubData(BufferTarget.ShaderStorageBuffer, IntPtr.Zero, _config.MaxSpecies * sizeof(uint), _worldState.SpeciesDied);

        ResetGPUCounters();
    }

    void ResetGPUCounters()
    {
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, _birthCounterBuffer);
        GL.BufferSubData(BufferTarget.ShaderStorageBuffer, IntPtr.Zero, _config.MaxSpecies * sizeof(uint), _zeroCounters);
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, _deathCounterBuffer);
        GL.BufferSubData(BufferTarget.ShaderStorageBuffer, IntPtr.Zero, _config.MaxSpecies * sizeof(uint), _zeroCounters);
    }


    void RunShaderToTextures(int program)
    {
        int readBuffer = _currentBuffer;
        int writeBuffer = 1 - _currentBuffer;

        // Reuse pre-created FBO, just reattach textures
        GL.BindFramebuffer(FramebufferTarget.Framebuffer, _simulationFbo);

        // Write to the OTHER buffer
        GL.FramebufferTexture2D(FramebufferTarget.Framebuffer,
            FramebufferAttachment.ColorAttachment0,
            TextureTarget.Texture2d, _speciesTextures[writeBuffer], 0);

        GL.FramebufferTexture2D(FramebufferTarget.Framebuffer,
            FramebufferAttachment.ColorAttachment1,
            TextureTarget.Texture2d, _worldStateTextures[writeBuffer], 0);

        GL.FramebufferTexture2D(FramebufferTarget.Framebuffer,
            FramebufferAttachment.ColorAttachment2,
            TextureTarget.Texture2d, _ageTextures[writeBuffer], 0);

        GL.DrawBuffers(3, [
            DrawBufferMode.ColorAttachment0,
            DrawBufferMode.ColorAttachment1,
            DrawBufferMode.ColorAttachment2
        ]);

        GL.Viewport(0, 0, _config.WorldWidth, _config.WorldHeight);

        GL.UseProgram(program);
        BindResources(program, readBuffer);  // Pass which buffer to read from

        GL.BindVertexArray(_quadVao);
        GL.DrawArrays(PrimitiveType.TriangleStrip, 0, 4);

        GL.BindFramebuffer(FramebufferTarget.Framebuffer, 0);

        // Swap buffers
        _currentBuffer = writeBuffer;
    }

    void RunShaderToRenderTexture(int program)
    {
        GL.BindFramebuffer(FramebufferTarget.Framebuffer, _renderFramebuffer);
        GL.Viewport(0, 0, _config.WorldWidth, _config.WorldHeight);

        GL.UseProgram(program);
        BindResources(program, _currentBuffer);

        GL.BindVertexArray(_quadVao);
        GL.DrawArrays(PrimitiveType.TriangleStrip, 0, 4);

        GL.BindFramebuffer(FramebufferTarget.Framebuffer, 0);
    }

    void DisplayRenderTexture()
    {
        GL.BindFramebuffer(FramebufferTarget.Framebuffer, 0);
        GL.Viewport(0, 0, _screenX, _screenY);

        GL.UseProgram(_displayProgram);

        // Bind the rendered texture
        GL.ActiveTexture(TextureUnit.Texture0);
        GL.BindTexture(TextureTarget.Texture2d, _renderTexture);
        GL.Uniform1i(GL.GetUniformLocation(_displayProgram, "renderTexture"), 0);

        // Send camera parameters
        GL.Uniform2f(GL.GetUniformLocation(_displayProgram, "cameraPos"), _cameraX, _cameraY);
        GL.Uniform1f(GL.GetUniformLocation(_displayProgram, "cameraZoom"), _cameraZoom);
        GL.Uniform2f(GL.GetUniformLocation(_displayProgram, "screenSize"), _screenX, _screenY);
        GL.Uniform2f(GL.GetUniformLocation(_displayProgram, "worldSize"), _config.WorldWidth, _config.WorldHeight);

        GL.BindVertexArray(_quadVao);
        GL.DrawArrays(PrimitiveType.TriangleStrip, 0, 4);
    }

    void BindResources(int program, int readBuffer)
    {
        _glHelper.BindTexture(program, TextureUnit.Texture0, _speciesTextures[readBuffer], "speciesTexture");
        _glHelper.BindTexture(program, TextureUnit.Texture1, _worldStateTextures[readBuffer], "worldStateTexture");
        _glHelper.BindTexture(program, TextureUnit.Texture2, _ageTextures[readBuffer], "ageTexture");

        _glHelper.BindUniform(program, "worldSize", (float)_config.WorldWidth, (float)_config.WorldHeight);
        _glHelper.BindUniform(program, "stepNumber", (uint)_stepNumber);
        _glHelper.BindUniform(program, "visualizationMode", _visualizationMode);

        // Привязка SSBO
        GL.BindBufferBase(BufferTarget.ShaderStorageBuffer, 0, _dnaBuffer);
        GL.BindBufferBase(BufferTarget.ShaderStorageBuffer, 1, _colorsBuffer);
        GL.BindBufferBase(BufferTarget.ShaderStorageBuffer, 2, _relatednessBuffer);
        GL.BindBufferBase(BufferTarget.ShaderStorageBuffer, 3, _birthCounterBuffer);
        GL.BindBufferBase(BufferTarget.ShaderStorageBuffer, 4, _deathCounterBuffer);
        GL.BindBufferBase(BufferTarget.ShaderStorageBuffer, 5, _createdBuffer);
    }

    public void SetCamera(float x, float y, float zoom)
    {
        _cameraX = Math.Clamp(x, 0f, 1f);
        _cameraY = Math.Clamp(y, 0f, 1f);
        _cameraZoom = Math.Max(0.1f, zoom);
    }

    public void Pan(float dx, float dy)
    {
        _cameraX = Math.Clamp(_cameraX + dx / _cameraZoom, 0f, 1f);
        _cameraY = Math.Clamp(_cameraY + dy / _cameraZoom, 0f, 1f);
    }

    public void Zoom(float factor)
    {
        _cameraZoom = Math.Max(0.1f, _cameraZoom * factor);
    }
}