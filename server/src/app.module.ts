import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { BuildModule } from './build/build.module';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health.controller';

/**
 * Root application module.
 *
 * Configures:
 * - **MongoDB** connection via `MONGODB_URI` environment variable.
 *   Example: `mongodb://user:pass@host:27017/inventory`
 *   Defaults to `mongodb://localhost:27017/inventory` for local development.
 * - **AuthModule**  — user registration, login, JWT issuance.
 * - **BuildModule** — installer build trigger (SSE) and download endpoints.
 */
@Module({
  imports: [
    MongooseModule.forRoot(
      process.env.MONGODB_URI ?? 'mongodb://localhost:27017/inventory',
    ),
    AuthModule,
    BuildModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
