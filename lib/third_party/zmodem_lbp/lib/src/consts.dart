// ignore_for_file: constant_identifier_names

// Ascii characters
const SOH = 0x01;
const STX = 0x02;
const EOT = 0x04;
const ENQ = 0x05;
const ACK = 0x06;
const LF = 0x0a;
const CR = 0x0d;
const XON = 0x11;
const XOFF = 0x13;
const NAK = 0x15;
const CAN = 0x18;

// ZModem Frame Types
const ZRQINIT = 0x00;
const ZRINIT = 0x01;
const ZSINIT = 0x02;
const ZACK = 0x03;
const ZFILE = 0x04;
const ZSKIP = 0x05;
const ZNAK = 0x06;
const ZABORT = 0x07;
const ZFIN = 0x08;
const ZRPOS = 0x09;
const ZDATA = 0x0a;
const ZEOF = 0x0b;
const ZFERR = 0x0c;
const ZCRC = 0x0d;
const ZCHALLENGE = 0x0e;
const ZCOMPL = 0x0f;
const ZCAN = 0x10;
const ZFREECNT = 0x11;
const ZCOMMAND = 0x12;
const ZSTDERR = 0x13;

// ZMODEM ZDLE sequences
const ZCRCE = 0x68;
const ZCRCG = 0x69;
const ZCRCQ = 0x6a;
const ZCRCW = 0x6b;
const ZRUB0 = 0x6c;
const ZRUB1 = 0x6d;

// ZModem Protocol bytes
const ZPAD = 0x2a; // pad character; begins frames
const ZDLE = 0x18; // ctrl-x zmodem escape
const ZDLEE = 0x58; // escaped ZDLE

const ZBIN = 0x41; // binary frame indicator (CRC16)
const ZHEX = 0x42; // hex frame indicator
const ZBIN32 = 0x43; // binary frame indicator (CRC32)
const ZBINR32 = 0x44; // run length encoded binary frame (CRC32)

const ZVBIN = 0x61; // binary frame indicator (CRC16)
const ZVHEX = 0x62; // hex frame indicator
const ZVBIN32 = 0x63; // binary frame indicator (CRC32)
const ZVBINR32 = 0x64; // run length encoded binary frame (CRC32)
const ZRESC = 0x7e; // run length encoding flag / escape character

// ZMODEM Frame contents
const ENDOFFRAME = 2;
const FRAMEOK = 1;
const TIMEOUT = -1; // Rx routine did not receive a character within timeout
const INVHDR = -2; // Invalid header received; but within timeout
const INVDATA = -3; // Invalid data subpacket received
const ZDLEESC = 0x8000; // One of ZCRCE/ZCRCG/ZCRCQ/ZCRCW was ZDLE escaped

// ZMODEM capabilities flags
const CANFDX = 0x01; // Rx can send and receive true FDX
const CANOVIO = 0x02; // Rx can receive data during disk I/O
const CANBRK = 0x04; // Rx can send a break signal
const CANCRY = 0x08; // Receiver can decrypt -- nothing does this
const CANLZW = 0x10; // Receiver can uncompress -- nothing does this
const CANFC32 = 0x20; // Receiver can use 32 bit Frame Check
const ESCCTL = 0x40; // Receiver expects ctl chars to be escaped
const ESC8 = 0x80; // Receiver expects 8th bit to be escaped
