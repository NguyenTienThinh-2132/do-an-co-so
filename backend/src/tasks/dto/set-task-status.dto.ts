import { IsEnum } from 'class-validator';
import { TaskStatus } from '../../generated/prisma/enums.js';

export class SetTaskStatusDto {
  @IsEnum(TaskStatus, {
    message: 'status chỉ nhận pending, inProgress hoặc completed.',
  })
  status!: TaskStatus;
}
