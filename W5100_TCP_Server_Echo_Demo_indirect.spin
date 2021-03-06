''**************************************
''
''  Brilldea W5100 TCP Server Echo Demo indirect Ver. 00.1
''
''  Timothy D. Swieter, P.E.
''  Brilldea - purveyor of prototyping goods
''  www.brilldea.com
''
''  Copyright (c) 2010 Timothy D. Swieter, P.E.
''  See end of file for terms of use and MIT License
''
''  Updated: June 26, 2010
''
''Description:
''
''      This is a TCP server echoing demo driver for the W5100. This program will
''      use the Indirect driver.
''
''      To use this program you will need a terminal program, perhaps the Parallax Serial Terminal.
''      You will also need a tool to establish TCP/sockets and send pacakets, we used TCP Test Tool 2.3 by Simple Com Tools (wwww.simplecomtools.com)
''
''      Before using this program review the network settings listed into the program (mac ID, gateway, subnet, IP adresses)
''
''      Have the terminal program open and ready, then load this program to the device or reset the device.
''      Status of the W5100 initializing will be displayed.  Eventually the program will
''      initialize a TCP server waiting for connection. The user (you) should establish a connection and send TCP data
''      packets to the IP address/socket that the device was initialized with. The device will
''      then acknowledge receipt of the packet and send it back to the user. 
''
''Reference:
''
''To do:
''
''Revision Notes:
'' 0.1 Start of design based on UDP demo
''
''  Original file Brilldea_W5100_TCP_Server_Echo_Demo_indirect_Ver001.spin -
''  added to version control repository on January 5, 2011
''
''**************************************
CON               'Constants to be located here
'***************************************                       
  '***************************************
  ' Firmware Version
  '***************************************
  FWmajor       = 0
  FWminor       = 1

DAT
  TxtFWdate   byte "June 26, 2010",0
  
CON

  '***************************************
  ' Processor Settings
  '***************************************
  _clkmode = xtal1 + pll16x     'Use the PLL to multiple the external clock by 16
  _xinfreq = 5_000_000          'An external clock of 5MHz. is used (80MHz. operation)

  '***************************************
  ' System Definitions     
  '***************************************

  _OUTPUT       = 1             'Sets pin to output in DIRA register
  _INPUT        = 0             'Sets pin to input in DIRA register  
  _HIGH         = 1             'High=ON=1=3.3V DC
  _ON           = 1
  _LOW          = 0             'Low=OFF=0=0V DC
  _OFF          = 0
  _ENABLE       = 1             'Enable (turn on) function/mode
  _DISABLE      = 0             'Disable (turn off) function/mode

