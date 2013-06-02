
util = require 'util'

#=========================================================

exports.BaseError = BaseError = (msg, constructor) ->
  Error.captureStackTrace @, @constructor
  @message = msg or 'Error'
util.inherits BaseError, Error
BaseError.prototype.name = "BaseError"

#=========================================================

to_lower   = (s) -> (s[0].toUpperCase() + s[1...].toLowerCase())
c_to_camel = (s) -> (to_lower p for p in s.split /_/).join ''

make_error_klass = (k) ->
  ctor = (msg) -> 
    BaseError.call(this, msg, this.constructor)
    this.istack = []
    this
  util.inherits ctor, BaseError
  ctor.prototype.name = k
  ctor.prototype.inspect = () -> "[#{k}: #{this.message}]"
  ctor

#=========================================================

exports.make_errors = make_errors = (d) ->
  out =
    msg : {}
    name : {}
    code : {}

  # Constants
  d.OK = "Success"
  errno = 100

  for k,msg of d
    if k isnt "OK"
      enam = (c_to_camel k) + "Error"
      out[enam] = make_error_klass enam
      val = errno++
    else
      val = 0
    out[k] = val
    out.msg[k] = out.msg[val] = msg
    out.name[k] = out.name[val] = k
    out.code[k] = val

  out

#=========================================================

ipush = (e, msg) ->
  if msg?
    e.istack = [] unless e.istack?
    e.istack.push msg

# Error short-circuit connector
exports.make_esc = make_esc = (gcb, where) -> (lcb) ->
  (err, args...) ->
    if not err? then lcb args...
    else if not gcb.__esc
      gcb.__esc = true
      ipush err, where
      gcb err

#================================================

# A class-based Error short-circuiter; output OK
exports.EscOk = class EscOk
  constructor : (@gcb, @where) ->

  bailout : () ->
    if @gcb
      t = @gcb
      @gcb = null
      t false

  check_ok : (cb) ->
    (ok, args...) =>
      if not ok then @bailout()
      else cb args...

  check_err : (cb) ->
    (err, args...) =>
      if err?
        ipush err, @where
        @bailout()
      else cb args...

  check_non_null : (cb) ->
    (args...) =>
      if not args[0]? then @bailout()
      else cb args...

#================================================

exports.EscErr = class EscErr
  constructor : (@gcb, @where) ->

  finish : (err) ->
    if @gcb
      t = @gcb
      @gcb = null
      t err

  check_ok : (cb, eclass = Error, emsg = null) -> 
    (ok, args...) ->
      if not ok 
        err = new eclass emsg
        ipush err, @where
        @finish err
      else cb args...

  check_err : (cb) ->
    (err, args...) ->
      if err?
        ipush err, @where
        @finish err
      else cb args...

#================================================


d = make_errors 
  FOO : "boob dood"
  HAVE_ONE_ON_ME : "ok then"

console.log d

f = () ->
  throw new d.FooError "shit dog"

try
  f()
catch e
  if (e instanceof d.FooError)
    console.log e
console.log new Error "ass dog"