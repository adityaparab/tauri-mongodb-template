import {
  Injectable,
  InternalServerErrorException,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { randomUUID } from 'crypto';
import { execFile } from 'child_process';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { User, UserDocument } from '../auth/schemas/user.schema';
import { SetupToken, SetupTokenDocument } from './setup-token.schema';

/** Setup tokens expire after 24 hours. */
const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;

/** JWT issued by the exchange endpoint is valid for 2 hours. */
const EXCHANGE_JWT_TTL = '2h';

/** Placeholder strings replaced in the template before serving. */
const PLACEHOLDER_URL   = '__API_BASE_URL__';
const PLACEHOLDER_TOKEN = '__SETUP_TOKEN__';

@Injectable()
export class SetupService {
  private readonly templateSource: string;

  constructor(
    @InjectModel(SetupToken.name)
    private readonly setupTokenModel: Model<SetupTokenDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {
    const templatePath = path.join(__dirname, 'setup.template.ps1');
    this.templateSource = fs.readFileSync(templatePath, 'utf8');
  }

  // ---------------------------------------------------------------------------
  // Called by GET /setup/download (requires JWT)
  // ---------------------------------------------------------------------------

  /**
   * Generates a setup-token, inserts it into the PS1 template, and returns
   * the populated script string ready to be streamed to the client.
   *
   * @param userId     - MongoDB ObjectId string of the requesting user.
   * @param apiBaseUrl - The server's own URL, extracted from the inbound request
   *                     so the script calls back to the same host it was served from.
   */
  /**
   * Generates a personalised `.exe` setup program.
   *
   * Internally calls `generateScript` to produce the PS1 source, then
   * compiles it with `ps12exe` (auto-installed on first use) and returns
   * the compiled Windows PE binary.  The output executable embeds its own
   * .NET host — the target machine only needs .NET Framework 4.x (built
   * into Windows 10+).  PowerShell does NOT need to be in PATH.
   */
  async generateExe(userId: string, apiBaseUrl: string): Promise<Buffer> {
    const ps1 = await this.generateScript(userId, apiBaseUrl);
    return this.compileToExe(ps1);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /**
   * Compiles a PS1 script string to a Windows PE executable using ps12exe.
   *
   * On first invocation the module is downloaded from the PowerShell Gallery
   * (~4 MB, cached afterwards). Subsequent calls take ~3-5 s.
   *
   * Works on Windows (powershell.exe) and Linux/macOS (pwsh).
   */
  /**
   * Reads a file with exponential back-off retries.
   *
   * On Windows, newly-written executables are often locked briefly by
   * Defender / AV scanners (EPERM / EBUSY) right after the writing process
   * exits.  We retry up to 8 times (max ~8 s total) before giving up.
   */
  private async readWithRetry(filePath: string, maxAttempts = 8): Promise<Buffer> {
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await fs.promises.readFile(filePath);
      } catch (err: any) {
        const retryable = err.code === 'EPERM' || err.code === 'EBUSY' || err.code === 'EACCES';
        if (!retryable || attempt === maxAttempts - 1) throw err;
        await new Promise((resolve) => setTimeout(resolve, 250 * (attempt + 1)));
      }
    }
    // unreachable, but keeps TS happy
    return fs.promises.readFile(filePath);
  }

  private async compileToExe(ps1Content: string): Promise<Buffer> {
    const tmpDir = os.tmpdir();
    const uid = randomUUID();
    const ps1Path = path.join(tmpDir, `machine-setup-${uid}.ps1`);
    const exePath = path.join(tmpDir, `machine-setup-${uid}.exe`);
    const compileScriptPath = path.join(tmpDir, `compile-${uid}.ps1`);

    // Build a helper script so we avoid any quoting issues with -Command.
    // $ErrorActionPreference = 'Stop' ensures any failure propagates to the
    // process exit code so execFile can catch it.
    // ps12exe is the PowerShell 7+ / cross-platform successor to ps2exe;
    // it uses .NET Roslyn directly and never calls powershell.exe, so it
    // works on Railway (Linux) as well as Windows.
    const compileScript = [
      `$ErrorActionPreference = 'Stop'`,
      // Ensure the NuGet package provider exists (required by Install-Module).
      `if (-not (Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue)) {`,
      `  Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser | Out-Null`,
      `}`,
      // Trust PSGallery so Install-Module never prompts for confirmation.
      `Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue`,
      // Install ps12exe only if the command is not yet available.
      `if (-not (Get-Command ps12exe -ErrorAction SilentlyContinue)) {`,
      `  Install-Module ps12exe -Scope CurrentUser -Force -AllowClobber | Out-Null`,
      `}`,
      `Import-Module ps12exe`,
      // ps12exe writes coloured status lines; in a headless Docker/Railway
      // environment the console colours are -1 (no TTY) which causes
      // "Cannot process the color because -1 is not a valid color".
      // Pre-set them to safe values before invoking the compiler.
      `try { if ([int]$Host.UI.RawUI.BackgroundColor -lt 0) { $Host.UI.RawUI.BackgroundColor = 'Black' } } catch {}`,
      `try { if ([int]$Host.UI.RawUI.ForegroundColor -lt 0) { $Host.UI.RawUI.ForegroundColor = 'Gray'  } } catch {}`,
      `ps12exe -inputFile '${ps1Path}' -outputFile '${exePath}' -noConsole`,
    ].join('\n');

    try {
      // The template is intentionally pure ASCII (no BOM, no multibyte chars)
      // so that ps12exe's preprocessor on Linux cannot misinterpret encoding.
      await fs.promises.writeFile(ps1Path, ps1Content, 'utf8');
      await fs.promises.writeFile(compileScriptPath, compileScript, 'utf8');

      const psExe = process.platform === 'win32' ? 'powershell.exe' : 'pwsh';

      await new Promise<void>((resolve, reject) => {
        execFile(
          psExe,
          [
            '-NonInteractive',
            '-NoProfile',
            '-ExecutionPolicy', 'Bypass',
            '-File', compileScriptPath,
          ],
          { timeout: 180_000 },
          (err, stdout, stderr) => {
            if (err) {
              reject(
                new InternalServerErrorException(
                  `ps12exe compilation failed: ${stderr || stdout || err.message}`,
                ),
              );
              return;
            }
            // ps12exe can exit 0 yet produce no output file on a script error.
            if (!fs.existsSync(exePath)) {
              reject(
                new InternalServerErrorException(
                  `ps12exe exited without error but produced no executable.\nstdout: ${stdout}\nstderr: ${stderr}`,
                ),
              );
              return;
            }
            resolve();
          },
        );
      });

      return await this.readWithRetry(exePath);
    } finally {
      await Promise.allSettled([
        fs.promises.unlink(ps1Path).catch(() => {}),
        fs.promises.unlink(exePath).catch(() => {}),
        fs.promises.unlink(compileScriptPath).catch(() => {}),
      ]);
    }
  }

  async generateScript(userId: string, apiBaseUrl: string): Promise<string> {
    const token = randomUUID();
    const expiresAt = new Date(Date.now() + TOKEN_TTL_MS);

    await this.setupTokenModel.create({
      token,
      userId: new Types.ObjectId(userId),
      expiresAt,
    });

    return this.templateSource
      .replace(PLACEHOLDER_URL, apiBaseUrl)
      .replace(PLACEHOLDER_TOKEN, token);
  }

  // ---------------------------------------------------------------------------
  // Called by POST /setup/exchange (no JWT required — token IS the credential)
  // ---------------------------------------------------------------------------

  /**
   * Validates a setup token and exchanges it for a short-lived JWT.
   *
   * The token is marked as `exchanged` immediately so it cannot be replayed.
   * The returned JWT inherits the same payload shape as the regular auth JWT
   * so all existing guards work without modification.
   *
   * @throws UnauthorizedException for any validation failure (expired, used, etc.)
   */
  async exchangeToken(setupToken: string): Promise<{ accessToken: string }> {
    const record = await this.setupTokenModel
      .findOne({ token: setupToken })
      .exec();

    if (!record) {
      throw new UnauthorizedException('Invalid setup token.');
    }
    if (record.expiresAt < new Date()) {
      throw new UnauthorizedException(
        'Setup token has expired. Please download a new setup script from the dashboard.',
      );
    }
    if (record.exchanged) {
      throw new UnauthorizedException(
        'Setup token has already been used. Each setup script can only be run once.',
      );
    }
    if (record.revoked) {
      throw new UnauthorizedException('Setup token has been revoked.');
    }

    // Mark as exchanged before issuing the JWT to prevent replay attacks.
    await this.setupTokenModel
      .findByIdAndUpdate(record._id, { exchanged: true })
      .exec();

    const user = await this.userModel.findById(record.userId).exec();
    if (!user) {
      throw new NotFoundException('Associated user account no longer exists.');
    }

    const payload = {
      sub: (user._id as { toString(): string }).toString(),
      username: user.username,
      email: user.email,
    };

    const accessToken = this.jwtService.sign(payload, {
      expiresIn: EXCHANGE_JWT_TTL,
      secret: this.config.get<string>('JWT_SECRET', 'changeme-jwt-secret'),
    });

    return { accessToken };
  }

  // ---------------------------------------------------------------------------
  // Called by POST /setup/revoke (no JWT required)
  // ---------------------------------------------------------------------------

  /**
   * Marks a setup token as revoked.
   *
   * Called by the setup script's `finally` block regardless of success or
   * failure so that spent tokens are clearly marked in the database.
   * Silently ignores unknown tokens to avoid information leakage.
   */
  async revokeToken(setupToken: string): Promise<void> {
    await this.setupTokenModel
      .findOneAndUpdate({ token: setupToken }, { revoked: true })
      .exec();
  }
}
