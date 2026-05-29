import json
from pathlib import Path

from mitmproxy import ctx, http

KEYWORDS = (
    "phoenix.ujing.online",
    "check.ujing.online",
)

INTERESTING = (
    "/api/v1/orders",
    "/api/v1/app/washer",
    "/api/v1/home/order",
    "/api/v1/payment",
    "/api/v1/redpackets",
)


def _text(content: bytes | None) -> str:
    if not content:
        return ""
    try:
        return content.decode("utf-8", errors="replace")
    except Exception:
        return repr(content[:500])


OUT = Path("tmp_ujing_flows.jsonl")


def load(loader):
    try:
        OUT.unlink()
    except FileNotFoundError:
        pass


def response(flow: http.HTTPFlow) -> None:
    req = flow.request
    if not any(host in req.pretty_host for host in KEYWORDS):
        return
    path = req.path
    if not any(key in path for key in INTERESTING):
        return

    headers = {}
    for name in (
        "Authorization",
        "authorization",
        "token",
        "app-version",
        "appVersion",
        "platform",
        "User-Agent",
        "Content-Type",
    ):
        if name in req.headers:
            value = req.headers.get(name)
            if name.lower() in {"authorization", "token"} and value:
                value = value[:16] + "...<redacted>"
            headers[name] = value

    item = {
        "method": req.method,
        "url": f"{req.scheme}://{req.pretty_host}{req.path}",
        "path": req.path,
        "status": flow.response.status_code if flow.response else None,
        "headers": headers,
        "requestBody": _text(req.raw_content),
        "responseBody": flow.response.get_text(strict=False) if flow.response else "",
    }
    with OUT.open("a", encoding="utf-8") as f:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")
