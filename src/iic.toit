import gpio
import log

import .mqtt
import .env

IIC_SCL ::= gpio.Pin 32
IIC_SDA ::= gpio.Pin 33
IIC_RST ::= gpio.Pin 25

GT_CMD_WR ::= 0xBA
GT_CMD_RD ::= 0xBB

GT_CTRL_REG ::= 0X8040
GT_CFGS_REG ::= 0X8047
GT_CHECK_REG ::= 0x80FF

GT911_READ_XY_REG ::= 0x814E

LOW ::= 0
HIGH ::= 1

CT_MAX_TOUCH ::= 5

IIC_SCL_0: IIC_SCL.set LOW
IIC_SCL_1: IIC_SCL.set HIGH
IIC_SDA_0: IIC_SDA.set LOW
IIC_SDA_1: IIC_SDA.set HIGH
IIC_RST_0: IIC_RST.set LOW
IIC_RST_1: IIC_RST.set HIGH
READ_SDA -> int: return IIC_SDA.get

class GT911_Dev:
  Touch := 0
  TouchpointFlag := 0
  TouchCount := 0

  Touchkeytrackid := ByteArray CT_MAX_TOUCH
  X := List CT_MAX_TOUCH 0
  Y := List CT_MAX_TOUCH 0
  S := List CT_MAX_TOUCH 0

Dev_Now := GT911_Dev
Dev_Backup := GT911_Dev
touched := false

delay_us xus: while xus > 1: xus-- 

SDA_IN: IIC_SDA.configure --input
SDA_OUT: IIC_SDA.configure --output

IIC_Start:
  SDA_OUT
  IIC_SDA_1
  IIC_SCL_1
  delay_us 4
  IIC_SDA_0
  delay_us 4
  IIC_SCL_0

IIC_Stop:
  SDA_OUT
  IIC_SCL_0
  IIC_SDA_0 
  delay_us 4
  IIC_SCL_1
  IIC_SDA_1
  delay_us 4

IIC_Wait_Ack:
  ucErrTime := 0
  SDA_IN
  IIC_SDA_1
  delay_us 1
  IIC_SCL_1
  delay_us 1
  while READ_SDA != 0:
    ucErrTime++
    if ucErrTime > 250:
      IIC_Stop
      return 1
  IIC_SCL_0
  return 0

IIC_Ack:
  IIC_SCL_0
  SDA_OUT
  IIC_SDA_0
  delay_us 2
  IIC_SCL_1
  delay_us 2
  IIC_SCL_0

IIC_NAck:
  IIC_SCL_0
  SDA_OUT
  IIC_SDA_1
  delay_us 2
  IIC_SCL_1
  delay_us 2
  IIC_SCL_0

IIC_Send_Byte txd/int:
  SDA_OUT
  IIC_SCL_0
  for t := 0; t < 8; t++:
    if ((txd & 0x80) >> 7) != 0:
      IIC_SDA_1
    else:
      IIC_SDA_0
    txd <<= 1
    delay_us 2
    IIC_SCL_1
    delay_us 2
    IIC_SCL_0
    delay_us 2

IIC_Read_Byte ack/int -> int:
  receive := 0
  SDA_IN
  for i := 0; i < 8; i++:
    IIC_SCL_0
    delay_us 2
    IIC_SCL_1
    receive <<= 1
    if READ_SDA != 0: receive++
    delay_us 1
  if ack == 0:
    IIC_NAck
  else:
    IIC_Ack
  return receive

GT911_WR_Reg reg/int buf/ByteArray len/int -> int:
  ret := 0
  IIC_Start
  IIC_Send_Byte GT_CMD_WR
  IIC_Wait_Ack
  IIC_Send_Byte (reg >> 8)
  IIC_Wait_Ack
  IIC_Send_Byte (reg & 0XFF)
  IIC_Wait_Ack
  for i := 0; i < len; i++:
    IIC_Send_Byte buf[i]
    ret = IIC_Wait_Ack
    if ret != 0: break
  IIC_Stop
  return ret

GT911_RD_Reg reg/int len/int -> ByteArray:
  buf := ByteArray len
  IIC_Start
  IIC_Send_Byte GT_CMD_WR
  IIC_Wait_Ack
  IIC_Send_Byte (reg >> 8)
  IIC_Wait_Ack
  IIC_Send_Byte (reg & 0XFF)
  IIC_Wait_Ack
  IIC_Start
  IIC_Send_Byte GT_CMD_RD
  IIC_Wait_Ack
  for i := 0; i < len; i++:
    buf[i] = IIC_Read_Byte (i == (len - 1) ? 0 : 1)
  IIC_Stop
  return buf

GT911_Send_Cfg mode/int -> int:
  buf := ByteArray 2
  buf[0] = 0
  buf[1] = mode  
  GT911_WR_Reg GT_CHECK_REG buf 2
  return 0

