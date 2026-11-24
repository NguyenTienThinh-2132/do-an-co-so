import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module.js';
import { FinanceService } from './finance.service.js';
import { FinanceController } from './finance.controller.js';
@Module({
  imports: [PrismaModule],
  providers: [FinanceService],
  controllers: [FinanceController],
})
export class FinanceModule {}
