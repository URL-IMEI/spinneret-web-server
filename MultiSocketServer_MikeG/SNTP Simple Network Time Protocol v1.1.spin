OBJ
{{
  v1.1 Revision - Added IsDST IsDSTEU for European Union), a method for detection and adjustment for DST
  Currently implemented for GetTransmitTimestamp, but should work for other methods that call HumanTime
}}

VAR

    long   HH,Month,Date,Year

PUB CreateUDPtimeheader(BufferAddress,IPAddr)
  '---------------------------------------------------------------------
  '                     UDP IP Address - 4 Bytes 
  '---------------------------------------------------------------------
    BYTEMOVE(BufferAddress,IPAddr,4)
  '---------------------------------------------------------------------
  '                       UDP Header - 4 Bytes 
  '---------------------------------------------------------------------
    byte[BufferAddress][4] := 0
    byte[BufferAddress][5] := 123 '<- Port Address 
    byte[BufferAddress][6] := 0 
    byte[BufferAddress][7] := 48  '<- Header + Packet
  '---------------------------------------------------------------------
  '                       UDP Packet - 44 Bytes
  '---------------------------------------------------------------------
    byte[BufferAddress][8]  := %11_100_011    'leap,version, and mode
    byte[BufferAddress][9]  := 0              'stratum
    byte[BufferAddress][10] := 0              'Poll   
    byte[BufferAddress][11] := %10010100      'precision
    byte[BufferAddress][12] := 0              'rootdelay
    byte[BufferAddress][13] := 0              'rootdelay   
    byte[BufferAddress][14] := 0              'rootdispersion
    byte[BufferAddress][15] := 0              'rootdispersion

    bytemove(BufferAddress+16,string("LOCL"),4) 'ref-id ; four-character ASCII string

    bytefill(BufferAddress+20,0,32)           '(ref, originate, receive, transmit) time 
  
  {
leap           = %11           ; alarm condition (clock not synchronized) 
version        = %011 or %100  ; Version 3 or 4
Mode           = %011          ; Client        
stratum        = %00000000     ; unspecified
Poll           = %00000000     ; = 2^n seconds (maximum interval between successive messages)
precision      = %10010100     ; -20 (8-bit signed integer)
rootdelay      = 0             ; 32 bit value
rootdispersion = 0             ; 32 bit value
ref id         = "LOCL"        ; four-character ASCII string
ref time       = 0             ; 64 bit value
originate time = 0             ; 64 bit value   
receive time   = 0             ; 64 bit value
transmit time  = 0             ; 64 bit value
  }


PUB GetMode(BufferAddress)
    result := byte[BufferAddress][8] & %00000111
    '0 - reserved
    '1 - symmetric active
    '2 - symmetric passive
    '3 - client
    '4 - server
    '5 - broadcast
    '6 - reserved for NTP control message
    '7 - reserved for private use

PUB GetVersion(BufferAddress)    
    result := (byte[BufferAddress][8] & %00111000)>>3
    '3 - Version 3 (IPv4 only)
    '4 - Version 4 (IPv4, IPv6 and OSI)

PUB GetLI(BufferAddress)
    result := (byte[BufferAddress][8] & %11000000)>>6
    '0 - No warning
    '1 - last minute has 61 seconds
    '2 - last minute has 59 seconds
    '3 - alarm condition (clock not synchronized)   

PUB GetStratum(BufferAddress)
    result := byte[BufferAddress][9]
    '0      - unspecified or unavailable
    '1      - primary reference (e.g., radio clock)
    '2-15   - secondary reference (via NTP or SNTP) 
    '16-255 - reserved

PUB GetPoll(BufferAddress)
    result := byte[BufferAddress][10]
    'This is an eight-bit signed integer indicating the
    'maximum interval between successive messages, in seconds
    'to the nearest power of two. The values that can appear
    'in this field presently range from 4 (16 s) to 14 (16384 s);
    'however, most applications use only the sub-range 6 (64 s)
    'to 10 (1024 s). 

PUB GetPrecision(BufferAddress)
    result := byte[BufferAddress][10]
    'This is an eight-bit signed integer indicating the
    'precision of the local clock, in seconds to the nearest
    'power of two. The values that normally appear in this
    'field range from -6 for mains-frequency clocks to -20 for
    'microsecond clocks found in some workstations.

PUB GetRootDelay(BufferAddress)|Temp1
    Temp1 := byte[BufferAddress][12]<<24+byte[BufferAddress][13]<<16
    Temp1 += byte[BufferAddress][14]<<8 +byte[BufferAddress][15]
    result  := Temp1
    'This is a 32-bit signed fixed-point number indicating the
    'total roundtrip delay to the primary reference source, in
    'seconds with fraction point between bits 15 and 16. Note
    'that this variable can take on both positive and negative
    'values, depending on the relative time and frequency offsets.
    'The values that normally appear in this field range from
    'negative values of a few milliseconds to positive values of
    'several hundred milliseconds.

