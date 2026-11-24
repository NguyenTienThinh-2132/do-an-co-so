/// Danh mục tên để nhận diện ứng viên, KHÔNG phải danh sách app đã tin cậy.
/// Chưa chứa package đã xác minh hoặc cam kết parser hỗ trợ ngân hàng.
/// Snapshot: 12/11/2026. Phạm vi rộng, chưa bảo đảm đầy đủ mọi chi nhánh/app.
/// Nguồn: https://api.vietqr.io/v2/banks (bỏ ví điện tử/công ty tài chính).
/// Tên số tham chiếu: https://cake.vn/ và https://timo.vn/.
/// Tên VCBNeo: https://www.vcbneo.com.vn/Pages/About.aspx
/// Bổ sung: https://www.anz.com/vietnam/ và https://vdb.gov.vn/.
/// Không lấy nội dung title/text thông báo để đoán tên ứng dụng.
class BankCatalogEntry {
  const BankCatalogEntry({
    required this.id,
    required this.name,
    this.aliases = const [],
  });
  final String id;
  final String name;
  final List<String> aliases;
}

const vietnamBankCatalog = <BankCatalogEntry>[
  BankCatalogEntry(id: 'icb', name: 'VietinBank', aliases: ['VietinBank iPay']),
  BankCatalogEntry(id: 'vcb', name: 'Vietcombank', aliases: ['VCB Digibank']),
  BankCatalogEntry(id: 'bidv', name: 'BIDV', aliases: ['BIDV SmartBanking']),
  BankCatalogEntry(id: 'vba', name: 'Agribank', aliases: []),
  BankCatalogEntry(id: 'ocb', name: 'OCB', aliases: []),
  BankCatalogEntry(id: 'mb', name: 'MBBank', aliases: ['MB Bank']),
  BankCatalogEntry(
    id: 'tcb',
    name: 'Techcombank',
    aliases: ['Techcombank Mobile'],
  ),
  BankCatalogEntry(id: 'acb', name: 'ACB', aliases: []),
  BankCatalogEntry(id: 'vpb', name: 'VPBank', aliases: []),
  BankCatalogEntry(id: 'tpb', name: 'TPBank', aliases: ['TPBank Mobile']),
  BankCatalogEntry(id: 'stb', name: 'Sacombank', aliases: []),
  BankCatalogEntry(id: 'hdb', name: 'HDBank', aliases: []),
  BankCatalogEntry(
    id: 'vccb',
    name: 'BVBank',
    aliases: ['VietCapitalBank', 'Bản Việt'],
  ),
  BankCatalogEntry(id: 'scb', name: 'SCB', aliases: []),
  BankCatalogEntry(id: 'vib', name: 'VIB', aliases: []),
  BankCatalogEntry(id: 'shb', name: 'SHB', aliases: []),
  BankCatalogEntry(id: 'eib', name: 'Eximbank', aliases: []),
  BankCatalogEntry(id: 'msb', name: 'MSB', aliases: []),
  BankCatalogEntry(
    id: 'cake',
    name: 'CAKE',
    aliases: ['Cake by VPBank', 'CAKE BANK'],
  ),
  BankCatalogEntry(id: 'ubank', name: 'Ubank', aliases: ['Ubank by VPBank']),
  BankCatalogEntry(id: 'timo', name: 'Timo', aliases: ['Timo by BVBank']),
  BankCatalogEntry(id: 'sgicb', name: 'SaigonBank', aliases: []),
  BankCatalogEntry(id: 'bab', name: 'BacABank', aliases: []),
  BankCatalogEntry(id: 'pvdb', name: 'PVcomBank Pay', aliases: []),
  BankCatalogEntry(id: 'pvcb', name: 'PVcomBank', aliases: []),
  BankCatalogEntry(id: 'mbv', name: 'MBV', aliases: ['OceanBank']),
  BankCatalogEntry(id: 'ncb', name: 'NCB', aliases: []),
  BankCatalogEntry(id: 'shbvn', name: 'ShinhanBank', aliases: []),
  BankCatalogEntry(id: 'abb', name: 'ABBANK', aliases: []),
  BankCatalogEntry(id: 'vab', name: 'VietABank', aliases: []),
  BankCatalogEntry(id: 'nab', name: 'NamABank', aliases: []),
  BankCatalogEntry(id: 'pgb', name: 'PGBank', aliases: []),
  BankCatalogEntry(id: 'vietbank', name: 'VietBank', aliases: []),
  BankCatalogEntry(id: 'bvb', name: 'BaoVietBank', aliases: []),
  BankCatalogEntry(id: 'seab', name: 'SeABank', aliases: []),
  BankCatalogEntry(id: 'coopbank', name: 'COOPBANK', aliases: []),
  BankCatalogEntry(id: 'lpb', name: 'LPBank', aliases: ['LienVietPostBank']),
  BankCatalogEntry(id: 'klb', name: 'KienLongBank', aliases: []),
  BankCatalogEntry(id: 'kbank', name: 'KBank', aliases: []),
  BankCatalogEntry(id: 'kebhanahcm', name: 'KEBHanaHCM', aliases: []),
  BankCatalogEntry(id: 'kebhanahn', name: 'KEBHANAHN', aliases: []),
  BankCatalogEntry(id: 'vbsp', name: 'VBSP', aliases: []),
  BankCatalogEntry(id: 'bnp_hn', name: 'BNP HN', aliases: []),
  BankCatalogEntry(id: 'bidc', name: 'BIDC', aliases: []),
  BankCatalogEntry(id: 'bnp_hcm', name: 'BNP HCM', aliases: []),
  BankCatalogEntry(id: 'bochk', name: 'BOCHK', aliases: []),
  BankCatalogEntry(id: 'bsp', name: 'BSP', aliases: []),
  BankCatalogEntry(id: 'cubhcm', name: 'CUBHCM', aliases: []),
  BankCatalogEntry(id: 'esun', name: 'ESUN', aliases: []),
  BankCatalogEntry(id: 'icbc', name: 'ICBC', aliases: []),
  BankCatalogEntry(id: 'tnex', name: 'TNEX', aliases: ['TNEX by MSB']),
  BankCatalogEntry(id: 'hsbc', name: 'HSBC', aliases: []),
  BankCatalogEntry(id: 'hlbvn', name: 'HongLeong', aliases: []),
  BankCatalogEntry(id: 'ibk_-_hn', name: 'IBKHN', aliases: []),
  BankCatalogEntry(id: 'ibk_-_hcm', name: 'IBKHCM', aliases: []),
  BankCatalogEntry(id: 'ivb', name: 'IndovinaBank', aliases: []),
  BankCatalogEntry(
    id: 'vikki',
    name: 'Vikki Bank',
    aliases: ['Vikki', 'DongA Bank', 'DongABank'],
  ),
  BankCatalogEntry(id: 'nhb_hn', name: 'Nonghyup', aliases: []),
  BankCatalogEntry(id: 'dbs', name: 'DBSBank', aliases: []),
  BankCatalogEntry(id: 'pbvn', name: 'PublicBank', aliases: []),
  BankCatalogEntry(id: 'scvn', name: 'StandardChartered', aliases: []),
  BankCatalogEntry(id: 'citibank', name: 'Citibank', aliases: []),
  BankCatalogEntry(id: 'cimb', name: 'CIMB', aliases: []),
  BankCatalogEntry(id: 'uob', name: 'UOB', aliases: ['UnitedOverseas']),
  BankCatalogEntry(id: 'cbb', name: 'VCBNeo', aliases: ['CBBank', 'NeoOne']),
  BankCatalogEntry(id: 'gpb', name: 'GPBank', aliases: []),
  BankCatalogEntry(id: 'vrb', name: 'VRB', aliases: []),
  BankCatalogEntry(id: 'wvn', name: 'Woori', aliases: []),
  BankCatalogEntry(id: 'kbhn', name: 'KookminHN', aliases: []),
  BankCatalogEntry(id: 'kbhcm', name: 'KookminHCM', aliases: []),
  BankCatalogEntry(id: 'anz', name: 'ANZ', aliases: ['ANZ Vietnam']),
  BankCatalogEntry(
    id: 'vdb',
    name: 'VDB',
    aliases: ['Ngân hàng Phát triển Việt Nam'],
  ),
];
