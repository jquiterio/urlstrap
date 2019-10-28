
#import urlstrappkg/submodule, 
import jester, json, net, strutils
import asyncdispatch
import graph, funcs


# proc db_setup() {.async.} =
#   var jr = await conn.runQuery(db.tableCreate("target"))
#   echo "Created: ", jr
#   jr = await conn.runQuery(db.tableCreate("check"))
#   echo "Created: ", jr
#   jr = await conn.runQuery(db.tableList())
#   echo "TableList: ", jr

#waitFor db_setup()

# template JsonEver(data:JsonNode): untyped =
#   resp Http200, data, "application/json"

routes:
  get "/":
    resp $(%*{"msg": "OK"}), "application/json"

  error {Http401 .. Http408}:
    if error.data.code == Http401:
      pass

  get "/graph/@host":
    #var x = $(%*(@[1, 2, 3, 4, 5]))
    var res:string
    var x:seq[string]
    var y:seq[float]
    var host = @"host"
    var xs: JsonNode
    var target:JsonNode
    #var ys: JsonNode
    #xs = waitFor getAll("check", %*{"target_id": target[0]["id"]} )
    target = waitFor getAllFiltered("target", %*{"url": {"hostname": host} } )
    if target.len == 0:
      res = "<html>nothing to show</html>"
    else:
      xs = waitFor getAllFiltered("check", %*{"target_id": target[0]["id"]})
      #ys = waitFor getAll("target", %*{"url": {"hostname": hostname} } )
      for v in xs:
        if v["response_time"].getStr().len == 0:
          y.add(0.1)
        else:
          y.add(parseFloat(v["response_time"].getStr()))
        x.add(v["check_time"].getStr())
      var html = getGraph($(%*x), $(%*y))
      res = html
    resp res
  
  get "/stats/@host":
    var host = @"host"
    var target,checks: JsonNode
    target = waitFor getAllFiltered("target", %*{"url": {"hostname": host} } )
    checks = waitFor getAllFiltered("check", %*{"target_id": target[0]["id"]})
    target[0]["checks"] = checks
    if target.len >= 1:
      resp Http200, $(target[0]), "application/json"
    else:
      resp Http404, $(%*{"msg": "not fount"}), "application/json"


  post "/post":
    var req = parsePayload($request.body)
    if req.url.len <= 0: resp Http204, $(%*{"msg": "POST request requires data parameter"}), "application/json"
    if req.request_method == "POST" and req.request_data.len < 1:
      resp Http204, $(%*{"msg": "POST request requires data parameter"}), "application/json"
    var json_res = PostCheck(%*req)
    resp $(json_res), "application/json"

