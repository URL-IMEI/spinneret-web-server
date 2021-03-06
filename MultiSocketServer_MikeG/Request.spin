{{
───────────────────────────────────────────────── 
Copyright (c) 2011 AgaveRobotics LLC.
See end of file for terms of use.

File....... Request.spin 
Author..... Mike Gebhard
Company.... Agave Robotics LLC
Email...... mailto:mike.gebhard@agaverobotics.com
Started.... 11/01/2010
Updated.... 07/25/2011        
───────────────────────────────────────────────── 
}}

{
About:
  Request.spin is a memory structure that holds HTTP resource header data by ID and
  is designed for use with the Spinneret and HTTPServer.spin.   

Usage:
  Instantiate with Constructor(stringMethods). The stringMethods argument is a pointer
  to StringMethods which is running in a COG.  The pointer providers access to the
  execute StringMethods' functions.

  Invoke InitializeRequest(id, rxbuff) with an ID (0-3) and a pointer to the
  request header.

Change Log:
-----------
7/25/2011
Fixed bug in FillPath where a resource without an ending "/" cause a lockup
if GET /test HTTP/1.1 
 
}

CON
  SOCKETS                       = 4
  MAX_NAME_LEN                  = 8
  MAX_EXTENSION_LEN             = 3
  MAX_BUFFER                    = 1024
  SOCKET_BUFFER                 = MAX_BUFFER / SOCKETS
  MAX_PATH_BUFFER               = 196
  SOCKET_PATH_BUFFER            = MAX_PATH_BUFFER / SOCKETS
  MAX_PATH_DEPTH                = 5
  MAX_PATH_DEPTH_POINTERS       = MAX_PATH_DEPTH * SOCKETS
  
  METHOD_LEN                    = 20                      '0  - 19 
  VERSION_LEN                   = 4                       '20 - 23 
  FILE_PATH_LEN                 = 49                      '24 - 72 
  NAME_LEN                      = 9                       '73 - 81 
  EXT_LEN                       = 4                       '82 - 85 
  QUERYSTRING_LEN               = 169                     '86 - 254
                                                          '255
  
                                                          
  METHOD_OFFSET                 = 0                                    
  VERSION_OFFSET                = METHOD_OFFSET + METHOD_LEN           
  FILE_PATH_OFFSET              = VERSION_OFFSET + VERSION_LEN         
  NAME_OFFSET                   = FILE_PATH_OFFSET + FILE_PATH_LEN     
  EXT_OFFSET                    = NAME_OFFSET + NAME_LEN               
  QUERYSTRING_OFFSET            = EXT_OFFSET + EXT_LEN

  MATCH_PATTERN                 = $03
  TO_STRING                     = $02
  TO_INTEGER                    = $01
               
                                                                       
  
  
DAT
  amp         byte      "&",0
  err         byte      "err", $0
  errorHtm    byte      "error.htm", $0
  depth       byte      $0[SOCKETS]          
  sock0       byte      $0[SOCKET_BUFFER]
  sock1       byte      $0[SOCKET_BUFFER]
  sock2       byte      $0[SOCKET_BUFFER]
  sock3       byte      $0[SOCKET_BUFFER]
  sockBuff    long      @sock0, @sock1, @sock2, @sock3
  method      long      @sock0+METHOD_OFFSET, @sock1+METHOD_OFFSET, @sock2+METHOD_OFFSET, @sock3+METHOD_OFFSET
  version     long      @sock0+VERSION_OFFSET, @sock1+VERSION_OFFSET, @sock2+VERSION_OFFSET, @sock3+VERSION_OFFSET
  filePath    long      @sock0+FILE_PATH_OFFSET, @sock1+FILE_PATH_OFFSET, @sock2+FILE_PATH_OFFSET, @sock3+FILE_PATH_OFFSET
  name        long      @sock0+NAME_OFFSET, @sock1+NAME_OFFSET, @sock2+NAME_OFFSET, @sock3+NAME_OFFSET
  extension   long      @sock0+EXT_OFFSET, @sock1+EXT_OFFSET, @sock2+EXT_OFFSET, @sock3+EXT_OFFSET
  queryString long      @sock0+QUERYSTRING_OFFSET, @sock1+QUERYSTRING_OFFSET, @sock2+QUERYSTRING_OFFSET, @sock3+QUERYSTRING_OFFSET
  pathPtr     long      $0[MAX_PATH_DEPTH_POINTERS]
  contentLen  long      $0[SOCKETS]
  strParams   long      $0
  defaultpage byte      "index.htm", 0
  numBuffer   byte      $0[10]
  null        byte      $0 
        