PUB GetRootDispersion(BufferAddress)|Temp1
    Temp1 := byte[BufferAddress][16]<<24+byte[BufferAddress][17]<<16
    Temp1 += byte[BufferAddress][18]<<8 +byte[BufferAddress][19]
    result  := Temp1
    'This is a 32-bit unsigned fixed-point number indicating the
    'nominal error relative to the primary reference source, in
    'seconds with fraction point between bits 15 and 16. The values
    'that normally appear in this field range from 0 to several
    'hundred milliseconds.          

PUB{
      Calling example:          
            PST.str(GetReferenceIdentifier(@Buffer,string("----"))

            dashes get replaced with 4-Character Buffer contents

}   GetReferenceIdentifier(BufferAddress,FillAddress)
    bytemove(FillAddress,BufferAddress+20,4)
    result := FillAddress
{          Reference Identifier return codes
       
           Code     External Reference Source
           -----------------------------------------------------------
           LOCL     uncalibrated local clock used as a primary reference for
                    a subnet without external means of synchronization
           PPS      atomic clock or other pulse-per-second source
                    individually calibrated to national standards
           ACTS     NIST dialup modem service
           USNO     USNO modem service
           PTB      PTB (Germany) modem service
           TDF      Allouis (France) Radio 164 kHz
           DCF      Mainflingen (Germany) Radio 77.5 kHz
           MSF      Rugby (UK) Radio 60 kHz
           WWV      Ft. Collins (US) Radio 2.5, 5, 10, 15, 20 MHz
           WWVB     Boulder (US) Radio 60 kHz
           WWVH     Kaui Hawaii (US) Radio 2.5, 5, 10, 15 MHz
           CHU      Ottawa (Canada) Radio 3330, 7335, 14670 kHz
           LORC     LORAN-C radionavigation system
           OMEG     OMEGA radionavigation system
           GPS      Global Positioning Service
           GOES     Geostationary Orbit Environment Satellite                   }

PUB  GetReferenceTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][24]<<24+byte[BufferAddress][25]<<16
     Temp1 += byte[BufferAddress][26]<<8 +byte[BufferAddress][27]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][28]<<24+byte[BufferAddress][29]<<16
     Temp1 += byte[BufferAddress][30]<<8 +byte[BufferAddress][31]
     long[Long2]:=Temp1     
     'This is the time at which the local clock was
     'last set or corrected, in 64-bit timestamp format.
     HumanTime(Offset,Long1)

PUB  GetOriginateTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][32]<<24+byte[BufferAddress][33]<<16
     Temp1 += byte[BufferAddress][34]<<8 +byte[BufferAddress][35]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][36]<<24+byte[BufferAddress][37]<<16
     Temp1 += byte[BufferAddress][38]<<8 +byte[BufferAddress][39]
     long[Long2]:=Temp1     
     'This is the time at which the request departed the
     'client for the server, in 64-bit timestamp format.
     HumanTime(Offset,Long1)

PUB  GetReceiveTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][40]<<24+byte[BufferAddress][41]<<16
     Temp1 += byte[BufferAddress][42]<<8 +byte[BufferAddress][43]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][44]<<24+byte[BufferAddress][45]<<16
     Temp1 += byte[BufferAddress][46]<<8 +byte[BufferAddress][47]
     long[Long2]:=Temp1     
     'This is the time at which the request arrived at
     'the server, in 64-bit timestamp format.
     HumanTime(Offset,Long1)     

PUB  GetTransmitTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][48]<<24+byte[BufferAddress][49]<<16
     Temp1 += byte[BufferAddress][50]<<8 +byte[BufferAddress][51]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][52]<<24+byte[BufferAddress][53]<<16
     Temp1 += byte[BufferAddress][54]<<8 +byte[BufferAddress][55]
     long[Long2]:=Temp1     
     'This is the time at which the reply departed the
     'server for the client, in 64-bit timestamp format.
     HumanTime(Offset,Long1)
     If IsDST
       HumanTime(Offset+1,Long1)

