namespace EvolutionAquarium2026;
class GlHelper
{
    readonly int _worldX;
    readonly int _worldY;
    int _vertexShader;

    public GlHelper(int worldX, int worldY)
    {
        _worldX = worldX;
        _worldY = worldY;
    }

    public void SetVertexShader(int vertexShader) => _vertexShader = vertexShader;

    public int CreateFragmentProgram(string path, string name)
    {
        int program = GL.CreateProgram();
        int fragment = CompileShader(path, ShaderType.FragmentShader);
        GL.AttachShader(program, _vertexShader);
        GL.AttachShader(program, fragment);
        GL.LinkProgram(program);

        GL.GetProgrami(program, ProgramProperty.LinkStatus, out int status);
        if (status == 0)
        {
            GL.GetProgramInfoLog(program, out string info);
            throw new Exception($"Ошибка линковки программы {name}: {info}");
        }

        return program;
    }

    public int CompileShader(string path, ShaderType type)
    {
        string source = File.ReadAllText(path);
        int shader = GL.CreateShader(type);
        GL.ShaderSource(shader, source);
        GL.CompileShader(shader);

        GL.GetShaderi(shader, ShaderParameterName.CompileStatus, out int status);
        if (status == 0)
        {
            GL.GetShaderInfoLog(shader, out string info);
            throw new Exception($"Ошибка компиляции шейдера {path}: {info}");
        }

        return shader;
    }

    public int CreateSSBO(int size, BufferUsage usage)
    {
        int buffer = GL.GenBuffer();
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, buffer);
        GL.BufferData(BufferTarget.ShaderStorageBuffer, size, IntPtr.Zero, usage);
        return buffer;
    }

    public int CreateTexture(InternalFormat internalFormat, PixelFormat pixelFormat, PixelType pixelType)
    {
        int texture = GL.GenTexture();
        GL.BindTexture(TextureTarget.Texture2d, texture);
        GL.TexParameteri(TextureTarget.Texture2d, TextureParameterName.TextureWrapS, (int)TextureWrapMode.Repeat);
        GL.TexParameteri(TextureTarget.Texture2d, TextureParameterName.TextureWrapT, (int)TextureWrapMode.ClampToEdge);
        GL.TexParameteri(TextureTarget.Texture2d, TextureParameterName.TextureMinFilter, (int)TextureMinFilter.Nearest);
        GL.TexParameteri(TextureTarget.Texture2d, TextureParameterName.TextureMagFilter, (int)TextureMagFilter.Nearest);
        GL.TexImage2D(TextureTarget.Texture2d, 0, internalFormat,
            _worldX, _worldY, 0,
            pixelFormat, pixelType, IntPtr.Zero);
        return texture;
    }

    public void UploadTexture(int texture, PixelFormat pixelFormat, PixelType pixelType, ushort[] data)
    {
        GL.BindTexture(TextureTarget.Texture2d, texture);
        GL.TexSubImage2D(TextureTarget.Texture2d, 0, 0, 0, _worldX, _worldY, pixelFormat, pixelType, data);
    }

    public void UploadTexture(int texture, PixelFormat pixelFormat, PixelType pixelType, uint[] data)
    {
        GL.BindTexture(TextureTarget.Texture2d, texture);
        GL.TexSubImage2D(TextureTarget.Texture2d, 0, 0, 0, _worldX, _worldY, pixelFormat, pixelType, data);
    }

    public void UploadTexture(int texture, PixelFormat pixelFormat, PixelType pixelType, byte[] data)
    {
        GL.BindTexture(TextureTarget.Texture2d, texture);
        GL.TexSubImage2D(TextureTarget.Texture2d, 0, 0, 0, _worldX, _worldY, pixelFormat, pixelType, data);
    }

    public void UploadBuffer(int buffer, int size, byte[] data, int bufferOffset = 0, int dataOffset = 0)
    {
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, buffer);
        ReadOnlySpan<byte> span = data.AsSpan(dataOffset, size);
        GL.BufferSubData(BufferTarget.ShaderStorageBuffer, (IntPtr)bufferOffset, size, span);
    }

    public void UploadBuffer(int buffer, int size, uint[] data, int bufferOffset = 0, int dataOffset = 0)
    {
        GL.BindBuffer(BufferTarget.ShaderStorageBuffer, buffer);
        ReadOnlySpan<uint> span = data.AsSpan(dataOffset, size / sizeof(uint));
        GL.BufferSubData(BufferTarget.ShaderStorageBuffer, (IntPtr)bufferOffset, size, span);
    }

    public void BindTexture(int program, TextureUnit unit, int texture, string name)
    {
        GL.ActiveTexture(unit);
        GL.BindTexture(TextureTarget.Texture2d, texture);
        int location = GL.GetUniformLocation(program, name);
        if (location != -1)
            GL.Uniform1i(location, (int)unit - (int)TextureUnit.Texture0);
    }

    public void BindUniform(int program, string name, float value1, float value2)
    {
        int location = GL.GetUniformLocation(program, name);
        if (location != -1)
            GL.Uniform2f(location, value1, value2);
    }

    public void BindUniform(int program, string name, uint value)
    {
        int location = GL.GetUniformLocation(program, name);
        if (location != -1)
            GL.Uniform1ui(location, value);
    }
}
