{{
───────────────────────────────────────────────── 
Copyright (c) 2011 AgaveRobotics LLC.
See end of file for terms of use.

File....... HTTPServer.spin 
Author..... Mike Gebhard
Company.... Agave Robotics LLC
Email...... mailto:mike.gebhard@agaverobotics.com
Started.... 11/01/2010
Updated.... 08/06/2011        
───────────────────────────────────────────────── 
}}

{
About:
  HTTPServer is the designed for use with the Spinneret Web server manufactured
  by Parallax Inc.

Usage:
  HTTPServer is the top level object.
  Required objects:
        • Parallax Serial Terminal.spin
        • W5100_Indirect_Driver.spin
        • S35390A_SD-MMC_FATEngineWrapper.spin
        • Request.spin
        • Response.spin
        • StringMethods.spin
        • S35390A_RTCEngine.spin 

Change Log:
 Added Beau's SNTP code - 08/06/2011 
}


CON
  _clkmode = xtal1 + pll16x     
  _xinfreq = 5_000_000

  MAX_PACKET_SIZE = $5C0 '1472   '$800 = 2048
  RxTx_BUFFER     = $600         '$600 = 1536
  TEMP_BUFFER     = $300         '$5B4 = 1460 
  TCP_PROTOCOL    = %0001        '$300 = 768 
  UDP_PROTOCOL    = %0010        '$200 = 512 
  TCP_CONNECT     = $04          '$100 = 256                 
  DELAY           = $05
  MAX_TRIES       = $05                   

  'note
  #1, ErrorConnect, ErrorVersion, ErrorChecksum, ErrorProgram, ErrorVerify
  #0, Shutdown, LoadRun, ProgramShutdown, ProgramRun
  #0, DONE, PUT, CD

      'USA Standard Time Zone Abbreviations
  #-10, HST,AtST,_PST,MST,CST,EST,AlST
  # -1, GMT {Day light saving time, we don't have dyalight savings time in AZ}

              
    'USA Daylight Time Zone Abbreviations     <-  No longer used in v1.1
  '#-9, HDT,AtDT,PDT,MDT,CDT,EDT,AlDT

  Zone = GMT  '<- Eastern Standard Time =  GMT-5

    'W5100 Interface
   #0, W5100_DATA0, W5100_DATA1, W5100_DATA2, W5100_DATA3, W5100_DATA4
   #5, W5100_DATA5, W5100_DATA6, W5100_DATA7, W5100_ADDR0, W5100_ADDR1
  #10, W5100_WR, W5100_RD, W5100_CS, W5100_INT, W5100_RST, W5100_SEN

                                           

DAT                             
  mac                   byte    $00, $08, $DC, $16, $F1, $32 {$EF, $22 or $F1, $32}   
  subnet                byte    255, 255 ,255, 0
  gateway               byte    192, 168, 1, 1 
  ip                    byte    192, 168, 1, 122 {120  or 122}
  sntpIp                byte    69, 25, 96, 13 {San Jose CA}
  port                  word    5000
  port2                 word    5010 
  remoteIp              byte    65, 98, 8, 151 {65.98.8.151}
  remotePort            word    80
  uport                 word    5050 
  emailIp               byte    68, 6, 19, 4
  emailPort             word    25
  sntpPort              word    123
  status                byte    $00, $00, $00, $00   
  rxdata                byte    $0[RxTx_BUFFER]
  txdata                byte    $0[RxTx_BUFFER]
  tempBuff              byte    $0[TEMP_BUFFER]
  fileErrorHandle       long    $0
  debug                 byte    $0
  lastFile              byte    $0[12], 0
  closedState           byte    %0000
  openState             byte    %0000
  listenState           byte    %0000
  establishedState      byte    %0000
  closingState          byte    %0000
  closeWaitState        byte    %0000 
  lastEstblState        byte    %0000
  lastEstblStateDebug   byte    %0000
  udpListen             byte    %0000
  tcpMask               byte    %1111
  udpMask               byte    %0000   
  fifoSocketDepth       byte    $0
  fifoSocket            long    $00_00_00_00
  debugSemId            byte    $00
  debugCounter          long    $00
  stringMethods         long    $00
  closingTimeout        long    $00, $00, $00, $00
  udpLen                long    $00
  time                  byte    "00/00/0000 00:00:00", 0
  httpDate              byte    "Wed, 01 Feb 2000 01:00:00 GMT", 0
  globalCache           byte    $0
  dynamicContentPtr     long    @txdata

                 
