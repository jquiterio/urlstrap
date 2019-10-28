
import json, math, sequtils, strutils, times, random


var
    e: ref OSError
new(e)

proc errmgs*(err: string): json.JsonNode =
    return %*{"msg": err}


proc genUUID*(): string =
    const pattern = "xxxxxxxx-xxxx-9xxx-yxxx-xxxxxxxxxxxx"
    var d: int = toInt(epochTime() * 100000)
    proc fn(c : char): string =
        var r = toBiggestInt(toFloat(d) + rand(1.0) * 16) %% 16
        d = toInt(floor(toFloat(d) / 16))
        toHex(if c == 'x': r else: r and 0x3 or 0x8, 1)
    toLowerAscii(join(pattern.mapIt(if it == 'x' or it == 'y': fn(it) else: $it)))
     
