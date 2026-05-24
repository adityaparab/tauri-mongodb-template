import {
  Injectable,
  InternalServerErrorException,
  NotFoundException,
  UnauthorizedException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { InjectModel } from '@nestjs/mongoose';
import { Model, Types } from 'mongoose';
import { randomUUID } from 'crypto';
import * as fs from 'fs';
import { User, UserDocument } from '../auth/schemas/user.schema';
import { SetupToken, SetupTokenDocument } from './setup-token.schema';

/** Setup tokens expire after 24 hours. */
const TOKEN_TTL_MS = 24 * 60 * 60 * 1000;

/** JWT issued by the exchange endpoint is valid for 2 hours. */
const EXCHANGE_JWT_TTL = '2h';

/**
 * 8-byte ASCII magic the .NET launcher looks for at the very end of its own
 * executable. Bump the trailing "01" if the footer layout ever changes so old
 * launchers refuse to read the new format.
 */
const FOOTER_MAGIC = Buffer.from('INVCFG01', 'ascii');

/**
 * Default location for the pre-built launcher executable inside the Docker
 * image.  The Dockerfile downloads it from the `launcher-latest` GitHub
 * release at build time.  Can be overridden via the `LAUNCHER_EXE_PATH`
 * environment variable for local development.
 */
const DEFAULT_LAUNCHER_PATH = '/app/setup-launcher.exe';

@Injectable()
export class SetupService {
  private readonly logger = new Logger(SetupService.name);
  private readonly launcherPath: string;
  /** Cached EXE bytes; loaded lazily on first request and re-used thereafter. */
  private launcherBytes: Buffer | null = null;

  constructor(
    @InjectModel(SetupToken.name)
    private readonly setupTokenModel: Model<SetupTokenDocument>,
    @InjectModel(User.name)
    private readonly userModel: Model<UserDocument>,
    private readonly jwtService: JwtService,
    private readonly config: ConfigService,
  ) {
    this.launcherPath = this.config.get<string>(
      'LAUNCHER_EXE_PATH',
      DEFAULT_LAUNCHER_PATH,
    );
  }

  // ---------------------------------------------------------------------------
  // Called by GET /setup/download (requires JWT)
  // ---------------------------------------------------------------------------

  /**
   * Generates a personalised Windows setup `.exe` for the requesting user.
   *
   * The base executable is a pre-built .NET 8 self-contained WinForms app
   * (the "launcher") that is downloaded into the Docker image at build time
   * from the `launcher-latest` GitHub release.  We append a small
   * configuration footer to the end of the EXE containing the user's API
   * URL and a single-use setup token; the launcher reads this footer from
   * its own file at startup.
   *
   * PE files tolerate trailing data after the last section, so Windows still
   * loads the resulting EXE normally — no compilation, signing or repacking
   * is required.
   */
  async generateExe(userId: string, apiBaseUrl: string): Promise<Buffer> {
    const launcher = await this.loadLauncherBytes();
    const setupToken = await this.issueSetupToken(userId);

    return this.appendFooter(launcher, {
      ApiBaseUrl: apiBaseUrl,
      SetupToken: setupToken,
    });
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /**
   * Loads the launcher executable from disk on first access and caches it
   * in memory.  Throws a clear error if the file is missing so we don't
   * silently serve a 0-byte download.
   */
  private async loadLauncherBytes(): Promise<Buffer> {
    if (this.launcherBytes) return this.launcherBytes;

    try {
      const bytes = await fs.promises.readFile(this.launcherPath);
      this.logger.log(
        `Loaded launcher EXE from ${this.launcherPath} (${bytes.length} bytes)`,
      );
      this.launcherBytes = bytes;
      return bytes;
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      throw new InternalServerErrorException(
        `Setup launcher executable is not available at "${this.launcherPath}". ` +
          `It must be downloaded into the image at build time from the ` +
          `"launcher-latest" GitHub release.  (${message})`,
      );
    }
  }

  /**
   * Inserts a fresh single-use setup-token row and returns the token string.
   */
  private async issueSetupToken(userId: string): Promise<string> {
    const token = randomUUID();
    const expiresAt = new Date(Date.now() + TOKEN_TTL_MS);

    await this.setupTokenModel.create({
      token,
      userId: new Types.ObjectId(userId),
      expiresAt,
    });

    return token;
  }

  /**
   * Appends the configuration footer to the launcher executable.
   *
   * Layout (all values are concatenated in order, no padding):
   *   [ UTF-8 JSON bytes                                  ]   (N bytes)
   *   [ uint32 LE = N                                     ]   (4 bytes)
   *   [ ASCII magic "INVCFG01"                            ]   (8 bytes)
   *
   * The launcher reads the trailing 12 bytes, validates the magic, then
   * seeks back `N` more bytes to recover the JSON.
   */
  private appendFooter(
    launcher: Buffer,
    config: { ApiBaseUrl: string; SetupToken: string },
  ): Buffer {
    const json = Buffer.from(JSON.stringify(config), 'utf8');
    const lengthField = Buffer.alloc(4);
    lengthField.writeUInt32LE(json.length, 0);
    return Buffer.concat([launcher, json, lengthField, FOOTER_MAGIC]);
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
        'Setup token has expired. Please download a new setup executable from the dashboard.',
      );
    }
    if (record.exchanged) {
      throw new UnauthorizedException(
        'Setup token has already been used. Each setup executable can only be run once.',
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
   * Called by the launcher's `finally` block regardless of success or
   * failure so that spent tokens are clearly marked in the database.
   * Silently ignores unknown tokens to avoid information leakage.
   */
  async revokeToken(setupToken: string): Promise<void> {
    await this.setupTokenModel
      .findOneAndUpdate({ token: setupToken }, { revoked: true })
      .exec();
  }
}