VAR
  long StackSpace[20]
  long P31, P30, LFSR, Ver, Echo  'note
  long  longHIGH,longLOW,MM_DD_YYYY,DW_HH_MM_SS 'Expected 4-contigous variables 

OBJ
  pst           : "Parallax Serial Terminal"
  Socket        : "W5100_Indirect_Driver"
  SDCard        : "S35390A_SD-MMC_FATEngineWrapper"
  Request       : "Request"
  Response      : "Response"
  str           : "StringMethods"
  rtc           : "S35390A_RTCEngine"
  sntp          : "SNTP Simple Network Time Protocol v1.1"


PUB Initialize | id, size, st

  debug := 1    
  SDCard.Start
  stringMethods := str.Start
  Request.Constructor(stringMethods)
  Response.Constructor(stringMethods, @txdata)

  pst.Start(115_200)
  pause(200) 

  'Mount the SD card
  pst.str(string("Mount SD Card - ")) 
  SDCard.mount(fileErrorHandle)
  pst.str(string("OK",13))
  
  pst.str(string("Start RTC: "))
  rtc.RTCEngineStart(29, 28, -1)
  
  pause(200)
  pst.str(FillTime)
    
  'Start the W5100 driver
  if(Socket.Start)
    pst.str(string(13, "W5100 Driver Started", 13))
    pst.str(string(13, "Status Memory Lock ID    : "))
    pst.dec(Socket.GetLockId)
    pst.char(13) 


  if(debugSemId := locknew) == -1
    pst.str(string("Error, no HTTP server locks available", 13))
  else
    pst.str(string("HTTP Server Lock ID      : "))
    pst.dec(debugSemId)
    pst.char(13)
    

  'Set the Socket addresses  
  SetMac(@mac)
  SetGateway(@gateway)
  SetSubnet(@subnet)
  SetIP(@ip)

  ' Initailize TCP sockets (defalut setting; TCP, Port, remote ip and remote port)
  repeat id from 0 to 3
    InitializeSocket(id)
    Request.Release(id)
    pause(50)

  ' Set all TCP sockets to listen
  pst.char(13) 
  repeat id from 0 to 3 
    Socket.Listen(id)
    pst.str(string("TCP Socket Listener ID   : "))
    pst.dec(id)
    pst.char(13)
    pause(50)

  pst.Str(string(13,"Started Socket Monitoring Service", 13))
 
  cognew(StatusMonitor, @StackSpace)
  pause(250)


  pst.Str(string(13, "Initial Socket States",13))
  StackDump

  pst.Str(string(13, "Initial Socket Queue",13))
  QueueDump

  pst.str(string(13,"//////////////////////////////////////////////////////////////",13))

  debugCounter := 4545
  
  Main

   