scan_buf_ := ByteArray 41
Clearbuf_ := 0
GT911_Scan:
  Dev_Now.Touch = 0;
  scan_buf_[0] = (GT911_RD_Reg GT911_READ_XY_REG 1)[0]

  if (scan_buf_[0] & 0x80) == 0x00:
    touched = false
    GT911_WR_Reg GT911_READ_XY_REG #[Clearbuf_] 1
    sleep --ms=10
  else:
    touched = true;
    Dev_Now.TouchpointFlag = scan_buf_[0];
    Dev_Now.TouchCount = scan_buf_[0] & 0x0f;
    if Dev_Now.TouchCount > 5:
      touched = false
      GT911_WR_Reg GT911_READ_XY_REG #[Clearbuf_] 1
      log.default.info "Dev_Now.TouchCount > 5\r\n"
      return
    scan_buf_.replace 1 (GT911_RD_Reg (GT911_READ_XY_REG + 1) (Dev_Now.TouchCount * 8)) 0 (Dev_Now.TouchCount * 8) 
    GT911_WR_Reg GT911_READ_XY_REG #[Clearbuf_] 1

    Dev_Now.Touchkeytrackid[0] = scan_buf_[1];
    Dev_Now.X[0] = (scan_buf_[3] << 8) + scan_buf_[2];
    Dev_Now.Y[0] = (scan_buf_[5] << 8) + scan_buf_[4];
    Dev_Now.S[0] = (scan_buf_[7] << 8) + scan_buf_[6];

    Dev_Now.Touchkeytrackid[1] = scan_buf_[9];
    Dev_Now.X[1] = (scan_buf_[11] << 8) + scan_buf_[10];
    Dev_Now.Y[1] = (scan_buf_[13] << 8) + scan_buf_[12];
    Dev_Now.S[1] = (scan_buf_[15] << 8) + scan_buf_[14];

    Dev_Now.Touchkeytrackid[2] = scan_buf_[17];
    Dev_Now.X[2] = (scan_buf_[19] << 8) + scan_buf_[18];
    Dev_Now.Y[2] = (scan_buf_[21] << 8) + scan_buf_[20];
    Dev_Now.S[2] = (scan_buf_[23] << 8) + scan_buf_[22];

    Dev_Now.Touchkeytrackid[3] = scan_buf_[25];
    Dev_Now.X[3] = (scan_buf_[27] << 8) + scan_buf_[26];
    Dev_Now.Y[3] = (scan_buf_[29] << 8) + scan_buf_[28];
    Dev_Now.S[3] = (scan_buf_[31] << 8) + scan_buf_[30];

    Dev_Now.Touchkeytrackid[4] = scan_buf_[33];
    Dev_Now.X[4] = (scan_buf_[35] << 8) + scan_buf_[34];
    Dev_Now.Y[4] = (scan_buf_[37] << 8) + scan_buf_[36];
    Dev_Now.S[4] = (scan_buf_[39] << 8) + scan_buf_[38];

    for i := 0; i < Dev_Backup.TouchCount; i++:      
      if Dev_Now.Y[i] < 0: Dev_Now.Y[i] = 0
      if Dev_Now.Y[i] > 480: Dev_Now.Y[i] = 480
      if Dev_Now.X[i] < 0: Dev_Now.X[i] = 0
      if Dev_Now.X[i] > 320: Dev_Now.X[i] = 320

    for i := 0; i < Dev_Now.TouchCount; i++:
      if Dev_Now.Y[i] < 0: touched = false
      if Dev_Now.Y[i] > 480: touched = false
      if Dev_Now.X[i] < 0: touched = false
      if Dev_Now.X[i] > 320: touched = false

      if touched:
        Dev_Backup.X[i] = Dev_Now.X[i];
        Dev_Backup.Y[i] = Dev_Now.Y[i];
        Dev_Backup.TouchCount = Dev_Now.TouchCount;
    if Dev_Now.TouchCount==0:
          touched = false

gt911_release:
  IIC_SCL.close
  IIC_SDA.close
  IIC_RST.close


gt911_int:
  buf := ByteArray 4;
  CFG_TBL := ByteArray 184;
  
  IIC_SDA.configure --output
  IIC_SCL.configure --output
  IIC_RST.configure --output
  
  sleep --ms=50;
  IIC_RST.set LOW

  sleep --ms=10
  IIC_RST.set HIGH
  sleep --ms=50

  buf = GT911_RD_Reg 0X8140 4
  print "TouchPad_ID:$(%d buf[0]),$(%d buf[1]),$(%d buf[2])\r\n"
  buf[0] = 0x02;

  GT911_WR_Reg GT_CTRL_REG buf 1
  buf[0] = (GT911_RD_Reg GT_CFGS_REG 1)[0]
  print "Default Ver:0x$(%X buf[0])\r\n"
  if buf[0] < 0X60:
    print "Default Ver:0x$(%X buf[0])\r\n"
    GT911_Send_Cfg 1
  
  CFG_TBL = GT911_RD_Reg GT_CFGS_REG 184

  sleep --ms=10
  buf[0] = 0x00;
  GT911_WR_Reg GT_CTRL_REG buf 1

class Coordinate:
  // x: X axis coordinate.
  // y: Y axis coordinate.
  // s: Touch screen status, true -> touched, false -> untouched.
  x /int := 0
  y /int := 0
  s /bool := false

  // We don't need to specify the type for constructor
  // arguments that are written directly to a typed field.
  constructor .x .y .s:

coordinate ::= Coordinate 0 0 false
coordinates x/int y/int s/bool -> Coordinate:
  coordinate.x = x
  coordinate.y = y
  coordinate.s = s
  return coordinate

get_coords -> Coordinate:
  if not SIMULATE:
    GT911_Scan

  return coordinates (480 - Dev_Now.Y[0]) (Dev_Now.X[0]) touched
