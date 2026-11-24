import { Transform } from 'class-transformer';
import {
  IsEnum,
  IsISO8601,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  Validate,
  ValidatorConstraint,
} from 'class-validator';
import type {
  ValidationArguments,
  ValidatorConstraintInterface,
} from 'class-validator';
import { TaskPriority } from '../../generated/prisma/enums.js';

@ValidatorConstraint({ name: 'endAfterStart', async: false })
class EndAfterStartConstraint implements ValidatorConstraintInterface {
  validate(value: unknown, args: ValidationArguments): boolean {
    const start = (args.object as { startAt?: unknown }).startAt;
    if (typeof value !== 'string' || typeof start !== 'string') {
      return false;
    }
    const startTime = Date.parse(start);
    const endTime = Date.parse(value);
    return (
      Number.isFinite(startTime) &&
      Number.isFinite(endTime) &&
      endTime > startTime
    );
  }

  defaultMessage(): string {
    return 'endAt phải sau startAt.';
  }
}

// Chỉ mô tả đầu vào tạo công việc; chưa gọi repository hoặc database.
export class CreateTaskDto {
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString({ message: 'title phải là chuỗi.' })
  @IsNotEmpty({ message: 'title không được rỗng.' })
  title!: string;

  @IsOptional()
  @IsString({ message: 'description phải là chuỗi hoặc null.' })
  description?: string | null;

  @IsOptional()
  @IsString({ message: 'categoryId phải là chuỗi hoặc null.' })
  categoryId?: string | null;

  @IsString({ message: 'startAt phải là chuỗi ISO có múi giờ.' })
  @IsISO8601(
    { strict: true, strictSeparator: true },
    { message: 'startAt phải là thời điểm ISO hợp lệ.' },
  )
  @Matches(/(?:Z|[+-]\d{2}:\d{2})$/, {
    message: 'startAt phải có Z hoặc độ lệch múi giờ dạng +07:00.',
  })
  startAt!: string;

  @IsString({ message: 'endAt phải là chuỗi ISO có múi giờ.' })
  @IsISO8601(
    { strict: true, strictSeparator: true },
    { message: 'endAt phải là thời điểm ISO hợp lệ.' },
  )
  @Matches(/(?:Z|[+-]\d{2}:\d{2})$/, {
    message: 'endAt phải có Z hoặc độ lệch múi giờ dạng +07:00.',
  })
  @Validate(EndAfterStartConstraint)
  endAt!: string;

  @IsEnum(TaskPriority, { message: 'priority chỉ nhận low, medium hoặc high.' })
  priority: TaskPriority = TaskPriority.medium;
}
