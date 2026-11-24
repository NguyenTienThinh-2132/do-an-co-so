import {
  Injectable,
  Inject,
  BadRequestException,
  ConflictException,
  NotFoundException,
  HttpException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { PrismaService } from '../prisma/prisma.service.js';
import type { Prisma } from '../generated/prisma/client.js';
import {
  canonical,
  categories,
  date,
  money,
  revision,
  split,
  styles,
  text,
  uuid,
} from './finance.rules.js';

type Tx = Prisma.TransactionClient;
type Body = Record<string, unknown>;
const defaults = [
  ['necessities', 'Hũ Thiết yếu', 'Nhà ở, thực phẩm, sinh hoạt', 'home', 5500],
  [
    'long-term',
    'Tiết kiệm dài hạn',
    'Dành dụm cho những mục tiêu lớn',
    'savings',
    1000,
  ],
  [
    'education',
    'Giáo dục & Phát triển',
    'Đầu tư vào kiến thức và kỹ năng',
    'education',
    1000,
  ],
  [
    'enjoyment',
    'Hưởng thụ & Giải trí',
    'Du lịch, cà phê và điều bạn thích',
    'enjoyment',
    1000,
  ],
  [
    'financial-freedom',
    'Đầu tư Tự do tài chính',
    'Chuẩn bị cho tương lai của bạn',
    'investment',
    1000,
  ],
  [
    'giving',
    'Cho đi & Thiện nguyện',
    'Chia sẻ cùng gia đình và cộng đồng',
    'giving',
    500,
  ],
] as const;
function json(value: unknown): Prisma.InputJsonValue {
  return JSON.parse(
    JSON.stringify(value, (_, v: unknown) =>
      typeof v === 'bigint' ? v.toString() : v,
    ),
  ) as Prisma.InputJsonValue;
}

@Injectable()
export class FinanceService {
  readonly bookId = uuid(
    process.env.FINAI_FINANCE_BOOK_ID ?? '00000000-0000-4000-8000-000000000001',
  );
  constructor(@Inject(PrismaService) private readonly db: PrismaService) {}
  private ready?: Promise<void>;
  private async ensureBook() {
    if (!this.ready)
      this.ready = this.initialize().catch((e) => {
        this.ready = undefined;
        throw e;
      });
    return this.ready;
  }
  private async initialize() {
    try {
      await this.db.client.$transaction(async (tx) => {
        const existing = await tx.financeBook.findUnique({
          where: { id: this.bookId },
        });
        if (existing) return;
        await tx.financeBook.create({
          data: {
            id: this.bookId,
            jars: {
              create: defaults.map(
                ([defaultCode, title, subtitle, styleKey, allocationBps]) => ({
                  defaultCode,
                  title,
                  normalizedTitle: title.toLocaleLowerCase('vi'),
                  subtitle,
                  styleKey,
                  allocationBps,
                }),
              ),
            },
          },
        });
      });
    } catch (e) {
      if (!(
        e &&
        typeof e === 'object' &&
        'code' in e &&
        e.code === 'P2002' &&
        (await this.db.client.financeBook.findUnique({
          where: { id: this.bookId },
        }))
      ))
        throw e;
    }
  }
  private async snapshot(tx: Tx) {
    const book = await tx.financeBook.findUniqueOrThrow({
      where: { id: this.bookId },
    });
    const jars = await tx.financeJar.findMany({
      where: { bookId: this.bookId },
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
    const transactions = await tx.financeTransaction.findMany({
      where: { bookId: this.bookId },
      orderBy: [{ occurredAt: 'desc' }, { id: 'asc' }],
    });
    const allocations = await tx.financeAllocation.findMany({
      where: { bookId: this.bookId },
      include: { items: true },
      orderBy: [{ createdAt: 'desc' }, { id: 'asc' }],
    });
    const balance = transactions.reduce(
      (s, t) => s + t.amount,
      book.openingBalance,
    );
    const jarDtos = jars.map((j) => ({
      id: j.id,
      title: j.title,
      subtitle: j.subtitle,
      style: j.styleKey,
      bps: j.allocationBps,
      allocated: allocations
        .flatMap((a) => a.items)
        .filter((i) => i.jarId === j.id)
        .reduce((s, i) => s + i.amount, 0n),
      spent: transactions
        .filter((t) => t.jarId === j.id && t.amount < 0n)
        .reduce((s, t) => s - t.amount, 0n),
      default: j.defaultCode !== null,
      deleted: j.deletedAt !== null,
    }));
    const active = jarDtos.filter((j) => !j.deleted);
    const unallocated =
      balance - active.reduce((s, j) => s + j.allocated - j.spent, 0n);
    const history = allocations.map((a) => ({
      id: a.id,
      amount: a.amount,
      at: a.createdAt,
      amounts: Object.fromEntries(a.items.map((i) => [i.jarId, i.amount])),
      ratios: Object.fromEntries(a.items.map((i) => [i.jarId, i.ratioBps])),
    }));
    return {
      book,
      jars,
      transactions,
      jarDtos,
      active,
      balance,
      unallocated,
      history,
    };
  }
  async jars() {
    return this.read(async (tx) => {
      const s = await this.snapshot(tx);
      return json({
        jars: s.active,
        deletedJars: s.jarDtos.filter((j) => j.deleted),
        history: s.history,
        accountBalance: s.balance,
        revision: s.book.revision,
        isPersistent: true,
      });
    });
  }
  async overview(start: unknown, end: unknown) {
    const from = date(start),
      to = date(end);
    if (from >= to || to.getTime() - from.getTime() > 367 * 86400000)
      throw new BadRequestException('Khoảng ngày không hợp lệ.');
    return this.read(async (tx) => {
      const s = await this.snapshot(tx);
      const entries = s.transactions.filter(
        (t) => t.occurredAt >= from && t.occurredAt < to,
      );
      return json({
        balance: s.balance,
        initialBalance: s.book.openingBalance,
        budget: s.book.budget,
        income: entries
          .filter((t) => t.amount > 0n)
          .reduce((v, t) => v + t.amount, 0n),
        expense: entries
          .filter((t) => t.amount < 0n)
          .reduce((v, t) => v - t.amount, 0n),
        transactions: entries.map((t) => ({
          id: t.id,
          title: t.title,
          amount: t.amount,
          occurredAt: t.occurredAt,
          category: t.category,
          jarId: t.jarId,
          note: t.note,
        })),
        upcoming: [],
        isPersistent: true,
        isDemo: s.book.isDemo,
      });
    });
  }
  async sources() {
    return this.read(async (tx) => {
      const s = await this.snapshot(tx);
      return json([
        {
          title: 'Tiền chưa phân bổ',
          availableAmount: s.unallocated,
          jarId: null,
        },
        ...s.active.map((j) => ({
          title: j.title,
          availableAmount: j.allocated - j.spent,
          jarId: j.id,
        })),
      ]);
    });
  }
  private async read(action: (tx: Tx) => Promise<Prisma.InputJsonValue>) {
    try {
      await this.ensureBook();
      return await this.db.client.$transaction(action, {
        isolationLevel: 'RepeatableRead',
      });
    } catch (e) {
      if (e instanceof HttpException) throw e;
      throw new ServiceUnavailableException('Chưa đọc được dữ liệu tài chính.');
    }
  }
  private async write(
    operation: string,
    body: Body,
    key: unknown,
    action: (tx: Tx) => Promise<unknown>,
  ) {
    if (!body || typeof body !== 'object' || Array.isArray(body))
      throw new BadRequestException('Dữ liệu không hợp lệ.');
    const requestKey = text(key, 100, 'Mã yêu cầu');
    const hash = createHash('sha256')
      .update(canonical({ operation, body }))
      .digest('hex');
    for (let attempt = 0; attempt < 4; attempt++) {
      try {
        await this.ensureBook();
        return await this.db.client.$transaction(
          async (tx) => {
            await tx.$queryRaw`SELECT id FROM finance_books WHERE id = ${this.bookId}::uuid FOR UPDATE`;
            const old = await tx.financeRequest.findUnique({
              where: { bookId_key: { bookId: this.bookId, key: requestKey } },
            });
            if (old) {
              if (old.hash !== hash || old.operation !== operation)
                throw new ConflictException(
                  'Mã yêu cầu đã dùng cho nội dung khác.',
                );
              return old.response;
            }
            const response = json(await action(tx));
            await tx.financeBook.update({
              where: { id: this.bookId },
              data: { revision: { increment: 1 } },
            });
            await tx.financeRequest.create({
              data: {
                bookId: this.bookId,
                key: requestKey,
                operation,
                hash,
                response,
              },
            });
            return response;
          },
          { isolationLevel: 'Serializable', timeout: 15000 },
        );
      } catch (e) {
        if (e instanceof HttpException) throw e;

        const failure = e as {
          code?: string;
          meta?: { driverAdapterError?: { cause?: { originalCode?: string } } };
        };
        const sqlCode = failure?.meta?.driverAdapterError?.cause?.originalCode;
        if (
          failure?.code === 'P2034' ||
          failure?.code === 'P2002' ||
          (failure?.code === 'P2010' &&
            (sqlCode === '40001' || sqlCode === '40P01'))
        ) {
          if (attempt < 3) continue;
          throw new ConflictException(
            'Dữ liệu vừa thay đổi. Hãy tải lại rồi thử lại.',
          );
        }
        throw new ServiceUnavailableException(
          'Chưa lưu được dữ liệu tài chính. Bạn có thể thử lại cùng mã yêu cầu.',
        );
      }
    }
  }
  private checkRevision(expected: unknown, current: number) {
    if (revision(expected) !== current)
      throw new ConflictException(
        'Dữ liệu đã thay đổi. Đóng form, tải lại rồi thử lại.',
      );
  }
  expense(body: Body, key: unknown) {
    return this.write('expense', body, key, async (tx) => {
      const amount = money(body.amount),
        title = text(body.title, 80, 'Tên khoản chi'),
        occurredAt = date(body.occurredAt);
      if (
        typeof body.category !== 'string' ||
        !categories.includes(body.category)
      )
        throw new BadRequestException('Danh mục không hợp lệ.');
      const note = body.note == null ? null : text(body.note, 500, 'Ghi chú');
      const jarId = body.jarId == null ? null : uuid(body.jarId);
      const s = await this.snapshot(tx);
      const jar = jarId ? s.active.find((j) => j.id === jarId) : null;
      if (jarId && !jar)
        throw new NotFoundException('Hũ không tồn tại hoặc đã xóa.');
      if (amount > (jar ? jar.allocated - jar.spent : s.unallocated))
        throw new BadRequestException('Nguồn tiền không đủ để chi.');
      const record = await tx.financeTransaction.create({
        data: {
          bookId: this.bookId,
          jarId,
          title,
          amount: -amount,
          category: body.category,
          occurredAt,
          note,
        },
      });
      return { id: record.id };
    });
  }
  addJar(body: Body, key: unknown) {
    return this.write('addJar', body, key, async (tx) => {
      const title = text(body.title, 50, 'Tên hũ'),
        normalizedTitle = title.toLocaleLowerCase('vi');
      const subtitle =
        body.subtitle === '' ? '' : text(body.subtitle, 120, 'Mô tả');
      if (typeof body.styleKey !== 'string' || !styles.includes(body.styleKey))
        throw new BadRequestException('Kiểu hũ không hợp lệ.');
      if (
        await tx.financeJar.findFirst({
          where: { bookId: this.bookId, normalizedTitle, deletedAt: null },
        })
      )
        throw new ConflictException('Tên hũ đã tồn tại.');
      const j = await tx.financeJar.create({
        data: {
          bookId: this.bookId,
          title,
          normalizedTitle,
          subtitle,
          styleKey: body.styleKey,
        },
      });
      return {
        id: j.id,
        title: j.title,
        subtitle: j.subtitle,
        style: j.styleKey,
        bps: 0,
        allocated: 0n,
        spent: 0n,
        default: false,
        deleted: false,
      };
    });
  }
  ratios(body: Body, key: unknown) {
    return this.write('ratios', body, key, async (tx) => {
      const s = await this.snapshot(tx);
      this.checkRevision(body.expectedRevision, s.book.revision);
      if (
        !body.ratios ||
        typeof body.ratios !== 'object' ||
        Array.isArray(body.ratios)
      )
        throw new BadRequestException('Tỷ lệ không hợp lệ.');
      const ratios = body.ratios as Record<string, unknown>;
      if (
        Object.keys(ratios).length !== s.active.length ||
        s.active.some(
          (j) =>
            !Number.isInteger(ratios[j.id]) ||
            (ratios[j.id] as number) < 0 ||
            (ratios[j.id] as number) > 10000,
        ) ||
        Object.values(ratios).reduce<number>(
          (v, n) => v + (typeof n === 'number' ? n : NaN),
          0,
        ) !== 10000
      )
        throw new BadRequestException(
          'Cần tỷ lệ của tất cả hũ, tổng đúng 100%.',
        );
      for (const j of s.active)
        await tx.financeJar.update({
          where: { id: j.id },
          data: { allocationBps: ratios[j.id] as number },
        });
      return { saved: true };
    });
  }
  allocate(body: Body, key: unknown) {
    return this.write('allocate', body, key, async (tx) => {
      const amount = money(body.amount),
        s = await this.snapshot(tx);
      if (body.expectedRevision != null)
        this.checkRevision(body.expectedRevision, s.book.revision);
      if (amount > s.unallocated)
        throw new BadRequestException('Tiền chưa phân bổ không đủ.');
      const parts = split(
        amount,
        s.jars.filter((j) => !j.deletedAt),
      );
      const record = await tx.financeAllocation.create({
        data: {
          bookId: this.bookId,
          amount,
          items: {
            create: s.active.map((j) => ({
              jarId: j.id,
              amount: parts.get(j.id)!,
              ratioBps: j.bps,
            })),
          },
        },
        include: { items: true },
      });
      return {
        id: record.id,
        amount: record.amount,
        at: record.createdAt,
        amounts: Object.fromEntries(
          record.items.map((i) => [i.jarId, i.amount]),
        ),
        ratios: Object.fromEntries(
          record.items.map((i) => [i.jarId, i.ratioBps]),
        ),
      };
    });
  }
  deleteJar(id: unknown, body: Body, key: unknown) {
    const jarId = uuid(id);
    return this.write('deleteJar:' + jarId, body, key, async (tx) => {
      const s = await this.snapshot(tx);
      this.checkRevision(body.expectedRevision, s.book.revision);
      const j = s.active.find((j) => j.id === jarId);
      if (!j) throw new NotFoundException('Hũ không tồn tại hoặc đã xóa.');
      if (j.default)
        throw new BadRequestException('Không thể xóa hũ mặc định.');
      if (j.bps > 0) {
        const other = s.active.find(
          (x) => x.id === body.transferRatioToJarId && x.id !== jarId,
        );
        if (!other)
          throw new BadRequestException('Chọn hũ nhận tỷ lệ trước khi xóa.');
        await tx.financeJar.update({
          where: { id: other.id },
          data: { allocationBps: other.bps + j.bps },
        });
      }
      await tx.financeJar.update({
        where: { id: jarId },
        data: { deletedAt: new Date(), allocationBps: 0 },
      });
      return { deleted: true };
    });
  }
}