{
  '***************************************
  ' I/O Definitions of PropNET Module
  '***************************************

  '~~~~Propeller Based I/O~~~~
  'W5100 Module Interface
  _WIZ_data0    = 0             'SPI Mode = MISO, Indirect Mode = data bit 0.
  _WIZ_miso     = 0
  _WIZ_data1    = 1             'SPI Mode = MOSI, Indirect Mode = data bit 1.
  _WIZ_mosi     = 1
  _WIZ_data2    = 2             'SPI Mode unused, Indirect Mode = data bit 2 dependent on solder jumper on board.
  _WIZ_data3    = 3             'SPI Mode = SCLK, Indirect Mode = data bit 3.
  _WIZ_sclk     = 3
  _WIZ_data4    = 4             'SPI Mode unused, Indirect Mode = data bit 4 dependent on solder jumper on board.
  _WIZ_data5    = 5             'SPI Mode unused, Indirect Mode = data bit 5 dependent on solder jumper on board.
  _WIZ_data6    = 6             'SPI Mode unused, Indirect Mode = data bit 6 dependent on solder jumper on board.
  _WIZ_data7    = 7             'SPI Mode unused, Indirect Mode = data bit 7 dependent on solder jumper on board.
  _WIZ_addr0    = 8             'SPI Mode unused, Indirect Mode = address bit 0 dependent on solder jumper on board.
  _WIZ_addr1    = 9             'SPI Mode unused, Indirect Mode = address bit 1 dependent on solder jumper on board.
  _WIZ_wr       = 10            'SPI Mode unused, Indirect Mode = /write dependent on solder jumper on board.
  _WIZ_rd       = 11            'SPI Mode unused, Indirect Mode = /read dependent on solder jumper on board.
  _WIZ_cs       = 12            'SPI Mode unused, Indirect Mode = /chip select dependent on solder jumper on board.
  _WIZ_int      = 13            'W5100 /interrupt dependent on solder jumper on board.  Shared with _OW.
  _WIZ_rst      = 14            'W5100 chip reset.
  _WIZ_scs      = 15            'SPI Mode SPI Slave Select, Indirect Mode unused dependent on solder jumper on board.

  'I2C Interface
  _I2C_scl      = 28            'Output for the I2C serial clock
  _I2C_sda      = 29            'Input/output for the I2C serial data  

  'Serial/Programming Interface (via Prop Plug Header)
  _SERIAL_tx    = 30            'Output for sending misc. serial communications via a Prop Plug
  _SERIAL_rx    = 31            'Input for receiving misc. serial communications via a Prop Plug
}
  '***************************************
  ' I/O Definitions of Spinneret Web Server Module
  '***************************************

  '~~~~Propeller Based I/O~~~~
  'W5100 Module Interface
  _WIZ_data0    = 0             'SPI Mode = MISO, Indirect Mode = data bit 0.
  _WIZ_miso     = 0
  _WIZ_data1    = 1             'SPI Mode = MOSI, Indirect Mode = data bit 1.
  _WIZ_mosi     = 1
  _WIZ_data2    = 2             'SPI Mode SPI Slave Select, Indirect Mode = data bit 2
  _WIZ_scs      = 2             
  _WIZ_data3    = 3             'SPI Mode = SCLK, Indirect Mode = data bit 3.
  _WIZ_sclk     = 3
  _WIZ_data4    = 4             'SPI Mode unused, Indirect Mode = data bit 4 
  _WIZ_data5    = 5             'SPI Mode unused, Indirect Mode = data bit 5 
  _WIZ_data6    = 6             'SPI Mode unused, Indirect Mode = data bit 6 
  _WIZ_data7    = 7             'SPI Mode unused, Indirect Mode = data bit 7 
  _WIZ_addr0    = 8             'SPI Mode unused, Indirect Mode = address bit 0 
  _WIZ_addr1    = 9             'SPI Mode unused, Indirect Mode = address bit 1 
  _WIZ_wr       = 10            'SPI Mode unused, Indirect Mode = /write 
  _WIZ_rd       = 11            'SPI Mode unused, Indirect Mode = /read 
  _WIZ_cs       = 12            'SPI Mode unused, Indirect Mode = /chip select 
  _WIZ_int      = 13            'W5100 /interrupt
  _WIZ_rst      = 14            'W5100 chip reset
  _WIZ_sen      = 15            'W5100 low = indirect mode, high = SPI mode, floating will = high.

  _DAT0         = 16
  _DAT1         = 17
  _DAT2         = 18
  _DAT3         = 19
  _CMD          = 20
  _SD_CLK       = 21
  
  _SIO          = 22            

  _LED          = 26            'UI - combo LED and buttuon
  
  _AUX0         = 24            'MOBO Interface
  _AUX1         = 25
  _AUX2         = 26
  _AUX3         = 27

  'I2C Interface
  _I2C_scl      = 28            'Output for the I2C serial clock
  _I2C_sda      = 29            'Input/output for the I2C serial data  

  'Serial/Programming Interface (via Prop Plug Header)
  _SERIAL_tx    = 30            'Output for sending misc. serial communications via a Prop Plug
  _SERIAL_rx    = 31            'Input for receiving misc. serial communications via a Prop Plug

  '***************************************
  ' I2C Definitions
  '***************************************
  _EEPROM0_address = $A0        'Slave address of EEPROM

  '***************************************
  ' Debugging Definitions
  '***************************************
  
  '***************************************
  ' Misc Definitions
  '***************************************
  
  _bytebuffersize = 2048

'**************************************
VAR               'Variables to be located here
'***************************************

  'Configuration variables for the W5100
  byte  MAC[6]                  '6 element array contianing MAC or source hardware address ex. "02:00:00:01:23:45"
  byte  Gateway[4]              '4 element array containing gateway address ex. "192.168.0.1"
  byte  Subnet[4]               '4 element array contianing subnet mask ex. "255.255.255.0"
  byte  IP[4]                   '4 element array containing IP address ex. "192.168.0.13"

  'verify variables for the W5100
  byte  vMAC[6]                 '6 element array contianing MAC or source hardware address ex. "02:00:00:01:23:45"
  byte  vGateway[4]             '4 element array containing gateway address ex. "192.168.0.1"
  byte  vSubnet[4]              '4 element array contianing subnet mask ex. "255.255.255.0"
  byte  vIP[4]                  '4 element array containing IP address ex. "192.168.0.13"

  long  socket                  '1 element for the socket number

  'Variables to info for where to return the data to
  byte  destIP[4]               '4 element array containing IP address ex. "192.168.0.16"

  'Misc variables
  byte  data[_bytebuffersize]
  long  stack[50]
  
