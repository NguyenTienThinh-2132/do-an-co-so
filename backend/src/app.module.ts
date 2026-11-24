import { FinanceModule } from './finance/finance.module.js';
import { TasksModule } from './tasks/tasks.module.js';
import { PrismaModule } from './prisma/prisma.module.js';
import { Module } from '@nestjs/common';
import { AppController } from './app.controller.js';
import { AppService } from './app.service.js';

@Module({
  imports: [PrismaModule, TasksModule, FinanceModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