PUB HumanTime(Offset,TimeStampAddress)|i,Seconds,Days,Years,LYrs,DW,DD,MM,SS
    Seconds := long[TimeStampAddress] + Offset * 3600
    Days    := ((Seconds >>= 7)/675) + 1 '<- Days since Jan 1, 1900

    DW      := (Days-1) // 7
    
    Years:=0
    repeat while Days > 365     '<- When done, Days will contain
      Years++                   '   Number of Days THIS year and
      Days -= 365               '   Years will show number of years
                                '   since 1900.

    LYrs := Years / 4           '<- Leap years since 1900
    Year := Years + 1900        '<- Current Year                   

    Days -= LYrs                '<- Leap year Days correction
                                '   for THIS year
    repeat
      repeat i from 1 to 12     '<- Calculate number of days 
        Month := 30             '   in each month.  Stop if
        if i&1 <> (i&8)>>4      '   Month has been reached
           Month += 1
        if i == 2
           Month := 28 
        if Days => Month        '<- When done, Days will contain
           Days -= Month        '   the number of days so far this 
           if Days =< Month     '   month.  In other words, the Date.
              quit     
    until Days =< Month
    Month := i + 1              '<- Current Month               
    Date  := Days               '<- Current Date


    SS := long[TimeStampAddress]-(((Years*365)*675)<<7) '<- seconds this year
    SS += Offset * 3600 
    
    MM := SS / 60                        '<- minutes this year
    SS := SS - (MM * 60)                 '<- current seconds

    HH := MM / 60                        '<- hours this year
    MM := MM - (HH * 60)                 '<- current minutes

    DD := HH / 24                        '<- days this year
    HH := HH - (DD * 24)                 '<- current hour

    DD -= LYrs                           '<- Leap year Days correction
                                         '   for THIS year

    long[TimeStampAddress][2] := Month<<24+Date<<16+Year
    long[TimeStampAddress][3] := DW<<24+HH<<16+MM<<8+SS                                     

'    DD is redundant but I included it for completion...
'    If you subtract the number of days so far this year from
'    DD and add one, you should get today's date.  This is calculated
'    from another angle above from Days
PUB IsDST|MarDate,NovDate           ' <- Using North American Rules

    case Year
      2021, 2027, 2032, 2038, 2049, 2055, 2060, 2066, 2077, 2083, 2088, 2094:
        MarDate := 14
        NovDate := 7
      2011, 2016, 2022, 2033, 2039, 2044, 2050, 2061, 2067, 2072, 2078, 2089, 2095:
        MarDate := 13
        NovDate := 6
      2017, 2023, 2028, 2034, 2045, 2051, 2056, 2062, 2073, 2079, 2084, 2090:
        MarDate := 12
        NovDate := 5
      2012, 2018, 2029, 2035, 2040, 2046, 2057, 2063, 2068, 2074, 2085, 2091, 2096:
        MarDate := 11
        NovDate := 4
      2013, 2019, 2024, 2030, 2041, 2047, 2052, 2058, 2069, 2075, 2080, 2086, 2097:
        MarDate := 10
        NovDate := 3
      2014, 2025, 2031, 2036, 2042, 2053, 2059, 2064, 2070, 2081, 2087, 2092, 2098:
        MarDate := 9
        NovDate := 2
      2015, 2020, 2026, 2037, 2043, 2048, 2054, 2065, 2071, 2076, 2082, 2093, 2099:
        MarDate := 8
        NovDate := 1

  case Month
    4,5,6,7,8,9,10:
      Return true
    3:
      if Date > MarDate        
        Return true
      if Date == MarDate         
        if HH => 2                                      
          Return true
    11:
      if Date < NovDate         
        Return true
      if Date == NovDate
        ifNot HH => 1              
          Return true

PUB IsDSTEU|MarDate,OctDate              ' <- Using European Union Rules

    case Year
      2021, 2027, 2032, 2038, 2049, 2055, 2060, 2066, 2077, 2083, 2088, 2094:
        MarDate := 28
        OctDate := 31
      2011, 2016, 2022, 2033, 2039, 2044, 2050, 2061, 2067, 2072, 2078, 2089, 2095:
        MarDate := 27
        OctDate := 30
      2017, 2023, 2028, 2034, 2045, 2051, 2056, 2062, 2073, 2079, 2084, 2090:
        MarDate := 26
        OctDate := 29
      2012, 2018, 2029, 2035, 2040, 2046, 2057, 2063, 2068, 2074, 2085, 2091, 2096:
        MarDate := 25
        OctDate := 28
      2013, 2019, 2024, 2030, 2041, 2047, 2052, 2058, 2069, 2075, 2080, 2086, 2097:
        MarDate := 31
        OctDate := 27
      2014, 2025, 2031, 2036, 2042, 2053, 2059, 2064, 2070, 2081, 2087, 2092, 2098:
        MarDate := 30
        OctDate := 26
      2015, 2020, 2026, 2037, 2043, 2048, 2054, 2065, 2071, 2076, 2082, 2093, 2099:
        MarDate := 29
        OctDate := 25

  case Month
    4,5,6,7,8,9:
      Return true
    3:
      if Date > MarDate        
        Return true
      if Date == MarDate        
        if HH => 1                                      
          Return true
    10:
      if Date =< OctDate         
        Return true
      