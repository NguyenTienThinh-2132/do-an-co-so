import { Prisma } from '../generated/prisma/client.js';
import type { ListTasksQueryDto } from './dto/list-tasks-query.dto.js';
import {
  Inject,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import type { Task } from '../generated/prisma/client.js';
import { TaskStatus } from '../generated/prisma/enums.js';
import { PrismaService } from '../prisma/prisma.service.js';
import type { CreateTaskDto } from './dto/create-task.dto.js';

@Injectable()
export class TasksService {
  constructor(@Inject(PrismaService) private readonly prisma: PrismaService) {}

  async create(dto: CreateTaskDto): Promise<Task> {
    try {
      return await this.prisma.client.task.create({
        data: {
          title: dto.title,
          description: dto.description ?? null,
          categoryId: dto.categoryId ?? null,
          startAt: new Date(dto.startAt),
          endAt: new Date(dto.endAt),
          priority: dto.priority,
          status: TaskStatus.pending,
        },
      });
    } catch {
      // Không trả lỗi SQL hoặc credentials cho client.
      throw new ServiceUnavailableException(
        'Chưa thể lưu công việc. Vui lòng thử lại sau.',
      );
    }
  }

  async getById(id: string): Promise<Task> {
    let task: Task | null;
    try {
      task = await this.prisma.client.task.findUnique({ where: { id } });
    } catch {
      throw new ServiceUnavailableException(
        'Chưa thể đọc công việc. Vui lòng thử lại sau.',
      );
    }

    // Đặt ngoài catch để lỗi không tồn tại giữ đúng HTTP 404.
    if (!task) {
      throw new NotFoundException('Không tìm thấy công việc.');
    }
    return task;
  }

  async list(query: ListTasksQueryDto): Promise<Task[]> {
    // Prisma contains dùng LIKE: escape để %, _ và \ là ký tự tìm kiếm thật.
    const searchText = query.searchText.replace(/[\\%_]/g, '\\$&');
    try {
      return await this.prisma.client.task.findMany({
        where: {
          startAt: { lt: new Date(query.end) },
          endAt: { gt: new Date(query.start) },
          ...(query.status !== undefined ? { status: query.status } : {}),
          ...(query.priority !== undefined ? { priority: query.priority } : {}),
          ...(searchText
            ? { title: { contains: searchText, mode: 'insensitive' } }
            : {}),
        },
        orderBy: [{ startAt: 'asc' }, { id: 'asc' }],
      });
    } catch {
      throw new ServiceUnavailableException(
        'Chưa thể đọc danh sách công việc.',
      );
    }
  }

  async update(id: string, dto: CreateTaskDto): Promise<Task> {
    try {
      return await this.prisma.client.task.update({
        where: { id },
        data: {
          title: dto.title,
          description: dto.description ?? null,
          categoryId: dto.categoryId ?? null,
          startAt: new Date(dto.startAt),
          endAt: new Date(dto.endAt),
          priority: dto.priority,
          version: { increment: 1 },
        },
      });
    } catch (error) {
      return this.throwMutationFailure(error);
    }
  }

  async setStatus(id: string, status: TaskStatus): Promise<Task> {
    try {
      return await this.prisma.client.task.update({
        where: { id },
        data: { status, version: { increment: 1 } },
      });
    } catch (error) {
      return this.throwMutationFailure(error);
    }
  }

  async delete(id: string): Promise<void> {
    try {
      await this.prisma.client.$transaction(async (tx) => {
        // adapter-pg normalizes timestamptz as UTC; scope the setting to this tx.
        await tx.$executeRaw`SET LOCAL TIME ZONE 'UTC'`;
        // DELETE returns the row locked by PostgreSQL, including its latest version.
        const deleted = await tx.task.delete({ where: { id } });
        // A failure here rolls back the deletion too. Never overwrite an old marker.
        await tx.taskTombstone.create({
          data: { taskId: deleted.id, version: deleted.version + 1 },
        });
      });
    } catch (error) {
      this.throwMutationFailure(error);
    }
  }

  private throwMutationFailure(error: unknown): never {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2025'
    ) {
      throw new NotFoundException('Không tìm thấy công việc.');
    }
    throw new ServiceUnavailableException(
      'Chưa thể thay đổi công việc. Vui lòng thử lại sau.',
    );
  }
}
