import uri, json

type
    Target* = object
      id*: string
      url*: Uri
    
    Check* = object
      id*: string
      ok*: bool
      check_time*: string
      response_time*: string
      target_id*: string
    
    MyRequest* = ref object of RootObj
      id*: string
      url*: string
      wait*: int
      request_data*: JsonNode
      content_type*: string
      request_method*: string
      user_agent*: string
      check_id*: string
      
    MyResponse* = object
      id*: string
      response*: JsonNode

    