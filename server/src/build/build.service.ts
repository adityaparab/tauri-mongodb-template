import { Injectable, ConflictException } from '@nestjs/common';
import { Observable } from 'rxjs';
import { spawn } from 'child_process';
import * as path from 'path';

@Injectable()
export class BuildService {
  private isBuildRunning = false;

  // /app/server/dist/build  →  ../../..  →  /app  (project root in container)
  private readonly projectRoot = path.resolve(__dirname, '../../..');

  build(uuid: string): Observable<{ data: Record<string, string> }> {
    if (this.isBuildRunning) {
      throw new ConflictException(
        'A build is already in progress. Please try again later.',
      );
    }

    return new Observable((subscriber) => {
      this.isBuildRunning = true;

      const scriptPath = path.join(this.projectRoot, 'build-installer.ps1');

      const proc = spawn(
        'pwsh',
        ['-NonInteractive', '-NoProfile', '-File', scriptPath, '-UUID', uuid],
        { cwd: this.projectRoot },
      );

      const emit = (type: string, message: string) => {
        subscriber.next({ data: { type, message } });
      };

      const handleOutput = (chunk: Buffer, isStderr: boolean) => {
        const lines = chunk
          .toString()
          .split(/\r?\n/)
          .filter((l) => l.trim().length > 0);
        for (const line of lines) {
          // Forward stderr as a log line; the build script writes progress to
          // stdout and errors to stderr; both are informational here.
          emit(isStderr ? 'stderr' : 'log', line);
        }
      };

      proc.stdout.on('data', (chunk: Buffer) => handleOutput(chunk, false));
      proc.stderr.on('data', (chunk: Buffer) => handleOutput(chunk, true));

      proc.on('close', (code) => {
        this.isBuildRunning = false;
        if (code === 0) {
          emit(
            'complete',
            `Installer created successfully for machine UUID: ${uuid}`,
          );
        } else {
          emit('error', `Build failed with exit code ${code}`);
        }
        subscriber.complete();
      });

      proc.on('error', (err) => {
        this.isBuildRunning = false;
        emit('error', `Failed to start build process: ${err.message}`);
        subscriber.complete();
      });

      // Clean up if the SSE client disconnects before the build finishes.
      return () => {
        if (!proc.killed) {
          proc.kill('SIGTERM');
        }
        this.isBuildRunning = false;
      };
    });
  }
}
