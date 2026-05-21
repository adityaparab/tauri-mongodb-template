import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // ---------------------------------------------------------------------------
  // Global validation — strips unknown fields and coerces types automatically.
  // ---------------------------------------------------------------------------
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,       // strip properties not declared in DTOs
      forbidNonWhitelisted: false,
      transform: true,       // auto-transform payloads to DTO class instances
    }),
  );

  // ---------------------------------------------------------------------------
  // Swagger / OpenAPI documentation
  // Available at: GET /api/docs
  // JSON spec at: GET /api/docs-json
  // ---------------------------------------------------------------------------
  const swaggerConfig = new DocumentBuilder()
    .setTitle('Inventory Build Server API')
    .setDescription(
      'REST + SSE API for generating and downloading machine-specific NSIS installers.\n\n' +
        '**Authentication flow:**\n' +
        '1. `POST /auth/register` — create an account (returns `accessToken`).\n' +
        '2. `POST /auth/login`    — authenticate (returns `accessToken`).\n' +
        '3. Click **Authorize** (lock icon) and enter `Bearer <accessToken>` to access protected endpoints.\n\n' +
        '**Build flow:**\n' +
        '1. `GET /generate/:uuid` — triggers the build; consumes the SSE stream until `type: "complete"`.\n' +
        '2. `GET /download/:uuid` — downloads the generated `.exe` installer.',
    )
    .setVersion('1.0')
    .addBearerAuth(
      {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
        description:
          'JWT access token obtained from POST /auth/login or POST /auth/register. ' +
          'Prefix with "Bearer " (e.g. "Bearer eyJhbGci...").',
        in: 'header',
      },
    )
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api/docs', app, document);

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  console.log(`Build server listening on port ${port}`);
  console.log(`Swagger UI: http://localhost:${port}/api/docs`);
}

bootstrap();
