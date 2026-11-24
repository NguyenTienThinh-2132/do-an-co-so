// Isolated finance book only. Never edits the user's Tasks or finance book.
import 'reflect-metadata';
import assert from 'node:assert/strict';
import { randomUUID, createHash } from 'node:crypto';
import { loadEnvFile } from 'node:process';
import { writeFileSync } from 'node:fs';
import pg from 'pg';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
loadEnvFile('.env');
const sql = new pg.Client({connectionString:process.env.DATABASE_URL});
await sql.connect();
const before=(await sql.query('SELECT * FROM tasks ORDER BY id')).rows;
const taskHash = createHash('sha256').update(JSON.stringify(before)).digest('hex');
const book=randomUUID();process.env.FINAI_FINANCE_BOOK_ID=book;
let app;let base;let checks=0;
async function start(){app=await NestFactory.create(AppModule,{logger:false,abortOnError:false});await app.listen(0,'127.0.0.1');base=await app.getUrl();}
async function api(method,path,body,key,status=200){
 const response=await fetch(base+'/finance/'+path,{method,headers:{'Content-Type':'application/json',...(key?{'Idempotency-Key':key}:{})},...(body?{body:JSON.stringify(body)}:{})});
 const data=await response.json();assert.equal(response.status,status,JSON.stringify(data));checks++;return data;
}
const range='overview?start=2026-10-31T17:00:00Z&end=2026-11-30T17:00:00Z';
try {
 await start();
 let jars=await api('GET','jars');assert.equal(jars.jars.length,6);assert.equal(jars.accountBalance,'0');
 await sql.query('UPDATE finance_books SET opening_balance_vnd=1000000, is_demo=true WHERE id=$1',[book]);
 const allocation={amount:'500000',expectedRevision:0};
 const first=await api('POST','allocations',allocation,'allocate-1',201);
 assert.equal(Object.values(first.amounts).reduce((s,v)=>s+BigInt(v),0n),500000n);
 assert.deepEqual(await api('POST','allocations',allocation,'allocate-1',201),first);
 await api('POST','allocations',{amount:'500001',expectedRevision:0},'allocate-1',409);
 const expense={title:'Khoan chi test',amount:'100000',occurredAt:'2026-11-13T03:00:00Z',category:'food',jarId:null,note:null};
 const spent=await api('POST','expenses',expense,'expense-1',201);
 assert.deepEqual(await api('POST','expenses',expense,'expense-1',201),spent);
 let overview=await api('GET',range);assert.equal(overview.balance,'900000');assert.equal(overview.expense,'100000');assert.equal(overview.transactions.length,1);
 const jar=jars.jars.find(j=>j.style==='home');
 await api('POST','expenses',{...expense,amount:'50000',jarId:jar.id},'expense-jar',201);
 jars=await api('GET','jars');assert.equal(jars.jars.find(j=>j.id===jar.id).spent,'50000');assert.equal(jars.accountBalance,'850000');
 await api('POST','expenses',{...expense,amount:'999999999999'},'expense-too-big',400);
 await api('POST','expenses',{...expense,title:' '},'expense-empty',400);
 await api('POST','expenses',{...expense,jarId:randomUUID()},'expense-missing',404);
 const custom=await api('POST','jars',{title:'Muc tieu test',subtitle:'',styleKey:'target'},'add-1',201);
 jars=await api('GET','jars');
 const ratios=Object.fromEntries(jars.jars.map(j=>[j.id,j.bps]));
 ratios[jar.id]-=1000;ratios[custom.id]=1000;
 await api('PUT','jars/ratios',{ratios,expectedRevision:0},'ratios-stale',409);
 await api('PUT','jars/ratios',{ratios,expectedRevision:jars.revision},'ratios-1');
 jars=await api('GET','jars');
 await api('POST','allocations',{amount:'100000',expectedRevision:jars.revision},'allocate-2',201);
 await api('POST','expenses',{...expense,amount:'1000',jarId:custom.id},'custom-spend',201);
 jars=await api('GET','jars');
 const balanceBefore=jars.accountBalance;
 await api('DELETE','jars/'+custom.id,{expectedRevision:jars.revision,transferRatioToJarId:jar.id},'delete-1');
 jars=await api('GET','jars');assert.equal(jars.accountBalance,balanceBefore);assert.equal(jars.deletedJars[0].spent,'1000');assert.equal(jars.history.length,2);
 // Simultaneous requests cannot spend the same unallocated funds twice.
 const results=await Promise.all([0,1].map(async i=>{
  const r=await fetch(base+'/finance/expenses',{method:'POST',headers:{'Content-Type':'application/json','Idempotency-Key':'race-'+i},body:JSON.stringify({...expense,amount:'250000'})});return r.status;
 }));
 assert.deepEqual(results.sort(),[201,400]);checks++;
 const saved=await api('GET',range);await app.close();await start();
 assert.deepEqual(await api('GET',range),saved);
 const sources=await api('GET','expense-sources');assert.ok(sources.every(s=>BigInt(s.availableAmount)>=0n));
 const after=(await sql.query('SELECT * FROM tasks ORDER BY id')).rows;
 assert.equal(createHash('sha256').update(JSON.stringify(after)).digest('hex'),taskHash);
 const report={checkedAt:new Date().toISOString(),httpChecks:checks,taskCount:after.length,tasksUnchanged:true,restartPersistence:true,concurrentSpendProtected:true,isolatedBookCleaned:true};
 writeFileSync('../build/finance-postgres-check.json',JSON.stringify(report,null,2));console.log(report);
} finally {
 if(app)await app.close();
 await sql.query('DELETE FROM finance_requests WHERE book_id=$1',[book]);
 await sql.query('DELETE FROM finance_allocation_items WHERE allocation_id IN (SELECT id FROM finance_allocations WHERE book_id=$1)',[book]);
 for(const table of ['finance_allocations','finance_transactions','finance_jars','finance_books'])await sql.query(`DELETE FROM ${table} WHERE ${table==='finance_books'?'id':'book_id'}=$1`,[book]);
 await sql.end();
}