PUB Constructor(stringMethods)
  strParams := stringMethods
   

PUB InitializeRequest(id, rxbuff) | endOfResource, startOfQString, startOfPath
  endOfResource := GetHttpVersion(id, rxbuff)
  startOfQString := FillQueryString(id, rxbuff, endOfResource)
  startOfPath := FillMethod(id, rxbuff)
  FillPath(id, rxbuff, startOfPath, startOfQString, endOfResource)
  FillFile(id, GetFileName(id))
  FillContentLength(id, rxbuff)
  FillPostValues(id, rxbuff)
  DecodeString(@@queryString[id])

 
PUB Release(id)
  bytefill(@@sockBuff[id], 0, SOCKET_BUFFER)
  bytefill(@numBuffer, 0, 10)
  depth[id] := $0
  contentLen[id] := $0

PUB getNumBuffer
  return @numBuffer

PUB Address(id)
  return @@sockBuff[id]


PUB SetMethod(id, srcAddress, count)
  if(count > 19) OR (count < 0)
    bytemove(@@method[id], @err, strsize(@err)+1)
    return false

  Set(@@method[id], srcAddress, count)
  return true

  
PUB GetMethod(id)
  return @@method[id]

PUB Exists(id)
  if(strsize(@@method[id]) > 0)
    return true
  return false

  
PUB SetVersion(id, srcAddress, count)
  if(count > 4)
    bytemove(@@version[id] , @err, strsize(@err)+1) 
    return false
  
  Set(@@version[id] , srcAddress, count)   


PUB GetVersion(id)
  return @@version[id]
  

PUB AddPathNode(id, srcAddress, count) | startAddr

  if(count > MAX_NAME_LEN+MAX_EXTENSION_LEN+2)
    bytemove(@@filePath[id], @errorHtm, strsize(@errorHtm)+1)
    depth[id] := 1
    return false
 
  if(depth[id] > 5)
    bytemove(@@filePath[id], @errorHtm, strsize(@errorHtm)+1)
    depth[id] := 1
    return false
  

  startAddr := @@filePath[id]+(depth[id]*(MAX_NAME_LEN+1))
  Set(startAddr, srcAddress, count) 
  depth[id] += 1
  return count


 
PUB GetPathNode(id, dirDepth)
  
  if(dirDepth > 4)
    return string("/") 
     
  return @@filePath[id]+dirDepth*(MAX_NAME_LEN+1)

  
PUB GetFileName(id)
  return @@filePath[id]+(depth[id]-1)*(MAX_NAME_LEN+1)
        
  
PUB GetDepth(id)
  return depth[id]


PUB SetName(id, srcAddress, count)
  if(count > 13)
    bytemove(@@name[id], @err, strsize(@err)+1)
    return false

  Set(@@name[id], srcAddress, count)



PUB GetName(id)
  return @@name[id]

  
PUB SetExtension(id, srcAddress, count)
  if(count > 4)
    Set(@@extension[id], @err, strsize(@err)+1)
    return false

  bytemove(@@extension[id], srcAddress, count)


PUB GetExtension(id)
  return @@extension[id]
  
PUB SetContentLength(id, length)
  contentLen[id] := length
  return true

PUB GetContentLength(id)
  return contentLen[id]

'SetQueryString(id, startOfQString+rxbuff, endOfResource-startOfQString+1)  
PUB SetQueryString(id, srcAddress, count)
  if(count > 100) OR (count < 0)
    bytemove(@@queryString[id]  , @err, strsize(@err)+1)
    return false

  Set(@@queryString[id], srcAddress, count)
  return true

PUB SetPostData(id, srcAddress, count)
  Set(@@queryString[id]+strsize(@@queryString[id]), srcAddress, count)
  return true
  