PUB Main | packetSize, id, i, reset, j, temp
  '' HTTP Service
  'GetSntp(3)
  repeat
  
    repeat until fifoSocket == 0
      SDCard.changeDirectory(@approot)
      bytefill(@rxdata, 0, RxTx_BUFFER)

      if(debug)
        pst.str(string(13, "----- Start of Request----------------------------",13))
        QueueDump
      else
        pause(DELAY)
        
      ' Pop the next socket handle 
      id := DequeueSocket
      if(id < 0)
        pst.str(string(13,"Id < 0"))
        pst.dec(id)                                  
        pst.char(13)
        next
      
      if(debug)
        pst.str(string(13,"ID: "))
        pst.dec(id)
        pst.str(string(13, "Request Count     : "))
        pst.dec(debugCounter)

      packetSize := Socket.rxTCP(id, @rxdata)

     {  } 
      reset := false
      if ((packetSize < 12) AND (strsize(@rxdata) < 12))
        repeat i from 0 to MAX_TRIES
           'pst.str(string(13,"* Retry *"))
          'Wait for a few moments and try again
          waitcnt((clkfreq/500) + cnt)
          packetSize := Socket.rxTCP(id, @rxdata)
          if(packetSize > 12)
            quit
          if(i == MAX_TRIES)
            'Clean up resource request   
            Request.Release(id)
            Socket.Disconnect(id)
            reset := true
            if(debug)
              StackDump
              pst.char(13)
              QueueDump
              pst.str(string(13,"* Timeout *",13))
            
      if(reset)
        next
     
      Request.InitializeRequest(id, @rxdata)
      
      if(debug)
        pst.char(13)
        HeaderLine1(id)
        StackDump
        pst.char(13)
        QueueDump
      else
        pause(DELAY)

      ' Process router
      Dispatcher(id)

      'Clean up request resource
      Request.Release(id)

      ' This starts the close process -> 0x00
      ' use close to force a close
      Socket.Disconnect(id)
      
      bytefill(@txdata, 0, RxTx_BUFFER)

      debugCounter++
      

  GotoMain

PRI GotoMain
  Main

 
PRI Dispatcher(id)
'' HTTP request handler
   
  ' The RESTful command is in the root location
  if(strcomp(Request.GetPathNode(id, 0), string("led")))
    RestLed(id)
    return

  ' XML time
  if(strcomp(Request.GetPathNode(id, 0), string("xmltime")))
    XmlTime(id)
    return

  if(strcomp(Request.GetPathNode(id, 0), string("pagecnt")))
    PageCount(id)
    return

  if(strcomp(Request.GetPathNode(id, 0), string("getsntp")))
    'GetSntp(3)
    XmlTime(id)
    return

  ' Send requested file content
  StaticFileHandler(id)
  return

PRI GetSntp(id) | tempMask

    pst.str(string(13, "GET SNTP Time"))
    tempMask := tcpMask
    SetTcpSocketMaskById(id, 0)
    
       
    Socket.Close(id)
    pause(delay)
    pst.str(string(13, "Initialize UDP Socket"))
    InitializeSntpUdpSocket(id)
    pause(delay)

    pst.str(string(13, "Request Time"))
    if GetSntpTime(id, @tempBuff)
'                        Decode 64-Bit time from server           
'≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈       
          sntp.GetTransmitTimestamp(Zone,@tempBuff,@LongHIGH,@LongLOW)

'               Display Reference/Sync TimeZone corrected Time           
'≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈       
          'DisplayHumanTime

'                         Set RTC to Internet Time
         pst.str(string(13, "SET RTC"))
'≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
         {{ rtc.SetDateTime(byte[@MM_DD_YYYY][3],   { <- Month 
                        } byte[@MM_DD_YYYY][2],   { <- Day 
                        } word[@MM_DD_YYYY][0]-2000,   { <- Year 
                        } byte[@DW_HH_MM_SS][3],  { <- (day of week)
                        } byte[@DW_HH_MM_SS][2],  { <- Hour
                        } byte[@DW_HH_MM_SS][1],  { <- Minutes
                        } byte[@DW_HH_MM_SS][0])  { <- Seconds }
          }}
          ''PUB writeTime(second, minute, hour, day, date, month, year) 
          rtc.writeTime(byte[@DW_HH_MM_SS][0],        { <- second 
                        } byte[@DW_HH_MM_SS][1],      { <- minute 
                        } byte[@DW_HH_MM_SS][2],      { <- hour 
                        } byte[@DW_HH_MM_SS][3]+2,      { <- (day of week)
                        } byte[@MM_DD_YYYY][2],       { <- date
                        } byte[@MM_DD_YYYY][3],       { <- month
                        } word[@MM_DD_YYYY][0])  { <- year }


    pst.str(string(13, "day: "))
    pst.dec(byte[@DW_HH_MM_SS][3]+2)
    pst.char(13)
    
    pst.str(string(13, "Disconnect and reset socket: "))
    pst.dec(id)
    pst.char(13)
    
    ' Reset the socket
    Socket.Disconnect(id)
    pause(delay)

    'Socket.SocketClose(id)
    'pause(delay)
    
    ' Reset the tcpMask 
    tcpMask := tempMask
    
    InitializeSocket(id)
    pause(delay)
    
    return


