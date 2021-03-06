#
#        Asyncdispatch2 Transport Common Types
#                 (c) Copyright 2018
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)

import net, strutils
import ../asyncloop, ../asyncsync

const
  DefaultStreamBufferSize* = 4096    ## Default buffer size for stream
                                     ## transports
  DefaultDatagramBufferSize* = 65536 ## Default buffer size for datagram
                                     ## transports
type
  ServerFlags* = enum
    ## Server's flags
    ReuseAddr, ReusePort

  TransportAddress* = object
    ## Transport network address
    address*: IpAddress           # IP Address
    port*: Port                   # IP port

  ServerCommand* = enum
    ## Server's commands
    Start,                        # Start server
    Pause,                        # Pause server
    Stop                          # Stop server

  ServerStatus* = enum
    ## Server's statuses
    Starting,                     # Server created
    Stopped,                      # Server stopped
    Running,                      # Server running
    Paused                        # Server paused

  SocketServer* = ref object of RootRef
    ## Socket server object
    sock*: AsyncFD                # Socket
    local*: TransportAddress      # Address
    actEvent*: AsyncEvent         # Activation event
    action*: ServerCommand        # Activation command
    status*: ServerStatus         # Current server status
    udata*: pointer               # User-defined pointer
    flags*: set[ServerFlags]      # Flags
    bufferSize*: int              # Size of internal transports' buffer
    loopFuture*: Future[void]     # Server's main Future

  TransportError* = object of Exception
    ## Transport's specific exception
  TransportOsError* = object of TransportError
    ## Transport's OS specific exception
  TransportIncompleteError* = object of TransportError
    ## Transport's `incomplete data received` exception
  TransportLimitError* = object of TransportError
    ## Transport's `data limit reached` exception

  TransportState* = enum
    ## Transport's state
    ReadPending,                  # Read operation pending (Windows)
    ReadPaused,                   # Read operations paused
    ReadClosed,                   # Read operations closed
    ReadEof,                      # Read at EOF
    ReadError,                    # Read error
    WritePending,                 # Writer operation pending (Windows)
    WritePaused,                  # Writer operations paused
    WriteClosed,                  # Writer operations closed
    WriteError                    # Write error

var
  AnyAddress* = TransportAddress(
    address: IpAddress(family: IpAddressFamily.IPv4), port: Port(0)
  ) ## Default INADDR_ANY address for IPv4
  AnyAddress6* = TransportAddress(
    address: IpAddress(family: IpAddressFamily.IPv6), port: Port(0)
  ) ## Default INADDR_ANY address for IPv6

proc getDomain*(address: IpAddress): Domain =
  ## Returns OS specific Domain from IP Address.
  case address.family
  of IpAddressFamily.IPv4:
    result = Domain.AF_INET
  of IpAddressFamily.IPv6:
    result = Domain.AF_INET6

proc getDomain*(address: TransportAddress): Domain =
  ## Returns OS specific Domain from TransportAddress.
  result = address.address.getDomain()

proc `$`*(address: TransportAddress): string =
  ## Returns string representation of ``address``.
  case address.address.family
  of IpAddressFamily.IPv4:
    result = $address.address
    result.add(":")
  of IpAddressFamily.IPv6:
    result = "[" & $address.address & "]"
    result.add(":")
  result.add($int(address.port))

proc strAddress*(address: string): TransportAddress =
  ## Parses string representation of ``address``.
  ##
  ## IPv4 transport address format is ``a.b.c.d:port``.
  ## IPv6 transport address format is ``[::]:port``.
  var parts = address.rsplit(":", maxsplit = 1)
  doAssert(len(parts) == 2, "Format is <address>:<port>!")
  let port = parseInt(parts[1])
  doAssert(port > 0 and port < 65536, "Illegal port number!")
  result.port = Port(port)
  if parts[0][0] == '[' and parts[0][^1] == ']':
    result.address = parseIpAddress(parts[0][1..^2])
  else:
    result.address = parseIpAddress(parts[0])

template checkClosed*(t: untyped) =
  if (ReadClosed in (t).state) or (WriteClosed in (t).state):
    raise newException(TransportError, "Transport is already closed!")

template getError*(t: untyped): ref Exception =
  var err = (t).error
  (t).error = nil
  err

when defined(windows):
  import winlean

  const ERROR_OPERATION_ABORTED* = 995
  const ERROR_SUCCESS* = 0
  proc cancelIo*(hFile: HANDLE): WINBOOL
       {.stdcall, dynlib: "kernel32", importc: "CancelIo".}
