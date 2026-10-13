class_name EliResult
extends RefCounted

# What came of asking ELI for something: the answer, or what kind of failure
# it was. A failure is never an empty string: "he did not catch that", "he is
# not running" and "he has no model loaded" are different things to tell the
# user, and each has its own sentence here.

var ok := false
var kind := ""          # empty when ok, else one of the kinds in SENTENCES
var status := 0         # HTTP status; 0 when the request never got an answer
var detail := ""        # ELI's own words about it, when he gave any
var retryable := false
var payload = null

const SENTENCES := {
    "disabled": "The link to ELI is off",
    "unreachable": "ELI is not running",
    "timeout": "ELI took too long to answer",
    "unauthorised": "ELI refused the token",
    "forbidden": "ELI does not allow that from here",
    "model_unavailable": "ELI has no model loaded",
    "unknown_model": "ELI has no model by that name",
    "incompatible": "This ELI v3 and this ELI VR speak different versions",
    "unsupported": "This ELI v3 is too old for that",
    "not_heard": "ELI did not catch that",
    "bad_request": "ELI could not make sense of the request",
    "server_error": "ELI ran into a problem",
    "bad_reply": "ELI's answer could not be read",
    "no_voice": "ELI answered, but his voice is not available",
}

static func good(value = null) -> EliResult:
    var r := EliResult.new()
    r.ok = true
    r.payload = value
    return r

static func bad(p_kind: String, p_detail: String = "", p_status: int = 0, p_retryable: bool = false) -> EliResult:
    var r := EliResult.new()
    r.kind = p_kind
    r.detail = p_detail
    r.status = p_status
    r.retryable = p_retryable
    return r

# One line for the status display. ELI's own words are used where they say
# more than the kind does.
func sentence() -> String:
    if ok:
        return ""
    if kind in ["incompatible", "bad_request"] and not detail.is_empty():
        return detail
    return str(SENTENCES.get(kind, "ELI could not do that"))
