// Test-only sqflite transport backed by Node's built-in SQLite. No npm packages.
// The only allowed database is the temp file passed by the Flutter test.
import { DatabaseSync } from 'node:sqlite';
import { createInterface } from 'node:readline';
import { resolve } from 'node:path';
const allowed=resolve(process.argv[2]);
const connections=new Map();let nextId=0;
function call(method,a={}) {
 if(method==='openDatabase') {
  if(resolve(a.path)!==allowed)throw new Error('Unexpected test database path');
  const id=++nextId;connections.set(id,new DatabaseSync(allowed));return {id};
 }
 if(method==='closeDatabase') {connections.get(a.id).close();connections.delete(a.id);return null;}
 if(method==='options')return null;
 const db=connections.get(a.id);if(!db)throw new Error('Unknown test connection');
 const args=a.arguments??[];
 if(method==='execute'){if(args.length)db.prepare(a.sql).run(...args);else db.exec(a.sql);return null;}
 const statement=db.prepare(a.sql);
 if(method==='query')return statement.all(...args);
 if(method==='insert')return Number(statement.run(...args).lastInsertRowid);
 if(method==='update')return Number(statement.run(...args).changes);
 throw new Error('Unsupported test method: '+method);
}
try {
 for await(const line of createInterface({input:process.stdin})) {
  try {const request=JSON.parse(line);process.stdout.write(JSON.stringify({result:call(request.method,request.args)})+'\n');}
  catch {process.stdout.write(JSON.stringify({error:'SQLite test transport failed'})+'\n');}
 }
} finally {for(const db of connections.values())db.close();}