'***************************************
OBJ               'Object declaration to be located here
'***************************************

  'Choose which driver to use by commenting/uncommenting the driver.  Only one can be chosen.
  ETHERNET      : "W5100_Indirect_Driver.spin"

  'The serial terminal to use  
  PST           : "Parallax Serial Terminal.spin"       'A terminal object created by Parallax, used for debugging

'***************************************
PUB main | temp0, temp1, temp2
'***************************************
''  First routine to be executed in the program
''  because it is first PUB in the file

  PauseMSec(2_000)              'A small delay to allow time to switch to the terminal application after loading the device

  '**************************************
  ' Start the processes in their cogs
  '**************************************

  'Start the terminal application
  'The terminal operates at 115,200 BAUD on the USB/COM Port the Prop Plug is attached to
  PST.Start(115_200)

  'Start the W5100 driver
  ETHERNET.StartINDIRECT(_WIZ_data0, _WIZ_addr0, _WIZ_addr1, _WIZ_cs, _WIZ_rd, _WIZ_wr,  _WIZ_rst, _WIZ_sen)

  '**************************************
  ' Initialize the variables
  '**************************************

  'The following variables can be adjusted by the demo user to fit in their particular network application.
  'Note the MAC ID is a locally administered address.   See Wikipedia MAC_Address 
  
  'MAC ID to be assigned to W5100
  MAC[0] := $02
  MAC[1] := $00
  MAC[2] := $00
  MAC[3] := $01
  MAC[4] := $23
  MAC[5] := $45

  'Subnet address to be assigned to W5100
  Subnet[0] := 255
  Subnet[1] := 255
  Subnet[2] := 255
  Subnet[3] := 0

  'IP address to be assigned to W5100
  IP[0] := 192
  IP[1] := 168
  IP[2] := 10
  IP[3] := 75

  'Gateway address of the system network
  Gateway[0] := 192
  Gateway[1] := 168
  Gateway[2] := 10
  Gateway[3] := 1

  'Local socket
  socket := 5000 

  'Destination IP address - can be left zeros, the TCO demo echoes to computer that sent the packet
  destIP[0] := 0
  destIP[1] := 0
  destIP[2] := 0
  destIP[3] := 0
  
  '**************************************
  ' Begin
  '**************************************

  'Clear the terminal screen
  PST.Home
  PST.Clear
   
  'Draw the title bar
  PST.Str(string("    W5100 Indirect Driver Test ", PST#NL))
  PST.Str(string("         TCP Server Demo", PST#NL, PST#NL))

  'Set the W5100 addresses
  PST.Str(string("Initialize all addresses...  ", PST#NL))  
  SetVerifyMAC(@MAC[0])
  SetVerifyGateway(@Gateway[0])
  SetVerifySubnet(@Subnet[0])
  SetVerifyIP(@IP[0])

  'Initialize the socket memory, only needs to be done if the non-default is to be used.
  ETHERNET.InitSocketMem(3)
  PST.Str(string("Socket Memory size initialized", PST#NL, PST#NL))

  'Addresses should now be set and displayed in the terminal window.
  'Next initialize Socket 0 for being the TCP server

  PST.Str(string("Initialize socket 0, port "))
  PST.dec(socket)
  PST.Str(string(PST#NL))

  'Testing Socket 0's status register and display information
  PST.Str(string("Socket 0 Status Register: "))
  ETHERNET.readIND(ETHERNET#_S0_SR, @temp0, 1)

  case temp0
    ETHERNET#_SOCK_CLOSED : PST.Str(string("$00 - socket closed", PST#NL, PST#NL))
    ETHERNET#_SOCK_INIT   : PST.Str(string("$13 - socket initalized", PST#NL, PST#NL))
    ETHERNET#_SOCK_LISTEN : PST.Str(string("$14 - socket listening", PST#NL, PST#NL))
    ETHERNET#_SOCK_ESTAB  : PST.Str(string("$17 - socket established", PST#NL, PST#NL))    
    ETHERNET#_SOCK_UDP    : PST.Str(string("$22 - socket UDP open", PST#NL, PST#NL))

  'Try opening a socket using a ASM method
  PST.Str(string("Attempting to open TCP on socket 0, port "))
  PST.dec(socket)
  PST.Str(string("...", PST#NL))
  
  ETHERNET.SocketOpen(0, ETHERNET#_TCPPROTO, socket, socket, @destIP[0])

  'Wait a moment for the socket to get established
  PauseMSec(500)

  'Testing Socket 0's status register and display information
  PST.Str(string("Socket 0 Status Register: "))
  ETHERNET.readIND(ETHERNET#_S0_SR, @temp0, 1)

  case temp0
    ETHERNET#_SOCK_CLOSED : PST.Str(string("$00 - socket closed", PST#NL, PST#NL))
    ETHERNET#_SOCK_INIT   : PST.Str(string("$13 - socket initalized/opened", PST#NL, PST#NL))
    ETHERNET#_SOCK_LISTEN : PST.Str(string("$14 - socket listening", PST#NL, PST#NL))
    ETHERNET#_SOCK_ESTAB  : PST.Str(string("$17 - socket established", PST#NL, PST#NL))    
    ETHERNET#_SOCK_UDP    : PST.Str(string("$22 - socket UDP open", PST#NL, PST#NL))

  'Try setting up a listen on the TCP socket
  PST.Str(string("Setting TCP on socket 0, port "))
  PST.dec(socket)
  PST.Str(string(" to listening", PST#NL))

  ETHERNET.SocketTCPlisten(0)

  'Wait a moment for the socket to listen
  PauseMSec(500)

  'Testing Socket 0's status register and display information
  PST.Str(string("Socket 0 Status Register: "))
  ETHERNET.readIND(ETHERNET#_S0_SR, @temp0, 1)

  case temp0
    ETHERNET#_SOCK_CLOSED : PST.Str(string("$00 - socket closed", PST#NL, PST#NL))
    ETHERNET#_SOCK_INIT   : PST.Str(string("$13 - socket initalized", PST#NL, PST#NL))
    ETHERNET#_SOCK_LISTEN : PST.Str(string("$14 - socket listening", PST#NL, PST#NL))
    ETHERNET#_SOCK_ESTAB  : PST.Str(string("$17 - socket established", PST#NL, PST#NL))    
    ETHERNET#_SOCK_UDP    : PST.Str(string("$22 - socket UDP open", PST#NL, PST#NL))

  'Infinite loop of the server
  repeat

    'Waiting for a client to connect
    PST.Str(string("Waiting for a client to connect....", PST#NL))

    'Testing Socket 0's status register and looking for a client to connect to our server
    repeat while !ETHERNET.SocketTCPestablished(0)

    'Connection established
    PST.Str(string("connection established, send TCP packet to be echoed", PST#NL))

    temp0 := 0
    bytefill(@data, 0, _bytebuffersize)

    repeat while ETHERNET.SocketTCPestablished(0)

      PST.Str(string("Waiting to receive...."))

      repeat until temp0 := ETHERNET.rxTCP(0, @data[0])
        ifnot ETHERNET.SocketTCPestablished(0)
          quit

      ifnot ETHERNET.SocketTCPestablished(0)
        PST.Str(string(PST#NL))
        quit
          
      PST.Str(string("received "))
      PST.dec(temp0)
      PST.Str(string(" bytes and echoing...."))
      
      ETHERNET.txTCP(0, @data[0], temp0)
      PST.Str(string("sent", PST#NL))

    'Connection terminated
    PST.Str(string("Connection disconnected", PST#NL, PST#NL))
    ETHERNET.SocketClose(0)

    'Once the connection is closed, need to open socket again
    OpenSocketAgain
    
  return 'end of main
  
'***************************************
PRI SetVerifyMAC(_firstOctet)
'***************************************

  'Set the MAC ID and display it in the terminal
  ETHERNET.WriteMACaddress(true, _firstOctet)

  
  PST.Str(string("  Set MAC ID........"))
  PST.hex(byte[_firstOctet + 0], 2)
  PST.Str(string(":"))
  PST.hex(byte[_firstOctet + 1], 2)
  PST.Str(string(":"))
  PST.hex(byte[_firstOctet + 2], 2)
  PST.Str(string(":"))
  PST.hex(byte[_firstOctet + 3], 2)
  PST.Str(string(":"))
  PST.hex(byte[_firstOctet + 4], 2)
  PST.Str(string(":"))
  PST.hex(byte[_firstOctet + 5], 2)
  PST.Str(string(PST#NL))

  'Wait a moment
  PauseMSec(500)
 
  ETHERNET.ReadMACAddress(@vMAC[0])
  
  PST.Str(string("  Verified MAC ID..."))
  PST.hex(vMAC[0], 2)
  PST.Str(string(":"))
  PST.hex(vMAC[1], 2)
  PST.Str(string(":"))
  PST.hex(vMAC[2], 2)
  PST.Str(string(":"))
  PST.hex(vMAC[3], 2)
  PST.Str(string(":"))
  PST.hex(vMAC[4], 2)
  PST.Str(string(":"))
  PST.hex(vMAC[5], 2)
  PST.Str(string(PST#NL))
  PST.Str(string(PST#NL))

  return 'end of SetVerifyMAC

'***************************************
PRI SetVerifyGateway(_firstOctet)
'***************************************

  'Set the Gatway address and display it in the terminal
  ETHERNET.WriteGatewayAddress(true, _firstOctet)

  PST.Str(string("  Set Gateway....."))
  PST.dec(byte[_firstOctet + 0])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 1])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 2])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 3])
  PST.Str(string(PST#NL))

  'Wait a moment
  PauseMSec(500)

  ETHERNET.ReadGatewayAddress(@vGATEWAY[0])
  
  PST.Str(string("  Verified Gateway.."))
  PST.dec(vGATEWAY[0])
  PST.Str(string("."))
  PST.dec(vGATEWAY[1])
  PST.Str(string("."))
  PST.dec(vGATEWAY[2])
  PST.Str(string("."))
  PST.dec(vGATEWAY[3])
  PST.Str(string(PST#NL))
  PST.Str(string(PST#NL))

  return 'end of SetVerifyGateway

'***************************************
PRI SetVerifySubnet(_firstOctet)
'***************************************

  'Set the Subnet address and display it in the terminal
  ETHERNET.WriteSubnetMask(true, _firstOctet)

  PST.Str(string("  Set Subnet......"))
  PST.dec(byte[_firstOctet + 0])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 1])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 2])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 3])
  PST.Str(string(PST#NL))

  'Wait a moment
  PauseMSec(500)

  ETHERNET.ReadSubnetMask(@vSUBNET[0])
  
  PST.Str(string("  Verified Subnet..."))
  PST.dec(vSUBNET[0])
  PST.Str(string("."))
  PST.dec(vSUBNET[1])
  PST.Str(string("."))
  PST.dec(vSUBNET[2])
  PST.Str(string("."))
  PST.dec(vSUBNET[3])
  PST.Str(string(PST#NL))
  PST.Str(string(PST#NL))

  return 'end of SetVerifySubnet

'***************************************
PRI SetVerifyIP(_firstOctet)
'***************************************

  'Set the IP address and display it in the terminal
  ETHERNET.WriteIPAddress(true, _firstOctet)

  PST.Str(string("  Set IP.........."))
  PST.dec(byte[_firstOctet + 0])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 1])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 2])
  PST.Str(string("."))
  PST.dec(byte[_firstOctet + 3])
  PST.Str(string(PST#NL))

  'Wait a moment
  PauseMSec(500)

  ETHERNET.ReadIPAddress(@vIP[0])
  
  PST.Str(string("  Verified IP......."))
  PST.dec(vIP[0])
  PST.Str(string("."))
  PST.dec(vIP[1])
  PST.Str(string("."))
  PST.dec(vIP[2])
  PST.Str(string("."))
  PST.dec(vIP[3])
  PST.Str(string(PST#NL))
  PST.Str(string(PST#NL))

  return 'end of SetVerifyIP

'***************************************
PRI OpenSocketAgain
'***************************************

  ETHERNET.SocketOpen(0, ETHERNET#_TCPPROTO, socket, socket, @destIP[0])
  ETHERNET.SocketTCPlisten(0)

  return 'end of OpenSocketAgain
  
'***************************************
PRI PauseMSec(Duration)
'***************************************
''  Pause execution for specified milliseconds.
''  This routine is based on the set clock frequency.
''  
''  params:  Duration = number of milliseconds to delay                                                                                               
''  return:  none
  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)

  return  'end of PauseMSec

'***************************************
DAT
'***************************************         

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}