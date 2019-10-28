
#import urlstrappkg/submodule
import utils, models, rethinkdb
import times, strutils, json, jester, net, httpClient, asyncdispatch, uri

let conn* = waitFor newConnection()
let newdb* = db("urlstrap")

proc insertResult*(t: Target, c: Check) {.async.} =
    var tr = await conn.runQuery(newdb.table("target").insert(%*t))
    var cr = await conn.runQuery(newdb.table("check").insert(%*c))
    echo tr
    echo cr 

proc insertTarget*(t: Target) {.async.} =
  var tr = await conn.runQuery(newdb.table("target").insert(%*t))
  echo tr

proc insertCheck*(c: Check) {.async.} =
  var cr = await conn.runQuery(newdb.table("check").insert(%*c))
  echo cr

proc insertMyReq*(myreq: MyRequest) {.async.} =
  var rr = await conn.runQuery(newdb.table("request").insert(%*myreq))
  echo rr

proc getAllFiltered*(t: string, f: JsonNode ): Future[JsonNode] =
  var tab = newdb.table(t)
  var j = conn.runQuery(tab.filter(f))
  return j

proc getAll*(t:string): Future[JsonNode] =
  var tab = newdb.table(t)
  var j = conn.runQuery(tab)
  return j

proc targetexist*(uri: Uri): JsonNode =
  #var res = waitFor getAllFiltered("target", %*{"url": {"hostname": ntarget} } )
  var res = waitFor getAllFiltered("target", %*{"url": %*uri } )
  return res

proc parsePayload*(payload: string): MyRequest =
  var httpreq = new(MyRequest)
  var r = parseJson(payload)
  if not (r.len <= 0):
    if "content_type" notin r:
      httpreq.content_type = "application/json"
    else:
      httpreq.content_type = r["content_type"].getStr()
    if "request_method" notin r:
      httpreq.request_method = "GET"
    else:
      httpreq.request_method = r["request_method"].getStr()
    if "user_agent" notin r:
      httpreq.user_agent = defUserAgent
    else:
      httpreq.user_agent = r["user_agent"].getStr()
    if "request_data" notin r:
      httpreq.request_data = %*{}
    else:
      httpreq.request_data = %*(r["request_data"].getFields())
    if "wait" notin r:
      httpreq.wait = 5 
    else:
      httpreq.wait = r["wait"].getInt()
    httpreq.url = r["url"].getStr()
    if httpreq.request_method == "GET":
      httpreq.request_data = %*{}
    httpreq.id = genUUID()
    return httpreq
  else:
    return httpreq


proc PostCheck*(payload: JsonNode): JsonNode =
  var myreq = to(payload, MyRequest)
  var check:Check
  check.id = genUUID()
  check.check_time = $(getTime().utc)
  if myreq.wait <= 0: myreq.wait = 5
  var myreq_url = parseUri(myreq.url)
  var t_exist = targetexist(myreq_url)
  var target:Target
  if t_exist.len >= 1:
    target = to(t_exist[0], Target)
  else:
    target = Target(id: genUUID(), url: myreq_url)
    waitFor insertTarget(target)
  if target.url.scheme == "tcp":
    var socket = newSocket()
    try:
        var time = cpuTime()
        socket.connect(target.url.hostname, Port( parseInt(target.url.port)), myreq.wait*1000)
        var elapsed = cpuTime() - time
        check.ok = true
        check.response_time = elapsed.formatFloat(format = ffDecimal, precision = 3)
    except:
        check.ok = false
    finally:
        socket.close()
  elif target.url.scheme == "udp":
    try:
      var socket = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
      var time = cpuTime()
      socket.sendTo(target.url.hostname, Port(parseInt(target.url.port)), "status\n")
      var elapsed = cpuTime() - time
      check.ok = true
      check.response_time = elapsed.formatFloat(format = ffDecimal, precision = 3)
    except:
      check.ok = false
  elif target.url.scheme == "http" or target.url.scheme == "https":
    var http_client = newHttpClient()
    var accepted_methods = @["GET", "POST"]
    if myreq.content_type == "":
      myreq.content_type = "application/json"
    if myreq.request_method == "" or myreq.request_method notin accepted_methods:
      myreq.request_method = "GET"
    if myreq.request_method == "GET":
      try:
        var time = cpuTime()
        var http_req = http_client.get(myreq.url)
        var elapsed = cpuTime() - time
        if http_req.code == Http200:
          check.ok = true
          check.response_time = elapsed.formatFloat(format = ffDecimal, precision = 3)
      except:
        check.ok = false
    elif myreq.request_method == "POST":
      http_client.headers = newHttpHeaders({"Content-Type": myreq.content_type })
      try:
        var time = cpuTime()
        var http_req = http_client.request(myreq.url, httpMethod = HttpPost, body = $myreq.request_data)
        var elapsed = cpuTime() - time
        if http_req.code == Http200:
          check.ok = true
          check.response_time = elapsed.formatFloat(format = ffDecimal, precision = 3)
      except:
        check.ok = false

  myreq.check_id = check.id
  check.target_id = target.id

  waitFor insertCheck(check)
  waitFor insertMyReq(myreq)
  var json_res = %*{"target": %*target}
  json_res["check"] = %*check
  json_res["myrequest"] = %*myreq
  return json_res
  