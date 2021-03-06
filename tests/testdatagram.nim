#              Asyncdispatch2 Test Suite
#                 (c) Copyright 2018
#         Status Research & Development GmbH
#
#              Licensed under either of
#  Apache License, version 2.0, (LICENSE-APACHEv2)
#              MIT license (LICENSE-MIT)

import strutils, net, unittest
import ../asyncdispatch2

const
  TestsCount = 10000
  ClientsCount = 100
  MessagesCount = 100

proc client1(transp: DatagramTransport, pbytes: pointer, nbytes: int,
             raddr: TransportAddress, udata: pointer): Future[void] {.async.} =
  if not isNil(pbytes):
    var data = newString(nbytes + 1)
    copyMem(addr data[0], pbytes, nbytes)
    data.setLen(nbytes)
    if data.startsWith("REQUEST"):
      var numstr = data[7..^1]
      var num = parseInt(numstr)
      var ans = "ANSWER" & $num
      await transp.sendTo(addr ans[0], len(ans), raddr)
    else:
      var err = "ERROR"
      await transp.sendTo(addr err[0], len(err), raddr)
  else:
    ## Read operation failed with error
    var counterPtr = cast[ptr int](udata)
    counterPtr[] = -1
    transp.close()

proc client2(transp: DatagramTransport, pbytes: pointer, nbytes: int,
             raddr: TransportAddress, udata: pointer): Future[void] {.async.} =
  if not isNil(pbytes):
    var data = newString(nbytes + 1)
    copyMem(addr data[0], pbytes, nbytes)
    data.setLen(nbytes)
    if data.startsWith("ANSWER"):
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = counterPtr[] + 1
      if counterPtr[] == TestsCount:
        transp.close()
      else:
        var ta = strAddress("127.0.0.1:33336")
        var req = "REQUEST" & $counterPtr[]
        await transp.sendTo(addr req[0], len(req), ta)
    else:
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = -1
      transp.close()
  else:
    ## Read operation failed with error
    var counterPtr = cast[ptr int](udata)
    counterPtr[] = -1
    transp.close()

proc client3(transp: DatagramTransport, pbytes: pointer, nbytes: int,
             raddr: TransportAddress, udata: pointer): Future[void] {.async.} =
  if not isNil(pbytes):
    var data = newString(nbytes + 1)
    copyMem(addr data[0], pbytes, nbytes)
    data.setLen(nbytes)
    if data.startsWith("ANSWER"):
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = counterPtr[] + 1
      if counterPtr[] == TestsCount:
        transp.close()
      else:
        var req = "REQUEST" & $counterPtr[]
        await transp.send(addr req[0], len(req))
    else:
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = -1
      transp.close()
  else:
    ## Read operation failed with error
    var counterPtr = cast[ptr int](udata)
    counterPtr[] = -1
    transp.close()

proc client4(transp: DatagramTransport, pbytes: pointer, nbytes: int,
             raddr: TransportAddress, udata: pointer): Future[void] {.async.} =
  if not isNil(pbytes):
    var data = newString(nbytes + 1)
    copyMem(addr data[0], pbytes, nbytes)
    data.setLen(nbytes)
    if data.startsWith("ANSWER"):
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = counterPtr[] + 1
      if counterPtr[] == MessagesCount:
        transp.close()
      else:
        var req = "REQUEST" & $counterPtr[]
        await transp.send(addr req[0], len(req))
    else:
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = -1
      transp.close()
  else:
    ## Read operation failed with error
    var counterPtr = cast[ptr int](udata)
    counterPtr[] = -1
    transp.close()

proc client5(transp: DatagramTransport, pbytes: pointer, nbytes: int,
             raddr: TransportAddress, udata: pointer): Future[void] {.async.} =
  if not isNil(pbytes):
    var data = newString(nbytes + 1)
    copyMem(addr data[0], pbytes, nbytes)
    data.setLen(nbytes)
    if data.startsWith("ANSWER"):
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = counterPtr[] + 1
      if counterPtr[] == MessagesCount:
        transp.close()
      else:
        var ta = strAddress("127.0.0.1:33337")
        var req = "REQUEST" & $counterPtr[]
        await transp.sendTo(addr req[0], len(req), ta)
    else:
      var counterPtr = cast[ptr int](udata)
      counterPtr[] = -1
      transp.close()
  else:
    ## Read operation failed with error
    var counterPtr = cast[ptr int](udata)
    counterPtr[] = -1
    transp.close()

proc test1(): Future[int] {.async.} =
  var ta = strAddress("127.0.0.1:33336")
  var counter = 0
  var dgram1 = newDatagramTransport(client1, udata = addr counter, local = ta)
  var dgram2 = newDatagramTransport(client2, udata = addr counter)
  var data = "REQUEST0"
  await dgram2.sendTo(addr data[0], len(data), ta)
  await dgram2.join()
  dgram1.close()
  result = counter

proc test2(): Future[int] {.async.} =
  var ta = strAddress("127.0.0.1:33337")
  var counter = 0
  var dgram1 = newDatagramTransport(client1, udata = addr counter, local = ta)
  var dgram2 = newDatagramTransport(client3, udata = addr counter, remote = ta)
  var data = "REQUEST0"
  await dgram2.send(addr data[0], len(data))
  await dgram2.join()
  dgram1.close()
  result = counter

proc waitAll(futs: seq[Future[void]]): Future[void] =
  var counter = len(futs)
  var retFuture = newFuture[void]("waitAll")
  proc cb(udata: pointer) =
    dec(counter)
    if counter == 0:
      retFuture.complete()
  for fut in futs:
    fut.addCallback(cb)
  return retFuture

proc test3(bounded: bool): Future[int] {.async.} =
  var ta = strAddress("127.0.0.1:33337")
  var counter = 0
  var dgram1 = newDatagramTransport(client1, udata = addr counter, local = ta)
  var clients = newSeq[Future[void]](ClientsCount)
  var counters = newSeq[int](ClientsCount)
  var dgram: DatagramTransport
  for i in 0..<ClientsCount:
    var data = "REQUEST0"
    if bounded:
      dgram = newDatagramTransport(client4, udata = addr counters[i],
                                   remote = ta)
      await dgram.send(addr data[0], len(data))
    else:
      dgram = newDatagramTransport(client5, udata = addr counters[i])
      await dgram.sendTo(addr data[0], len(data), ta)
    clients[i] = dgram.join()

  await waitAll(clients)
  dgram1.close()
  result = 0
  for i in 0..<ClientsCount:
    result += counters[i]

when isMainModule:
  const
    m1 = "Unbounded test (" & $TestsCount & " messages)"
    m2 = "Bounded test (" & $TestsCount & " messages)"
    m3 = "Unbounded multiple clients with messages (" & $ClientsCount &
         " clients x " & $MessagesCount & " messages)"
    m4 = "Bounded multiple clients with messages (" & $ClientsCount &
         " clients x " & $MessagesCount & " messages)"
  suite "Datagram Transport test suite":
    test m1:
      check waitFor(test1()) == TestsCount
    test m2:
      check waitFor(test2()) == TestsCount
    test m3:
      check waitFor(test3(false)) == ClientsCount * MessagesCount
    test m4:
      check waitFor(test3(true)) == ClientsCount * MessagesCount
