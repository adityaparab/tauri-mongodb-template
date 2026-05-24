using System.Windows.Forms;

namespace Inventory.Launcher;

internal static class Program
{
    [STAThread]
    private static int Main()
    {
        ApplicationConfiguration.Initialize();

        LauncherConfig config;
        try
        {
            config = LauncherConfig.LoadFromSelf();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                ex.Message,
                "Inventory - Machine Setup",
                MessageBoxButtons.OK,
                MessageBoxIcon.Error);
            return 1;
        }

        var form = new SetupForm();
        // Run the form on the UI thread; kick off the workflow in the background
        // as soon as the window is shown so the user immediately sees progress.
        form.Shown += async (_, _) => await RunWorkflowAsync(form, config);
        Application.Run(form);
        return 0;
    }

    private static async Task RunWorkflowAsync(SetupForm form, LauncherConfig config)
    {
        using var client = new SetupClient(config);

        try
        {
            // 1. Authenticate
            form.SetStep(0, SetupForm.StepState.Running);
            form.SetStatus("Authenticating...");
            form.AddLog("-> Exchanging setup credentials with server...", SetupForm.LogKind.Info);
            await client.AuthenticateAsync();
            form.AddLog("   Authenticated successfully.", SetupForm.LogKind.Ok);
            form.SetStep(0, SetupForm.StepState.Done);
            form.SetProgress(1);

            // 2. Detect UUID
            form.SetStep(1, SetupForm.StepState.Running);
            form.SetStatus("Detecting machine UUID...");
            form.AddLog("-> Reading hardware UUID from WMI...", SetupForm.LogKind.Info);
            await client.DetectUuidAsync();
            form.AddLog($"   UUID: {client.MachineUuid}", SetupForm.LogKind.Ok);
            form.SetStep(1, SetupForm.StepState.Done);
            form.SetProgress(2);

            // 3. Detect hostname
            form.SetStep(2, SetupForm.StepState.Running);
            form.SetStatus("Detecting hostname...");
            form.AddLog("-> Reading computer name...", SetupForm.LogKind.Info);
            await client.DetectHostnameAsync();
            form.AddLog($"   Hostname: {client.Hostname}", SetupForm.LogKind.Ok);
            form.SetStep(2, SetupForm.StepState.Done);
            form.SetProgress(3);

            // 4. Register
            form.SetStep(3, SetupForm.StepState.Running);
            form.SetStatus("Registering machine...");
            form.AddLog("-> Registering machine with server...", SetupForm.LogKind.Info);
            await client.RegisterMachineAsync();
            form.AddLog($"   Machine registered: {client.MachineName}", SetupForm.LogKind.Ok);
            form.SetStep(3, SetupForm.StepState.Done);
            form.SetProgress(4);

            // Success summary
            form.AddLog("", SetupForm.LogKind.Normal);
            form.AddLog("==============================================", SetupForm.LogKind.Ok);
            form.AddLog("  Machine registered successfully!",            SetupForm.LogKind.Ok);
            form.AddLog("==============================================", SetupForm.LogKind.Ok);
            form.AddLog("", SetupForm.LogKind.Normal);
            form.AddLog($"  UUID:     {client.MachineUuid}", SetupForm.LogKind.Info);
            form.AddLog($"  Machine:  {client.MachineName}", SetupForm.LogKind.Info);
            form.AddLog("", SetupForm.LogKind.Normal);
            form.AddLog("  Next step:");
            form.AddLog("  Go to the dashboard in your browser and");
            form.AddLog("  download the installer for this machine:");
            form.AddLog("");
            form.AddLog($"  {config.ApiBaseUrl}", SetupForm.LogKind.Info);
            form.AddLog("");
            form.SetStatus("Registration complete. Visit the dashboard to download your installer.");
        }
        catch (SetupException sx)
        {
            MarkFailed(form);
            form.AddLog("", SetupForm.LogKind.Normal);
            form.AddLog("Setup failed: " + sx.Message, SetupForm.LogKind.Err);
            form.SetStatus("Setup failed. Review the log above, then close this window.");
        }
        catch (Exception ex)
        {
            MarkFailed(form);
            form.AddLog("", SetupForm.LogKind.Normal);
            form.AddLog("Unexpected error: " + ex.Message, SetupForm.LogKind.Err);
            form.SetStatus("Setup failed. Review the log above, then close this window.");
        }
        finally
        {
            await client.TryRevokeTokenAsync();
        }
    }

    private static void MarkFailed(SetupForm form)
    {
        // Mark the first non-Done step as failed so the user can see where it stopped.
        // (The currently-running step will already be highlighted as such.)
        // Simplest: try each step; if its label is still bold/white we know it was running.
        // Since we don't expose step state, just rely on the running step already being
        // visually distinct, and add a generic failure indication on the progress bar.
        form.SetProgress(0);
    }
}
