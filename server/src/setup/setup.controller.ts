import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Request,
  Res,
  UseGuards,
} from '@nestjs/common';
import { IsNotEmpty, IsString } from 'class-validator';
import { Response, Request as ExpressRequest } from 'express';
import {
  ApiBearerAuth,
  ApiBody,
  ApiOperation,
  ApiResponse,
  ApiTags,
} from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AuthenticatedUser } from '../auth/strategies/jwt.strategy';
import { SetupService } from './setup.service';

class ExchangeTokenDto {
  @IsString()
  @IsNotEmpty()
  setupToken: string;
}

class RevokeTokenDto {
  @IsString()
  @IsNotEmpty()
  setupToken: string;
}

@ApiTags('Setup')
@Controller('setup')
export class SetupController {
  constructor(private readonly setupService: SetupService) {}

  /**
   * Download a personalised PowerShell setup script.
   *
   * Generates a single-use setup token, embeds it together with this server's
   * own URL into the PS1 template, and serves the result as a file download.
   *
   * The returned script, when executed on a Windows machine, will:
   * 1. Exchange the token for a short-lived JWT.
   * 2. Detect the machine UUID and hostname.
   * 3. Register the machine.
   * 4. Trigger and stream an installer build.
   * 5. Download and silently install the generated installer.
   * 6. Launch the application.
   */
  @UseGuards(JwtAuthGuard)
  @Get('download')
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Download personalised machine setup executable (.exe)' })
  @ApiResponse({
    status: 200,
    description: 'Self-contained Windows setup executable (machine-setup.exe).',
  })
  @ApiResponse({ status: 401, description: 'Unauthorized.' })
  async downloadScript(
    @Request() req: ExpressRequest & { user: AuthenticatedUser },
    @Res() res: Response,
  ): Promise<void> {
    const protocol = req.protocol || 'http';
    const host = req.get('host') ?? 'localhost:3000';
    const apiBaseUrl = `${protocol}://${host}`;

    const exeBuffer = await this.setupService.generateExe(
      req.user.userId,
      apiBaseUrl,
    );

    res.setHeader('Content-Type', 'application/vnd.microsoft.portable-executable');
    res.setHeader(
      'Content-Disposition',
      'attachment; filename="install-generator.exe"',
    );
    res.send(exeBuffer);
  }

  /**
   * Exchange a setup token for a short-lived JWT.
   *
   * Called by the setup script immediately after it starts.  The token is
   * single-use: it is marked `exchanged` upon success and cannot be reused.
   * Returns a JWT with a 2-hour expiry that is accepted by all protected
   * endpoints (generate, download, machines, etc.).
   */
  @Post('exchange')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Exchange a setup token for a short-lived JWT' })
  @ApiBody({ type: ExchangeTokenDto })
  @ApiResponse({
    status: 200,
    description: 'JWT access token (2 h expiry).',
    schema: {
      type: 'object',
      properties: {
        accessToken: { type: 'string' },
      },
    },
  })
  @ApiResponse({ status: 401, description: 'Token invalid, expired, or already used.' })
  async exchange(@Body() dto: ExchangeTokenDto) {
    return this.setupService.exchangeToken(dto.setupToken);
  }

  /**
   * Revoke a setup token.
   *
   * Called by the setup script's `finally` block on both success and failure.
   * Silently succeeds even if the token is unknown so the script never blocks
   * on revocation errors.
   */
  @Post('revoke')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Revoke a setup token (called by setup script on exit)' })
  @ApiBody({ type: RevokeTokenDto })
  @ApiResponse({ status: 204, description: 'Token revoked (or silently ignored if unknown).' })
  async revoke(@Body() dto: RevokeTokenDto): Promise<void> {
    await this.setupService.revokeToken(dto.setupToken);
  }
}
