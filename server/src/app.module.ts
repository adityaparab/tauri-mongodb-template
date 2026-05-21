import { Module } from '@nestjs/common';
import { BuildModule } from './build/build.module';
import { HealthController } from './health.controller';

@Module({
  imports: [BuildModule],
  controllers: [HealthController],
})
export class AppModule {}
