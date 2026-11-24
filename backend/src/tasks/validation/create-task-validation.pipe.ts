import { BadRequestException, ValidationPipe } from '@nestjs/common';
import type { ArgumentMetadata } from '@nestjs/common';
import { CreateTaskDto } from '../dto/create-task.dto.js';

// Chỉ dùng cho body tạo Task, chưa áp dụng global cho module khác.
export class CreateTaskValidationPipe extends ValidationPipe {
  constructor() {
    super({
      expectedType: CreateTaskDto,
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
      forbidUnknownValues: true,
      transformOptions: { enableImplicitConversion: false },
      validationError: { target: false, value: false },
    });
  }

  override async transform(
    value: unknown,
    metadata: ArgumentMetadata,
  ): Promise<CreateTaskDto> {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new BadRequestException('Body phải là một JSON object.');
    }
    return super.transform(value, metadata) as Promise<CreateTaskDto>;
  }
}
