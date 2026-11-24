// Run via setup-postgres-local.ps1 to enter the existing admin password privately.
// Never changes pg_hba.conf, resets admin passwords, or overwrites an existing DB.
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync, renameSync, unlinkSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
const root=new URL('../',import.meta.url);
const envPath=fileURLToPath(new URL('.env',root));
const pending=fileURLToPath(new URL('.env.native.pending',root));
const stamp=new Date().toISOString().replace(/[:.]/g,'-');
const backup=fileURLToPath(new URL('.env.before-native-'+stamp,root));
const appUser='finai_app',dbName='finai_tv3_demo';
const port=Number(process.env.FINAI_ADMIN_PORT||'5432');
if(![5432,5433].includes(port))throw new Error('Unsupported local port');
const adminPassword=process.env.FINAI_ADMIN_PASSWORD;
if(!adminPassword){console.error('Chạy setup-postgres-local.ps1 để nhập mật khẩu postgres trên máy.');process.exit(1);}
const admin=new pg.Client({host:'127.0.0.1',port,user:process.env.FINAI_ADMIN_USER||'postgres',database:'postgres',password:adminPassword,connectionTimeoutMillis:5000});
let createdRole=false,createdDatabase=false,createdPending=false;
try {
 await admin.connect();
 const roles=await admin.query('SELECT 1 FROM pg_roles WHERE rolname=$1',[appUser]);
 const databases=await admin.query('SELECT 1 FROM pg_database WHERE datname=$1',[dbName]);
 if(roles.rowCount||databases.rowCount){console.error('Tài khoản hoặc database FinAI đã tồn tại. Dừng để không ghi đè; hãy kiểm tra và cấu hình .env bằng thông tin hiện có.');process.exitCode=1;}
 else if(existsSync(pending)){console.error('Còn .env.native.pending từ lần trước. Dừng để giữ thông tin khôi phục.');process.exitCode=1;}
 else {
  const old=existsSync(envPath)?readFileSync(envPath,'utf8'):'';
  const password=randomBytes(32).toString('hex');
  const url=`postgresql://${appUser}:${encodeURIComponent(password)}@127.0.0.1:${port}/${dbName}?schema=public`;
  const preserved=old.split(/\r?\n/).filter(line=>!/^\s*(?:DATABASE_URL|POSTGRES_DB|POSTGRES_USER|POSTGRES_PASSWORD|POSTGRES_PORT)\s*=/.test(line));
  const updated=preserved.join('\n').trimEnd()+'\nDATABASE_URL='+url+'\n';
  if(existsSync(envPath))writeFileSync(backup,old,{flag:'wx',mode:0o600});
  writeFileSync(pending,updated,{flag:'wx',mode:0o600});createdPending=true;
  // Password is generated hex, not user-controlled SQL. Never print it.
  await admin.query(`CREATE ROLE "${appUser}" LOGIN PASSWORD '${password}'`);createdRole=true;
  await admin.query(`CREATE DATABASE "${dbName}" OWNER "${appUser}"`);createdDatabase=true;
  const check=new pg.Client({connectionString:url,connectionTimeoutMillis:5000});
  try{await check.connect();await check.query('SELECT 1');}finally{await check.end().catch(()=>{});}
  renameSync(pending,envPath);
  console.log(`Đã tạo tài khoản finai_app và database finai_tv3_demo trên PostgreSQL trực tiếp :${port}.`);
  console.log('Đã kiểm tra đăng nhập và cập nhật backend/.env; mật khẩu app không in ra console.');
  console.log('Đã giữ bản .env cũ nếu có. Chưa chạy migration hoặc nhập dữ liệu Docker.');
 }
} catch(e) {
 if(createdRole&&!createdDatabase){try{await admin.query(`DROP ROLE "${appUser}"`);createdRole=false;}catch{}}
 if(createdPending&&!createdDatabase&&!createdRole&&existsSync(pending))try{unlinkSync(pending);}catch{}
 if(createdDatabase)console.error('Đã tạo database, nhưng chưa hoàn tất. Giữ .env.native.pending để khôi phục; không chạy tạo lại.');
 else if(e?.code==='28P01')console.error('Không đăng nhập được postgres. Kiểm tra mật khẩu quản trị; chưa tạo database.');
 else console.error('Chưa tạo được database FinAI. Kiểm tra PostgreSQL, quyền quản trị và file cấu hình; không in lỗi hoặc mật khẩu thô.');
 process.exitCode=1;
} finally {await admin.end().catch(()=>{});}
