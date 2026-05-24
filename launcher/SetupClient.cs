using System.Management;
using System.Net.Http;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace Inventory.Launcher;

/// <summary>
/// Thin HTTP/WMI client that performs the 4-step setup flow:
///
///   1. Exchange the embedded setup token for a short-lived JWT.
///   2. Detect the machine's hardware UUID via WMI.
///   3. Detect the hostname.
///   4. Register the machine with the server.
///
/// All steps throw <see cref="SetupException"/> on user-facing failures so
/// the UI can show a clean message without a stack trace.
/// </summary>
public sealed class SetupClient : IDisposable
{
    private readonly HttpClient _http;
    private readonly LauncherConfig _config;
    private string? _accessToken;

    public string? MachineUuid { get; private set; }
    public string? Hostname    { get; private set; }
    public string? MachineName { get; private set; }

    public SetupClient(LauncherConfig config)
    {
        _config = config;
        _http = new HttpClient
        {
            BaseAddress = new Uri(config.ApiBaseUrl.TrimEnd('/') + "/"),
            Timeout     = TimeSpan.FromSeconds(30),
        };
        _http.DefaultRequestHeaders.UserAgent.ParseAdd("InventoryMachineSetup/1.0");
    }

    // -------------------------------------------------------------------------
    // Step 1: Exchange setup token for a short-lived JWT.
    // -------------------------------------------------------------------------
    public async Task AuthenticateAsync(CancellationToken ct = default)
    {
        var resp = await PostJsonAsync("setup/exchange",
            new { setupToken = _config.SetupToken }, requireAuth: false, ct);

        var token = resp.GetProperty("accessToken").GetString();
        if (string.IsNullOrEmpty(token))
        {
            throw new SetupException("Authentication succeeded but no token was returned.");
        }
        _accessToken = token;
    }

    // -------------------------------------------------------------------------
    // Step 2: Detect machine UUID via WMI.
    // -------------------------------------------------------------------------
    public Task DetectUuidAsync(CancellationToken ct = default)
    {
        return Task.Run(() =>
        {
            string? uuid = null;
            try
            {
                using var searcher = new ManagementObjectSearcher(
                    "SELECT UUID FROM Win32_ComputerSystemProduct");
                foreach (ManagementObject obj in searcher.Get())
                {
                    uuid = obj["UUID"]?.ToString();
                    obj.Dispose();
                    if (!string.IsNullOrWhiteSpace(uuid)) break;
                }
            }
            catch (Exception ex)
            {
                throw new SetupException("Unable to read machine UUID via WMI.", ex);
            }

            uuid = uuid?.Trim().ToUpperInvariant();

            if (string.IsNullOrEmpty(uuid)
                || uuid == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF"
                || uuid == "00000000-0000-0000-0000-000000000000")
            {
                throw new SetupException(
                    $"Machine UUID could not be reliably determined (value: '{uuid ?? "<null>"}').");
            }

            MachineUuid = uuid;
        }, ct);
    }

    // -------------------------------------------------------------------------
    // Step 3: Detect hostname.
    // -------------------------------------------------------------------------
    public Task DetectHostnameAsync(CancellationToken ct = default)
    {
        return Task.Run(() =>
        {
            var hostname = Environment.MachineName;
            if (string.IsNullOrWhiteSpace(hostname))
            {
                throw new SetupException("Unable to read the computer name.");
            }
            Hostname    = hostname;
            MachineName = $"{hostname}'s computer";
        }, ct);
    }

    // -------------------------------------------------------------------------
    // Step 4: Register the machine.
    // -------------------------------------------------------------------------
    public async Task RegisterMachineAsync(CancellationToken ct = default)
    {
        if (string.IsNullOrEmpty(MachineUuid) || string.IsNullOrEmpty(MachineName))
        {
            throw new InvalidOperationException(
                "DetectUuidAsync and DetectHostnameAsync must run before RegisterMachineAsync.");
        }
        await PostJsonAsync("machines",
            new { uuid = MachineUuid, name = MachineName }, requireAuth: true, ct);
    }

    // -------------------------------------------------------------------------
    // Best-effort: revoke the setup token so it cannot be re-used.
    // Called from a finally block; never throws to the caller.
    // -------------------------------------------------------------------------
    public async Task TryRevokeTokenAsync(CancellationToken ct = default)
    {
        try
        {
            await PostJsonAsync("setup/revoke",
                new { setupToken = _config.SetupToken }, requireAuth: false, ct);
        }
        catch
        {
            // Intentionally swallowed.
        }
    }

    // -------------------------------------------------------------------------
    private async Task<JsonElement> PostJsonAsync(
        string path, object body, bool requireAuth, CancellationToken ct)
    {
        using var req = new HttpRequestMessage(HttpMethod.Post, path)
        {
            Content = JsonContent.Create(body),
        };
        if (requireAuth)
        {
            if (string.IsNullOrEmpty(_accessToken))
            {
                throw new InvalidOperationException(
                    "AuthenticateAsync must run before authenticated requests.");
            }
            req.Headers.Authorization =
                new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _accessToken);
        }

        HttpResponseMessage resp;
        try
        {
            resp = await _http.SendAsync(req, ct);
        }
        catch (HttpRequestException ex)
        {
            throw new SetupException(
                $"Could not reach the server at {_http.BaseAddress}. " +
                $"Check your internet connection and try again.\r\n\r\nDetails: {ex.Message}",
                ex);
        }

        var responseBody = await resp.Content.ReadAsStringAsync(ct);

        if (!resp.IsSuccessStatusCode)
        {
            var message = ExtractServerMessage(responseBody) ?? $"HTTP {(int)resp.StatusCode}";
            throw new SetupException($"Request to /{path} failed: {message}");
        }

        if (string.IsNullOrWhiteSpace(responseBody))
        {
            return default;
        }

        try
        {
            return JsonDocument.Parse(responseBody).RootElement.Clone();
        }
        catch (JsonException)
        {
            return default;
        }
    }

    private static string? ExtractServerMessage(string body)
    {
        if (string.IsNullOrWhiteSpace(body)) return null;
        try
        {
            var root = JsonDocument.Parse(body).RootElement;
            if (root.TryGetProperty("message", out var msg))
            {
                return msg.ValueKind switch
                {
                    JsonValueKind.String => msg.GetString(),
                    JsonValueKind.Array  => string.Join("; ",
                        msg.EnumerateArray().Select(e => e.ToString())),
                    _ => msg.ToString(),
                };
            }
        }
        catch (JsonException) { /* ignore — fall through */ }
        return body.Length > 300 ? body[..300] + "..." : body;
    }

    public void Dispose() => _http.Dispose();
}

public sealed class SetupException : Exception
{
    public SetupException(string message) : base(message) { }
    public SetupException(string message, Exception inner) : base(message, inner) { }
}
