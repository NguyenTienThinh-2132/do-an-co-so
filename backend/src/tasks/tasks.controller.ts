import { Delete, HttpCode, Patch, Put, Query } from '@nestjs/common';
import { ListTasksQueryDto } from './dto/list-tasks-query.dto.js';
import { SetTaskStatusDto } from './dto/set-task-status.dto.js';
import {
  ListTasksValidationPipe,
  SetTaskStatusValidationPipe,
} from './validation/tasks-management.pipes.js';
import {
  Body,
  Controller,
  Get,
  Inject,
  Param,
  ParseUUIDPipe,
  Post,
} from '@nestjs/common';
import { CreateTaskDto } from './dto/create-task.dto.js';
import { TasksService } from './tasks.service.js';
import { CreateTaskValidationPipe } from './validation/create-task-validation.pipe.js';

@Controller('tasks')
export class TasksController {
  constructor(@Inject(TasksService) private readonly tasks: TasksService) {}

  @Post()
  create(@Body(new CreateTaskValidationPipe()) dto: CreateTaskDto) {
    return this.tasks.create(dto);
  }

  @Get(':taskId')
  getById(@Param('taskId', new ParseUUIDPipe()) taskId: string) {
    return this.tasks.getById(taskId);
  }

  @Get()
  list(@Query(new ListTasksValidationPipe()) query: ListTasksQueryDto) {
    return this.tasks.list(query);
  }

  // PUT thay toàn bộ nội dung, dùng lại validation của TaskDraft/create.
  @Put(':taskId')
  update(
    @Param('taskId', new ParseUUIDPipe()) taskId: string,
    @Body(new CreateTaskValidationPipe()) dto: CreateTaskDto,
  ) {
    return this.tasks.update(taskId, dto);
  }

  @Patch(':taskId/status')
  setStatus(
    @Param('taskId', new ParseUUIDPipe()) taskId: string,
    @Body(new SetTaskStatusValidationPipe()) dto: SetTaskStatusDto,
  ) {
    return this.tasks.setStatus(taskId, dto.status);
  }

  @Delete(':taskId')
  @HttpCode(204)
  async delete(
    @Param('taskId', new ParseUUIDPipe()) taskId: string,
  ): Promise<void> {
    await this.tasks.delete(taskId);
  }
}
