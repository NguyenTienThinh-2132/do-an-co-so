import { BadRequestException, ValidationPipe } from '@nestjs/common';
import type { ArgumentMetadata, Type } from '@nestjs/common';
import { ListTasksQueryDto } from '../dto/list-tasks-query.dto.js';
import { SetTaskStatusDto } from '../dto/set-task-status.dto.js';

class ObjectValidationPipe extends ValidationPipe {
  constructor(expectedType: Type<unknown>) {
    super({
      expectedType,
      transform: true,
      whitelist: true,
      forbidNonWhitelisted: true,
      forbidUnknownValues: true,
      transformOptions: { enableImplicitConversion: false },
      validationError: { target: false, value: false },
    });
  }

  override async transform(value: unknown, metadata: ArgumentMetadata) {
    if (value === null || typeof value !== 'object' || Array.isArray(value)) {
      throw new BadRequestException('Đầu vào phải là object.');
    }
    return super.transform(value, metadata);
  }
}

export class ListTasksValidationPipe extends ObjectValidationPipe {
  constructor() {
    super(ListTasksQueryDto);
  }
}

export class SetTaskStatusValidationPipe extends ObjectValidationPipe {
  constructor() {
    super(SetTaskStatusDto);
  }
}
