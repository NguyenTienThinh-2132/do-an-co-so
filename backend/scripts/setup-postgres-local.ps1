param(
  [string]$AdminUser = 'postgres',
  [string]$NodePath = 'D:\nodejs\node.exe'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $NodePath)) { throw 'Không tìm thấy Node.js. Truyền -NodePath đúng.' }
$oldAdminUser = $env:FINAI_ADMIN_USER
$oldAdminPassword = $env:FINAI_ADMIN_PASSWORD
$adminSecret = Read-Host "Nhập mật khẩu quản trị $AdminUser của PostgreSQL trực tiếp (không hiển thị)" -AsSecureString
$secretPointer = [IntPtr]::Zero
try {
  $secretPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($adminSecret)
  $env:FINAI_ADMIN_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($secretPointer)
  $env:FINAI_ADMIN_USER = $AdminUser
  & $NodePath (Join-Path $PSScriptRoot 'setup-postgres-local.mjs')
  $setupExitCode = $LASTEXITCODE
} finally {
  if ($secretPointer -ne [IntPtr]::Zero) { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($secretPointer) }
  $adminSecret.Dispose()
  $env:FINAI_ADMIN_USER = $oldAdminUser
  $env:FINAI_ADMIN_PASSWORD = $oldAdminPassword
}
if ($setupExitCode -ne 0) { throw 'Thiết lập chưa hoàn tất. Xem thông báo phía trên; không gửi mật khẩu vào chat.' }
