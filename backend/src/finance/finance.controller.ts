import {
  Body,
  Controller,
  Delete,
  Get,
  Headers,
  Inject,
  Param,
  Post,
  Put,
  Query,
} from '@nestjs/common';
import { FinanceService } from './finance.service.js';
@Controller('finance')
export class FinanceController {
  constructor(
    @Inject(FinanceService) private readonly finance: FinanceService,
  ) {}
  @Get('overview') overview(
    @Query('start') start: unknown,
    @Query('end') end: unknown,
  ) {
    return this.finance.overview(start, end);
  }
  @Get('jars') jars() {
    return this.finance.jars();
  }
  @Get('expense-sources') sources() {
    return this.finance.sources();
  }
  @Post('expenses') expense(
    @Body() b: Record<string, unknown>,
    @Headers('idempotency-key') k: unknown,
  ) {
    return this.finance.expense(b, k);
  }
  @Post('jars') addJar(
    @Body() b: Record<string, unknown>,
    @Headers('idempotency-key') k: unknown,
  ) {
    return this.finance.addJar(b, k);
  }
  @Put('jars/ratios') ratios(
    @Body() b: Record<string, unknown>,
    @Headers('idempotency-key') k: unknown,
  ) {
    return this.finance.ratios(b, k);
  }
  @Delete('jars/:id') deleteJar(
    @Param('id') id: string,
    @Body() b: Record<string, unknown>,
    @Headers('idempotency-key') k: unknown,
  ) {
    return this.finance.deleteJar(id, b, k);
  }
  @Post('allocations') allocate(
    @Body() b: Record<string, unknown>,
    @Headers('idempotency-key') k: unknown,
  ) {
    return this.finance.allocate(b, k);
  }
}
