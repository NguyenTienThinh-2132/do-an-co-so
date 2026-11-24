// Explicit report-only fixture. A different finance book from the normal app.
import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
import { PrismaService } from '../dist/prisma/prisma.service.js';
import { FinanceService } from '../dist/finance/finance.service.js';
if (!process.argv.includes('--demo-data')) throw new Error('Use --demo-data to explicitly choose the report fixture.');
const bookId='00000000-0000-4000-8000-000000000002';
process.env.FINAI_FINANCE_BOOK_ID=bookId;
const app=await NestFactory.createApplicationContext(AppModule,{logger:false,abortOnError:false});
try {
 await app.get(FinanceService).jars();
 const db=app.get(PrismaService).client;
 await db.$transaction(async tx=>{
  await tx.$queryRaw`SELECT id FROM finance_books WHERE id=${bookId}::uuid FOR UPDATE`;
  const book=await tx.financeBook.findUniqueOrThrow({where:{id:bookId}});
  const entries=await tx.financeTransaction.count({where:{bookId}});
  const requests=await tx.financeRequest.count({where:{bookId}});
  if(book.isDemo) {console.log('Using saved report data; no re-seeding.');return;}
  if(book.openingBalance!==0n || entries || requests)throw new Error('Report book already contains non-demo changes; refused to seed.');
  const now=new Date();
  await tx.financeBook.update({where:{id:bookId},data:{openingBalance:5000000n,budget:3000000n,isDemo:true,revision:{increment:1}}});
  await tx.financeTransaction.createMany({data:[
   {bookId,title:'Thu nhap mau - bao cao',amount:3000000n,category:'other',occurredAt:new Date(Date.UTC(now.getFullYear(),now.getMonth(),1,2))},
   {bookId,title:'An trua mau - bao cao',amount:-100000n,category:'food',occurredAt:new Date(Date.UTC(now.getFullYear(),now.getMonth(),1,3))},
   {bookId,title:'Di chuyen mau - bao cao',amount:-50000n,category:'transport',occurredAt:new Date(Date.UTC(now.getFullYear(),now.getMonth(),1,4))},
  ]});
  console.log('Created isolated, labelled report fixture. No bank or user data imported.');
 });
} finally {await app.close();}
const server=await NestFactory.create(AppModule,{logger:false,abortOnError:false});
server.setGlobalPrefix('api');
await server.listen(3111,'127.0.0.1');
console.log('FinAI report API: http://127.0.0.1:3111/api (separate demo finance book)');
for(const signal of ['SIGINT','SIGTERM']) process.on(signal,async()=>{await server.close();process.exit(0);});
