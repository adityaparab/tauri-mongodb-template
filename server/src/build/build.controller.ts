import {
  Controller,
  Get,
  Param,
  BadRequestException,
  Sse,
} from '@nestjs/common';
import { Observable } from 'rxjs';
import { BuildService } from './build.service';

const UUID_PATTERN =
  /^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$/;

@Controller()
export class BuildController {
  constructor(private readonly buildService: BuildService) {}

  /**
   * GET /generate/:uuid
   *
   * Streams build output as Server-Sent Events.
   * Each event has the JSON shape:
   *   { type: 'log',      message: string }  — a line of stdout/stderr
   *   { type: 'complete', message: string }  — build finished successfully
   *   { type: 'error',    message: string }  — build failed
   *
   * Responds 400 if the UUID format is invalid.
   * Responds 409 if another build is already running.
   */
  @Sse('generate/:uuid')
  generate(
    @Param('uuid') uuid: string,
  ): Observable<{ data: Record<string, string> }> {
    if (!UUID_PATTERN.test(uuid)) {
      throw new BadRequestException(
        'Invalid UUID format. Expected: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX',
      );
    }
    return this.buildService.build(uuid);
  }
}