PUB GetSntpTime(id, BufferAddress)|i
    sntp.CreateUDPtimeheader(BufferAddress,@sntpIp)
    Socket.txUDP(id, BufferAddress) '<-- Send the UDP packet
    
    repeat 100
      i := Socket.rxUDP(id, BufferAddress)  
      if i == 56
         return 1                  
      Pause(100) '<- if 1000 = 1 sec ; 10 = 1/100th sec X 100 repeats above = 1 sec   
    return 0                       '<- Timed out without a response

PRI ReadStatus(socketNum) : socketStatus
    Socket.readIND((Socket#_S0_SR + (socketNum * $0100)), @socketStatus, 1)

                
PRI RestLed(id) | pin, state, temp, headerLen
'' URL => led\pin\on|off

  ' Get the pin and state
  pin :=  Request.GetPathNode(id, 1)
  state :=  Request.GetPathNode(id, 2)
  
  ' Convert the ASCII pin number to an integer
  bytemove(@numBuff, pin, strsize(pin))
  temp := str.ToInteger(@numBuff)
  
  if(temp < 23 OR temp > 27)
    temp := 23 
  
  if (strcomp(string("on"), state ))
    PinState(temp, 1)
  else
    PinState(temp, 0)
    
  bytefill(@numBuff, 0, strsize(pin))

  dynamicContentPtr := @tempBuff
  PushDynamicContent(@xmlencode)
  PushDynamicContent(string("<root application='multisocket'><led id='"))
  PushDynamicContent(pin)
  PushDynamicContent(string("'><![CDATA["))
  PushDynamicContent(state)
  PushDynamicContent(string("]]></led></root>"))
    
  ' Build and send the header
  ' Send the value of led= on or off
  headerLen := Response.BuildHeader(string("xml"), 200, false)
  Socket.txTCP(id, @txdata, headerLen)
  StringSend(id, @tempBuff)

  bytefill(@tempBuff, 0, TEMP_BUFFER)
  
  return

PRI XmlTime(id) | headerOffset
    dynamicContentPtr := @tempBuff

    FillHttpDate
    
    PushDynamicContent(@xmlencode)
    PushDynamicContent(string("<root application='multisocket'><time><![CDATA["))
    PushDynamicContent(@httpDate)
    PushDynamicContent(string("]]></time></root>"))
    
    ' Write the header and XML body
    headerOffset := Response.BuildHeader(string("xml"), 200, false)
    Socket.txTCP(id, @txdata, headerOffset)
    StringSend(id, @tempBuff)
    
    bytefill(@tempBuff, 0, TEMP_BUFFER)
    
    return

PRI PageCount(id) | headerOffset, count
    dynamicContentPtr := @tempBuff
    bytefill(@numbuff, 0 ,10)
 
    PushDynamicContent(@xmlencode)
    PushDynamicContent(string("<root application='multisocket'><pageCount><![CDATA["))
    PushDynamicContent(str.ToString(@debugCounter, @numbuff))
    PushDynamicContent(string("]]></pageCount></root>"))
    
    ' Write the header and XML body
    headerOffset := Response.BuildHeader(string("xml"), 200, false)
    Socket.txTCP(id, @txdata, headerOffset)
    StringSend(id, @tempBuff)
    
    bytefill(@tempBuff, 0, TEMP_BUFFER)
    bytefill(@numbuff, 0 ,10)
    return
 
PRI PinState(pin, state)
  dira[pin]~~
  outa[pin] := state
  return


PRI StaticFileHandler(id) | fileSize, i, headerLen, temp, j
  ''Serve up static files from the SDCard
  
  'pst.str(string(13,"Static File Handler",13)) 
  SDCard.changeDirectory(@approot)
  pst.char(13)
  
  'Make sure the directory exists
  ifnot(ChangeDirectory(id))
    'send 404 error
    WriteError(id)
    SDCard.changeDirectory(@approot)
    return
    
  ' Make sure the file exists
  ifnot(FileExists(Request.GetFileName(id)))
    'send 404 error
    WriteError(id)
    SDCard.changeDirectory(@approot)
    return

  ' Open the file for reading
  SDCard.openFile(Request.GetFileName(id), "r")
  fileSize := SDCard.getFileSize

  'WriteResponseHeader(id)
  'BuildHeader(extension, statusCode, expirer)
  headerLen := Response.BuildHeader(Request.GetExtension(id), 200, globalCache)
  Socket.txTCP(id, @txdata, headerLen)
  
  if fileSize < MAX_PACKET_SIZE
    ' send the file in one packet
    SDCard.readFromFile(@txdata, fileSize)
    Socket.txTCP(id, @txdata, fileSize)
  else
    ' send the file in a bunch of packets 
    repeat
      SDCard.readFromFile(@txdata, MAX_PACKET_SIZE)  
      Socket.txTCP(id, @txdata, MAX_PACKET_SIZE)
      fileSize -= MAX_PACKET_SIZE
      ' once the remaining fileSize is less then the max packet size, just send that remaining bit and quit the loop
      if fileSize < MAX_PACKET_SIZE and fileSize > 0
        SDCard.readFromFile(@txdata, fileSize)
        Socket.txTCP(id, @txdata, fileSize)
        quit
   
      ' Bailout
      if(i++ > 1_000_000)
        WriteError(id)
        quit
     
  SDCard.closeFile
  SDCard.changeDirectory(@approot)
  return


  
PRI WriteError(id) | headerOffset
  '' Simple 404 error
  pst.str(string(13, "Write 404 Error",13 ))
  headerOffset := Response.BuildHeader(Request.GetExtension(id), 404, false)
  Socket.txTCP(id, @txdata, headerOffset)
  return


''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Write data to a buffer
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI PushDynamicContent(content)
  ' Write the content to memory
  ' and update the pointer
  bytemove(dynamicContentPtr, content, strsize(content))
  dynamicContentPtr := dynamicContentPtr + strsize(content)
  return

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' directory and file handlers
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''  
PRI ChangeDirectory(id) | i, found
  'Handle directory structure for this Request
  if(Request.GetDepth(id) > 1)
    repeat i from 0 to Request.GetDepth(id)-2
      'Return if the directory is not found
      if(strsize(Request.GetPathNode(id, i)) =< 1)
        return false
      ifnot(FileExists(Request.GetPathNode(id, i)))
        return false
      found := SDCard.changeDirectory(Request.GetPathNode(id, i))
  return true     

  
PRI FileExists(fileToCompare) | filenamePtr
'Start file find at the top of the list
  SDCard.startFindFile 
  'Verify that the file exists
  repeat while filenamePtr <> 0
    filenamePtr := SDCard.nextFile
    if(str.MatchPattern(filenamePtr, fileToCompare, 0, false ) == 0 )
      return true

  return false

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Time Methods and Formats
'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''' 
PRI GetTime(id) | ptr, headerOffset
  dynamicContentPtr := @tempBuff

  '' Place the date in memory
  FillHttpDate
  
  PushDynamicContent(string("<p>"))
  PushDynamicContent(@httpDate)
  PushDynamicContent(string("</p>"))

  '' Write the header and HTML body
  headerOffset := Response.BuildHeader(string("htm"), 200, false)
  Socket.txTCP(id, @txdata, headerOffset)
  StringSend(id, @tempBuff)
 
  bytefill(@tempBuff, 0, TEMP_BUFFER)
  
  return
   
PRI FillTime | ptr, num
 'ToString(integerToConvert, destinationPointer)
 '00/00/0000 00:00:00
  ptr := @time
  rtc.readTime
  

  FillTimeHelper(rtc.clockMonth, ptr)
  ptr += 3

  FillTimeHelper(rtc.clockDate, ptr)
  ptr += 3

  FillTimeHelper(rtc.clockYear, ptr)
  ptr += 5

  FillTimeHelper(rtc.clockHour , ptr)
  ptr += 3

  FillTimeHelper(rtc.clockMinute , ptr)
  ptr += 3

  FillTimeHelper(rtc.clockSecond, ptr) 
 
  return @time


PRI FillHttpDate | ptr, num, temp
 'ToString(integerToConvert, destinationPointer)
 'Wed, 01 Feb 2000 01:00:00 GMT
  ptr := @httpDate
  rtc.readTime


  temp := rtc.getDayString
  bytemove(ptr, temp, strsize(temp))
  ptr += strsize(temp) + 2

  FillTimeHelper(rtc.clockDate, ptr)
  ptr += 3

  temp := rtc.getMonthString
  bytemove(ptr, temp, strsize(temp))
  ptr += strsize(temp) + 1

  FillTimeHelper(rtc.clockYear, ptr)
  ptr += 5

  FillTimeHelper(rtc.clockHour , ptr)
  ptr += 3

  FillTimeHelper(rtc.clockMinute , ptr)
  ptr += 3

  FillTimeHelper(rtc.clockSecond, ptr)
  
  return @httpDate
 

PRI FillTimeHelper(number, ptr) | offset
  offset := 0
  if(number < 10)
    offset := 1
     
  str.ToString(@number, @tempNum)
  bytemove(ptr+offset, @tempNum, strsize(@tempNum))
  

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' SDCard Logger
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI AppendLog(logToAppend)
  '' logToAppend:  Pointer to a string of test we'd like to log
  SDCard.changeDirectory(@approot) 

  if(FileExists(@logfile))
    SDCard.openFile(@logfile, "A")
  else
    SDCard.newFile(@logfile)

  SDCard.writeData(string(13,10,"----- Start "),14)
  SDCard.writeData(FillTime, 19)
  SDCard.writeData(string(" -----"),6)
  SDCard.writeData(@crlf_crlf, 2)

  SDCard.writeData(logToAppend, strsize(logToAppend))
  SDCard.writeData(@crlf_crlf, 2)
  
  SDCard.writeData(string("----- End "),10)
  SDCard.writeData(FillTime, 19)
  SDCard.writeData(string(" -----"),6)
  SDCard.writeData(@crlf_crlf, 2)

  SDCard.closeFile

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Memory Management
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI Set(DestAddress, SrcAddress, Count)
  bytemove(DestAddress, SrcAddress, Count)
  bytefill(DestAddress+Count, $0, 1)
  

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Socekt helpers
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

PRI GetTcpSocketMask(id)
  return id & tcpMask

  
PRI DecodeId(value) | tmp
    if(%0001 & value)
      return 0
    if(%0010 & value)
      return 1
    if(%0100 & value)
      return 2 
    if(%1000 & value)
      return 3
  return -1


PRI QueueSocket(id) | tmp
'' Place a socket ID in the Queue
'' to be processed

  if(fifoSocketDepth > 4)
    return false

  tmp := |< id
  
  'Unique check
  ifnot(IsUnique(tmp))
    return false
    
  tmp <<= (fifoSocketDepth++) * 8
  
  fifoSocket |= tmp

  return true


PRI IsUnique(encodedId) | tmp
  tmp := encodedId & $0F
  repeat 4
    if(encodedId & fifoSocket)
      return false
    encodedId <<= 8
  return true 
    

PRI DequeueSocket | tmp
  if(fifoSocketDepth == 0)
    return -2
  repeat until not lockset(debugSemId) 
  tmp := fifoSocket & $0F
  fifoSocket >>= 8  
  fifoSocketDepth--
  lockclr(debugSemId)
  return DecodeId(tmp)

  
PRI ResetSocket(id)
  Socket.Disconnect(id)                                                                                                                                 
  Socket.Close(id)
  
PRI IsolateTcpSocketById(id) | tmp
  tmp := |< id
  tcpMask &= tmp


PRI SetTcpSocketMaskById(id, state) | tmp
'' The tcpMask contains the socket the the StatusMonitor monitors
  tmp := |< id
  
  if(state == 1)
    tcpMask |= tmp
  else
    tmp := !tmp
    tcpMask &= tmp 
    
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' W5100 Helper methods
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI GetCommandRegisterAddress(id)
  return Socket#_S0_CR + (id * $0100)

PRI GetStatusRegisterAddress(id)
  return Socket#_S0_SR + (id * $0100)

    
PRI SetMac(_firstOctet)
  Socket.WriteMACaddress(true, _firstOctet)
  return 


PRI SetGateway(_firstOctet)
  Socket.WriteGatewayAddress(true, _firstOctet)
  return 


PRI SetSubnet(_firstOctet)
  Socket.WriteSubnetMask(true, _firstOctet)
  return 


PRI SetIP(_firstOctet)
  Socket.WriteIPAddress(true, _firstOctet)
  return 



PRI StringSend(id, _dataPtr)
  Socket.txTCP(id, _dataPtr, strsize(_dataPtr))
  return 


PRI SendChar(id, _dataPtr)
  Socket.txTCP(id, _dataPtr, 1)
  return 

 
PRI SendChars(id, _dataPtr, _length)
  Socket.txTCP(id, _dataPtr, _length)
  return 


PRI InitializeSocket(id)
  Socket.Initialize(id, TCP_PROTOCOL, port, remotePort, @remoteIp)
  return

PRI InitializeSocket2(id)
  Socket.Initialize(id, TCP_PROTOCOL, port2, remotePort, @remoteIp)
  return

PRI InitializeSocketForEmail(id)
  Socket.Initialize(id, TCP_PROTOCOL, port2, emailPort, @emailIp)
  return
  
PRI InitializeUDPSocket(id)
  Socket.Initialize(id, UDP_PROTOCOL, uport, remotePort, @remoteIp)
  return

PRI InitializeSntpUdpSocket(id)
  Socket.Initialize(id, UDP_PROTOCOL, uport, sntpPort, @sntpIp)
  return



''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' Debug/Display Methods
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI QueueDump
  '' Display socket IDs in the queue
  '' ie 00000401 -> socket Zero is next to pop off
  pst.str(string("FIFO["))
  pst.dec(fifoSocketDepth)
  pst.str(string("] "))
  pst.hex(fifoSocket, 8)

    
PRI StackDump | clsd, open, lstn, estb, clwt, clng, id, ulst
  '' This method is purely for debugging
  '' It displays the status of all socket registers
  repeat until not lockset(debugSemId)
  clsd := closedState
  open := openState
  lstn := listenState
  estb := establishedState
  clwt := closeWaitState
  clng := closingState
  ulst := udpListen
  lockclr(debugSemId)

  pst.char(13) 
  repeat id from 3 to 0
    pst.dec(id)
    pst.str(string("-"))
    pst.hex(status[id], 2)
    pst.str(string(" "))
    pause(1)

  pst.str(string(13,"clsd open lstn estb clwt clng udps", 13))
  pst.bin(clsd, 4)
  pst.str(string("-"))
  pst.bin(open, 4)
  pst.str(string("-"))
  pst.bin(lstn, 4)
  pst.str(string("-"))  
  pst.bin(estb, 4)
  pst.str(string("-"))  
  pst.bin(clwt, 4)
  pst.str(string("-"))  
  pst.bin(clng, 4)
  pst.str(string("-"))  
  pst.bin(ulst, 4)
  pst.char(13)


PRI GetPath(id) | i
  bytefill(@filepath, 0 ,33)
  dynamicContentPtr := @filepath
  PushDynamicContent(@approot)
  
  i := 0
  repeat Request.GetDepth(id)-1
    PushDynamicContent(Request.GetPathNode(id, i++))
    PushDynamicContent(@approot) 

   
PRI HeaderLine1(id) | i
  pst.str(Request.GetMethod(id))
  pst.char($20)

  i := 0
  repeat Request.GetDepth(id)
    pst.char($2F)
    pst.str(Request.GetPathNode(id, i++))
    
   
PRI Pause(Duration)  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)
  return


PRI StatusMonitor | id, tmp, value
'' StatusMonitor is the heartbeat of the project
'' Here we monitor the state of the Wiznet 5100's 4 sockets
  repeat

    Socket.GetStatus32(@status[0])

    ' Encode status register states
    repeat until not lockset(debugSemId)

    closedState := openState := listenState := establishedState := {
     } closeWaitState := closingState := 0
     
    repeat id from 0 to 3
      case(status[id])
        $00: closedState               |= |< id
             closedState               &= tcpMask  
        $13: openState                 |= |< id
             openState                 &= tcpMask                   
        $14: listenState               |= |< id
             listenState               &= tcpMask
        $17: establishedState          |= |< id
             establishedState          &= tcpMask
        $18,$1A,$1B: closingState      |= |< id
                     closingState      &= tcpMask
        $1C: closeWaitState            |= |< id
             closeWaitState            &= tcpMask
        $1D: closingState              |= |< id
             closingState              &= tcpMask
        $22: udpListen                 |= |< id
             udpListen                 &= udpMask 

    'Queue up socket IDs
    if(lastEstblState <> establishedState)
      value := establishedState
      repeat while value > 0
        tmp := DecodeId(value)
        if(tmp > -1)
          if(QueueSocket(tmp))
            tmp := |< tmp
            tmp := !tmp
            value &= tmp
          else
            quit
      lastEstblState := establishedState
      

    lockclr(debugSemId)
    
    ' Initialize a closed socket 
    if(closedState > 0)
      id := DecodeId(closedState)
      if(id > -1)
        InitializeSocket(id & tcpMask)
    
    'Start a listener on an initialized/open socket   
    if(openState > 0)
      id := DecodeId(openState)
      if(id > -1)
        Socket.Listen(id & tcpMask)
return
    
DAT
  approot               byte    "\", 0 
  defaultpage           byte    "index.htm", 0
  logfile               byte    "log.txt", 0
  binFile               byte    $0[13]
  binDir                byte    $0[9]
  loadFile              byte    $0[13]  'note
  FS                    byte    "/", 0
  crlf                  byte    13, 10, 0
  crlf_crlf             byte    13, 10, 13, 10, 0
  tempNum               byte    "0000",0
  numBuff               byte    $0[10]
  xmlencode             byte    "<?xml version='1.0' encoding='utf-8'?>",0
  filepath              byte    $0[33]
  doublequote           byte    $22, 0 
  uploadfile            byte    $0[12], 0
  uploadfolder          byte    "uploads", 0
  boundary              byte    $2D, $2D
  boundary1             byte    $0[64]
  multipart             byte    "Content-Type: multipart/form-data; boundary=",0
  fn                    byte    "filename=", 0                                         

{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial ions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}