PUB GetQueryString(id)
  return @@queryString[id] 

PUB Get(id, qname) | t1, t2, strt
  t1 := MatchPattern(@@queryString[id], qname, 0, false)
  if(t1 == -1 or t1 > 50)
    return  null

  return @@queryString[id] + t1 + 1 + strsize(qname)


PUB Post(id, pname) | t1, t2, strt
  t1 := MatchPattern(@@queryString[id], pname, 0, false)
  if(t1 == -1 or t1 > 50)
    return  null

  return @@queryString[id] + t1 + 1 + strsize(pname)

  
PUB GetPostDataLen(id, rxbuff) : len | strt
  strt := MatchPattern(rxbuff, string(13,10,13,10), 0, true)
  
  if(strt == -1)
    return strt
    
  len :=  strsize(strt +  rxbuff + 4)   
  return
  
PRI Set(DestAddress, SrcAddress, Count)
  bytemove(DestAddress, SrcAddress, Count)
  bytefill(DestAddress+Count, $0, 1)



  
PRI GetHttpVersion(id, rxbuff) : endOfResource  
  endOfResource := MatchPattern(rxbuff, string("HTTP/"), 0, true)
  
  if(endOfResource == -1)
    return endOfResource

  SetVersion(id, rxbuff+endOfResource+5, 3)
  
  endOfResource -= 2
  return endOfResource
  
  
PRI FillQueryString(id, rxbuff, endOfResource) : startOfQString

  ' Find the strt and end of the query string if it exists
  startOfQString := MatchPattern(rxbuff, string("?"), 0, true)

  'Get out of here if we did not find a query string
  if((startOfQString == -1) OR (startOfQString > endOfResource))
    startOfQString := -1
    return startOfQString

  SetQueryString(id, startOfQString+rxbuff+1, endOfResource-startOfQString)

  return startOfQString

  
PRI FillPostValues(id, rxbuff) | strt,  len
  ifnot(strcomp(GetMethod(id),string("POST")))
    return
    
  strt := MatchPattern(rxbuff, string(13,10,13,10), 0, true)
  if(strt == -1)
    return

  len :=  strsize(rxbuff) - strt+4
  SetPostData(id, strt+rxbuff+1, len)

  return  



PRI FillMethod(id, rxbuff) : startOfPath

  ' Mark the first "/", the end of the method is - 2 characters
  ' GET /images/guitar.gif
  ' Buffer the method string
  startOfPath := MatchPattern(rxbuff, string("/"), 0, true)
  SetMethod(id, rxbuff, startOfPath-1)

  ' Return the start of the path item
  return startOfPath

  
PRI FillPath(id, rxbuff, startOfPath, startOfQString, endOfResource) | endOfPath, prv, nxt, t1

  t1 := 0
  'We're looking for the end of the path and does
  'not include a query string ?id=1
  '/members/default.htm?id=1 
  '/images/guitar.gif
  endOfPath := endOfResource
  if(startOfQString > 0)
    'startOfQString is pointing to "?"
    endOfPath := startOfQString-1

  'eop := endOfPath  

  ' The root is requested if the start and end of the path are equal
  ' GET / HTTP/1.1
  if(startOfPath == endOfPath)
    AddPathNode(id, @defaultPage, strsize(@defaultPage))
    return   

  'Previous pointer
  prv := startOfPath
  'prva[i] := prv
  repeat MAX_PATH_DEPTH
    'Mark the next "/"
    nxt := MatchPattern(rxbuff, string("/"), prv+1, true)
    'nxta[i++] := nxt                                       
    ' Did we find the "/" in "HTTP/1.1"?
    ' If so, buff the file name and we're done
    ' GET /images/guitar.gif HTTP/1.1
    ' GET /uploads HTTP/1.1
    if((nxt == -1) OR (nxt > endOfPath))
      t1 := MatchPattern(rxbuff, string("."), prv+1, true)

      ' Did we find the "." in HTTP/1.1?
      ' If so we're done, write the last directory
      if(t1 > endOfPath)
        nxt := endOfPath
        AddPathNode(id, prv+rxbuff+1, nxt-prv) 
        AddPathNode(id, @defaultPage, strsize(@defaultPage))
        return 

      ' Did we find a "." in a file name
      ' if so write the file name and we're done
      if((t1 < endOfPath) AND (t1 > -1))
        AddPathNode(id, prv+rxbuff+1, endOfPath-prv)
        return

    ' Does the path end with a "/" like /members/home/
    ' if so, buffer the directory and the default page
    if(nxt ==  endOfPath)
      AddPathNode(id, prv+rxbuff+1, nxt-prv-1) 
      AddPathNode(id, @defaultPage, strsize(@defaultPage))
      return 
                                                               
    ' Add the directory
    '/images/home/guitar.gif HTTP/1.1
    AddPathNode(id, prv+rxbuff+1, nxt-prv-1)

    ' Set the privious pointer equal to the 
    ' next pointer and repeat
    prv := nxt
    'prva[i]  := prv

    

