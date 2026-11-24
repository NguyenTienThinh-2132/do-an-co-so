// Real local NestJS/PostgreSQL check. Uses owned fixtures only and cleans them.
import 'reflect-metadata';
import assert from 'node:assert/strict';
import { createHash,randomUUID } from 'node:crypto';
import { loadEnvFile } from 'node:process';
import { writeFileSync } from 'node:fs';
import pg from 'pg';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../dist/app.module.js';
loadEnvFile('.env');
const target=new URL(process.env.DATABASE_URL);
if(target.hostname!=='127.0.0.1'||!['5432','5433'].includes(target.port)||target.pathname!=='/finai_tv3_demo')throw new Error('Check only supports the local FinAI demo database.');
const sql=new pg.Client({connectionString:target.toString(),connectionTimeoutMillis:5000});
await sql.connect();
const initial=(await sql.query('SELECT * FROM tasks ORDER BY id')).rows;
const initialHash=createHash('sha256').update(JSON.stringify(initial)).digest('hex');
const marker='__tv3_version_http_'+randomUUID();
const ownedIds=new Set();let app;let base;let checks=0;
const body={title:marker,startAt:'2048-01-03T02:00:00Z',endAt:'2048-01-03T03:00:00Z',priority:'high'};
async function api(method,path,data,status=200){
 const response=await fetch(base+path,{method,headers:{'Content-Type':'application/json'},...(data?{body:JSON.stringify(data)}:{}),signal:AbortSignal.timeout(10000)});
 const text=await response.text();const result=text?JSON.parse(text):null;
 if(result && typeof result.id==='string' && typeof result.title==='string' && result.title.startsWith(marker))ownedIds.add(result.id);
 assert.equal(response.status,status,'Unexpected HTTP status');checks++;return result;
}
try {
 app=await NestFactory.create(AppModule,{logger:false,abortOnError:false});await app.listen(0,'127.0.0.1');base=await app.getUrl();
 const created=await api('POST','/tasks',body,201);const id=created.id;
 assert.equal(created.version,1);assert.equal((await api('GET','/tasks/'+id)).version,1);
 const list=await api('GET','/tasks?'+new URLSearchParams({start:'2048-01-03T00:00:00Z',end:'2048-01-04T00:00:00Z',searchText:marker}));
 assert.equal(list.length,1);assert.equal(list[0].version,1);
 const updated=await api('PUT','/tasks/'+id,{...body,title:marker+' updated'});assert.equal(updated.version,2);assert.equal(updated.createdAt,created.createdAt);
 assert.equal((await api('PATCH','/tasks/'+id+'/status',{status:'inProgress'})).version,3);
 // An accepted no-op write is still a new server revision.
 assert.equal((await api('PATCH','/tasks/'+id+'/status',{status:'inProgress'})).version,4);
 await api('POST','/tasks',{...body,version:99},400);
 await api('PUT','/tasks/'+id,{...body,version:99},400);
 await api('PATCH','/tasks/'+id+'/status',{status:'completed',version:99},400);
 await api('PUT','/tasks/'+id,{...body,endAt:body.startAt},400);
 await api('PUT','/tasks/'+randomUUID(),body,404);
 assert.equal((await api('GET','/tasks/'+id)).version,4);
 await assert.rejects(sql.query('UPDATE tasks SET version=0 WHERE id=$1',[id]),e=>e?.code==='23514');
 assert.equal((await api('GET','/tasks/'+id)).version,4);
 const parallel=await Promise.all(['A','B'].map(suffix=>api('PUT','/tasks/'+id,{...body,title:marker+suffix})));
 assert.deepEqual(parallel.map(t=>t.version).sort((a,b)=>a-b),[5,6]);
 const final=await api('GET','/tasks/'+id);assert.equal(final.version,6);assert.equal(final.status,'inProgress');assert.equal(final.createdAt,created.createdAt);
 await api('DELETE','/tasks/'+id,undefined,204);await api('GET','/tasks/'+id,undefined,404);
 const after=(await sql.query('SELECT * FROM tasks ORDER BY id')).rows;
 assert.equal(createHash('sha256').update(JSON.stringify(after)).digest('hex'),initialHash);
 const report={checkedAt:new Date().toISOString(),httpChecks:checks,newTaskVersion:1,afterEditVersion:2,afterStatusVersion:3,concurrentVersions:[5,6],rejectedWritesKeepVersion:true,existingTasksUnchanged:true};
 writeFileSync('../build/task-version-http-result.json',JSON.stringify(report,null,2));console.log(report);
}finally{
 for(const id of ownedIds){
  await sql.query('DELETE FROM tasks WHERE id=$1 AND title LIKE $2',[id,marker+'%']);
  await sql.query('DELETE FROM task_tombstones WHERE task_id=$1',[id]);
 }
 if(app)await app.close();await sql.end();
}
