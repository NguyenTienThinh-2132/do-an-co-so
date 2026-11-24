import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsString,
  Matches,
  Validate,
  ValidateIf,
  ValidatorConstraint,
} from 'class-validator';
import type {
  ValidationArguments,
  ValidatorConstraintInterface,
} from 'class-validator';
import { TaskPriority, TaskStatus } from '../../generated/prisma/enums.js';

@ValidatorConstraint({ name: 'queryEndAfterStart', async: false })
class QueryEndAfterStart implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments): boolean {
    const start = (args.object as { start?: unknown }).start;
    if (typeof start !== 'string' || typeof value !== 'string') return false;
    const a = Date.parse(start);
    const b = Date.parse(value);
    return Number.isFinite(a) && Number.isFinite(b) && b > a;
  }
  defaultMessage(): string {
    return 'end phải sau start.';
  }
}

export class ListTasksQueryDto {
  @IsString()
  @IsISO8601({ strict: true, strictSeparator: true })
  @Matches(/(?:Z|[+-]\d{2}:\d{2})$/, { message: 'start phải có múi giờ.' })
  start!: string;

  @IsString()
  @IsISO8601({ strict: true, strictSeparator: true })
  @Matches(/(?:Z|[+-]\d{2}:\d{2})$/, { message: 'end phải có múi giờ.' })
  @Validate(QueryEndAfterStart)
  end!: string;

  @ValidateIf((_object, value: unknown) => value !== undefined)
  @IsEnum(TaskStatus)
  status?: TaskStatus;

  @ValidateIf((_object, value: unknown) => value !== undefined)
  @IsEnum(TaskPriority)
  priority?: TaskPriority;

  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  searchText = '';
}