PRI FillFile(id, fname) | dot
  ' Mark the dot in the file name
  ' guitar.gif
  dot := MatchPattern(fname, string("."), 0, true)
  if(dot == -1)
    return
    
  ' MatchPattern is zero based
  SetName(id, fname, dot)
  SetExtension(id, fname+dot+1, 3)



PRI FillContentLength(id, rxbuff) | strt, end, conlen, char, i

  bytefill(@numBuffer, 0, 10) 
  i := 0
  
  'Content-Length: 100 
  strt := MatchPattern(rxbuff, string("-Length: "), 0, true)
    
  if(strt == -1)
    SetContentLength(id, 0)
    return
    
  strt += strsize(string("-Length: ")) + rxbuff
  
  repeat until ((byte[strt][i] == $0A) or (byte[strt][i] == $0D) or (i > 9)) 
    byte[@numBuffer][i++] := byte[strt][i]

  conlen := ToInteger(@numBuffer)
  SetContentLength(id, conlen)
  


PRI DecodeString(decodeStr) | char, inPlace, outPlace
  inPlace := outPlace := 0
  repeat 
    char := byte[decodeStr][inPlace++]
    if (char == "%") ' convert %## back into a character
      'inPlace++ ' skip %
      ' first nibble
      char := byte[decodeStr][inPlace++] - 48
      if (char > 9)
        char -= 7
      char := char << 4
      byte[decodeStr][outPlace] := char
      ' second nibble
      char := byte[decodeStr][inPlace++] - 48
      if (char > 9)
        char -= 7
      byte[decodeStr][outPlace++] += char
      ' since we trashed char doing the decode, we need this to keep the loop going
      char := "x"
    elseif (char == "+") ' convert + back to a space
      byte[decodeStr][outPlace++] := " "
    elseif(char == "&")
      byte[decodeStr][outPlace++] := $00
    else ' no conversion needed, just set the character
      byte[decodeStr][outPlace++] := char
  until (char == 0)
    
  byte[decodeStr][outPlace-1] := 0 ' terminate the string at it's new shorter size

''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'' StringMethod signatures
'' StringMethods object is running in a COG invoked from
'' the top level object
''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
PRI MatchPattern(source, pattern, offset, binary)

  long[strParams][0] := $00
  long[strParams][1] := $FFFF_FFFF
  long[strParams][2] := source
  long[strParams][3] := pattern
  long[strParams][4] := offset
  long[strParams][5] := binary

  long[strParams][0] := MATCH_PATTERN

  repeat until long[strParams][0] == $00
  return long[strParams][1]

PRI ToInteger(stringToConvert)
  long[strParams][0] := $00
  long[strParams][1] := $FFFF_FFFF
  long[strParams][2] := stringToConvert
  long[strParams][3] := $00
  long[strParams][4] := $00
  long[strParams][5] := $00

  long[strParams][0] := TO_INTEGER

  repeat until long[strParams][0] == $00
  return long[strParams][1]

PRI ToString(integerToConvert, destinationPointer)
  long[strParams][0] := $00
  long[strParams][1] := $FFFF_FFFF
  long[strParams][2] := integerToConvert
  long[strParams][3] := destinationPointer
  long[strParams][4] := $00
  long[strParams][5] := $00

  long[strParams][0] := TO_STRING

  repeat until long[strParams][0] == $00
  return destinationPointer
  
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