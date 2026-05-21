import { Prop, Schema, SchemaFactory } from '@nestjs/mongoose';
import { Document, Types } from 'mongoose';

/**
 * Mongoose document type for the BuildRecord entity.
 */
export type BuildRecordDocument = BuildRecord & Document;

/**
 * Possible lifecycle states for a build job.
 *
 * - `building`  — the build process has been started and is currently running
 * - `completed` — the build finished successfully and the output file is available
 * - `failed`    — the build process exited with a non-zero code or encountered an error
 */
export enum BuildStatus {
  BUILDING = 'building',
  COMPLETED = 'completed',
  FAILED = 'failed',
}

/**
 * Persists metadata about a machine-specific installer build.
 *
 * Each record ties a machine UUID to a specific user and tracks the lifecycle
 * of a single build invocation. On successful completion the record stores the
 * absolute path of the generated installer on the server's file system, allowing
 * the download endpoint to locate and stream the file.
 *
 * DB design rationale:
 * - `uuid + userId` compound index enables O(1) lookup for the download endpoint.
 * - The `outputPath` / `outputFilename` columns are nullable so the record can be
 *   created at the *start* of a build (giving clients visibility into in-progress
 *   jobs) and populated atomically on success.
 * - `completedAt` is separate from `createdAt` (added by timestamps) so callers
 *   can measure build duration.
 *
 * File storage convention:
 *   `<server-root>/builds/<username>/inventory_<uuid>_setup.exe`
 */
@Schema({ timestamps: { createdAt: true, updatedAt: false } })
export class BuildRecord {
  /** The target machine UUID that was locked into the installer. */
  @Prop({ required: true, index: true })
  uuid: string;

  /** Reference to the User who triggered the build. */
  @Prop({ type: Types.ObjectId, ref: 'User', required: true, index: true })
  userId: Types.ObjectId;

  /** Current lifecycle state of the build. */
  @Prop({ enum: BuildStatus, default: BuildStatus.BUILDING })
  status: BuildStatus;

  /**
   * Absolute path on the server's file system where the generated installer
   * was stored after a successful build.
   * Null while the build is in progress or if the build failed.
   */
  @Prop({ default: null })
  outputPath: string | null;

  /** Basename of the installer file (e.g. `inventory_<uuid>_setup.exe`). */
  @Prop({ default: null })
  outputFilename: string | null;

  /** Timestamp at which the build finished (success or failure). */
  @Prop({ default: null })
  completedAt: Date | null;
}

export const BuildRecordSchema = SchemaFactory.createForClass(BuildRecord);

// Compound index for the most common query pattern: look up a build by its
// owner and machine UUID (used by both the download and status endpoints).
BuildRecordSchema.index({ userId: 1, uuid: 1 });
